"""End-to-end HTTP test of the OAuth 2.1 + PKCE + Dynamic Client
Registration flow wired into unified_server.py, plus the RFC 9728 Protected
Resource Metadata endpoints and the interaction between OAuth access tokens
and the legacy static-bearer-token path on /mcp.

Uses the shared session-scoped `mcp_test_client` fixture from conftest.py -
see test_mcp_http_endpoint.py's module docstring for why a single shared
TestClient is required (weather_mcp's StreamableHTTPSessionManager can only
be entered once per process).

Redirects are never auto-followed: the provider's issuer_url need not match
the TestClient's origin for these tests to be valid (in production it's the
public beeblebox funnel URL), so each hop's Location header is parsed for its path
and query, and the next request is made directly against that path on the
same TestClient/app - exactly what a browser would do by following the
redirect, just without requiring the origins to match.
"""
import base64
import hashlib
import secrets
from urllib.parse import parse_qs, urlparse

CALLBACK_URI = "https://claude.example/callback"


def make_pkce_pair():
    verifier = secrets.token_urlsafe(64)
    digest = hashlib.sha256(verifier.encode()).digest()
    challenge = base64.urlsafe_b64encode(digest).decode().rstrip("=")
    return verifier, challenge


def path_and_query(url):
    parsed = urlparse(url)
    return parsed.path + (f"?{parsed.query}" if parsed.query else "")


def register_client(client, redirect_uri=CALLBACK_URI):
    response = client.post(
        "/register",
        json={
            "redirect_uris": [redirect_uri],
            "token_endpoint_auth_method": "none",
            "grant_types": ["authorization_code", "refresh_token"],
            "response_types": ["code"],
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def start_authorization(client, client_id, challenge, redirect_uri=CALLBACK_URI, state="abc123"):
    response = client.get(
        "/authorize",
        params={
            "client_id": client_id,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "code_challenge": challenge,
            "code_challenge_method": "S256",
            "state": state,
        },
        follow_redirects=False,
    )
    assert response.status_code == 302, response.text
    return response.headers["location"]


def test_well_known_authorization_server_metadata(mcp_test_client):
    response = mcp_test_client.get("/.well-known/oauth-authorization-server")

    assert response.status_code == 200
    metadata = response.json()
    assert metadata["authorization_endpoint"].endswith("/authorize")
    assert metadata["token_endpoint"].endswith("/token")
    assert metadata["registration_endpoint"].endswith("/register")
    assert "S256" in metadata["code_challenge_methods_supported"]


def test_well_known_protected_resource_metadata(mcp_test_client):
    for path in ("/.well-known/oauth-protected-resource", "/.well-known/oauth-protected-resource/mcp"):
        response = mcp_test_client.get(path)
        assert response.status_code == 200, path
        metadata = response.json()
        assert metadata["resource"].endswith("/mcp")
        assert metadata["authorization_servers"]


def test_protected_resource_metadata_issuer_matches_as_metadata_issuer(mcp_test_client):
    """Spec-compliant clients may compare these two issuer strings byte-for-
    byte; a normalization mismatch (e.g. a missing trailing slash) would be
    a silent discovery failure."""
    as_metadata = mcp_test_client.get("/.well-known/oauth-authorization-server").json()
    pr_metadata = mcp_test_client.get("/.well-known/oauth-protected-resource").json()

    assert pr_metadata["authorization_servers"] == [as_metadata["issuer"]]


def test_dynamic_client_registration_returns_public_client(mcp_test_client):
    client_info = register_client(mcp_test_client)

    assert client_info["client_id"]
    assert client_info.get("client_secret") is None


def test_authorize_redirects_to_login(mcp_test_client):
    client_info = register_client(mcp_test_client)
    _, challenge = make_pkce_pair()

    login_url = start_authorization(mcp_test_client, client_info["client_id"], challenge)

    assert "/login" in login_url
    assert "request_id=" in login_url


def test_login_get_renders_password_form(mcp_test_client):
    client_info = register_client(mcp_test_client)
    _, challenge = make_pkce_pair()
    login_url = start_authorization(mcp_test_client, client_info["client_id"], challenge)

    response = mcp_test_client.get(path_and_query(login_url))

    assert response.status_code == 200
    assert "password" in response.text.lower()


def test_login_post_wrong_password_rejected(mcp_test_client, monkeypatch):
    monkeypatch.setenv("WEATHER_MCP_TOKEN", "test-secret-token")
    client_info = register_client(mcp_test_client)
    _, challenge = make_pkce_pair()
    login_url = start_authorization(mcp_test_client, client_info["client_id"], challenge)

    response = mcp_test_client.post(
        path_and_query(login_url), data={"password": "wrong"}, follow_redirects=False
    )

    assert response.status_code == 401


def test_login_post_unknown_request_id_rejected(mcp_test_client, monkeypatch):
    monkeypatch.setenv("WEATHER_MCP_TOKEN", "test-secret-token")

    response = mcp_test_client.post(
        "/login?request_id=does-not-exist",
        data={"password": "test-secret-token"},
        follow_redirects=False,
    )

    assert response.status_code == 400


def test_login_post_disabled_when_token_unset(mcp_test_client, monkeypatch):
    client_info = register_client(mcp_test_client)
    _, challenge = make_pkce_pair()
    login_url = start_authorization(mcp_test_client, client_info["client_id"], challenge)
    monkeypatch.delenv("WEATHER_MCP_TOKEN", raising=False)

    response = mcp_test_client.post(
        path_and_query(login_url), data={"password": "anything"}, follow_redirects=False
    )

    assert response.status_code == 503


def _complete_login(client, login_url, password="test-secret-token"):
    response = client.post(path_and_query(login_url), data={"password": password}, follow_redirects=False)
    assert response.status_code == 302, response.text
    return response.headers["location"]


def test_full_authorization_code_flow_issues_working_access_token(mcp_test_client, monkeypatch):
    monkeypatch.setenv("WEATHER_MCP_TOKEN", "test-secret-token")
    client = mcp_test_client
    client_info = register_client(client)
    verifier, challenge = make_pkce_pair()

    login_url = start_authorization(client, client_info["client_id"], challenge, state="my-state")
    final_redirect = _complete_login(client, login_url)

    assert final_redirect.startswith(CALLBACK_URI)
    query = parse_qs(urlparse(final_redirect).query)
    assert query["state"] == ["my-state"]
    code = query["code"][0]

    token_response = client.post(
        "/token",
        data={
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": CALLBACK_URI,
            "client_id": client_info["client_id"],
            "code_verifier": verifier,
        },
    )
    assert token_response.status_code == 200, token_response.text
    tokens = token_response.json()
    assert tokens["access_token"]
    assert tokens["refresh_token"]

    init_payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2025-06-18",
            "capabilities": {},
            "clientInfo": {"name": "oauth-test-client", "version": "0"},
        },
    }
    mcp_response = client.post(
        "/mcp",
        json=init_payload,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "Authorization": f"Bearer {tokens['access_token']}",
        },
    )
    assert mcp_response.status_code == 200

    refresh_response = client.post(
        "/token",
        data={
            "grant_type": "refresh_token",
            "refresh_token": tokens["refresh_token"],
            "client_id": client_info["client_id"],
        },
    )
    assert refresh_response.status_code == 200, refresh_response.text
    refreshed = refresh_response.json()
    assert refreshed["access_token"] != tokens["access_token"]


def test_token_exchange_rejects_wrong_pkce_verifier(mcp_test_client, monkeypatch):
    monkeypatch.setenv("WEATHER_MCP_TOKEN", "test-secret-token")
    client = mcp_test_client
    client_info = register_client(client)
    _, challenge = make_pkce_pair()

    login_url = start_authorization(client, client_info["client_id"], challenge)
    final_redirect = _complete_login(client, login_url)
    code = parse_qs(urlparse(final_redirect).query)["code"][0]

    token_response = client.post(
        "/token",
        data={
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": CALLBACK_URI,
            "client_id": client_info["client_id"],
            "code_verifier": "wrong-verifier",
        },
    )

    assert token_response.status_code == 400
    assert token_response.json()["error"] == "invalid_grant"


def test_static_bearer_token_still_works_once_oauth_is_wired_in(mcp_test_client, monkeypatch):
    """Regression: the legacy static WEATHER_MCP_TOKEN path must keep working
    unmodified once OAuth is also wired in."""
    monkeypatch.setenv("WEATHER_MCP_TOKEN", "test-secret-token")
    client = mcp_test_client
    auth_headers = {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
        "Authorization": "Bearer test-secret-token",
    }

    init_response = client.post(
        "/mcp",
        json={
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "clientInfo": {"name": "static-token-regression", "version": "0"},
            },
        },
        headers=auth_headers,
    )
    assert init_response.status_code == 200
    session_id = init_response.headers["mcp-session-id"]

    client.post(
        "/mcp",
        json={"jsonrpc": "2.0", "method": "notifications/initialized"},
        headers={**auth_headers, "mcp-session-id": session_id},
    )

    tools_response = client.post(
        "/mcp",
        json={"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}},
        headers={**auth_headers, "mcp-session-id": session_id},
    )

    assert tools_response.status_code == 200


def test_mcp_401_www_authenticate_advertises_resource_metadata(mcp_test_client, monkeypatch):
    monkeypatch.setenv("WEATHER_MCP_TOKEN", "test-secret-token")
    client = mcp_test_client

    response = client.post(
        "/mcp",
        json={"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}},
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        },
    )

    assert response.status_code == 401
    www_authenticate = response.headers.get("www-authenticate", "")
    assert www_authenticate.startswith("Bearer ")
    assert "resource_metadata=" in www_authenticate
    assert "/.well-known/oauth-protected-resource" in www_authenticate


def test_as_metadata_urls_are_wellformed_under_a_path_prefixed_issuer():
    """Guards the deployment behind a Tailscale Funnel path mount.

    In production the server is mounted at https://<host>/weather, so the
    issuer carries a path component. mcp 1.9.1's build_metadata() joined the
    endpoint names on without a separator - "/weather" + "authorize" - and
    emitted "https://<host>//weatherauthorize" for all four endpoints. It was
    only ever correct for a bare-origin issuer, which is what every other test
    here (and local dev) uses, so nothing caught it.

    Pin the path-prefixed behaviour explicitly so a future SDK bump can't
    silently reintroduce it. See pyproject.toml's mcp lower bound.
    """
    from mcp.server.auth.routes import build_metadata
    from mcp.server.auth.settings import ClientRegistrationOptions, RevocationOptions
    from pydantic import AnyHttpUrl

    metadata = build_metadata(
        issuer_url=AnyHttpUrl("https://example.com/weather"),
        service_documentation_url=None,
        client_registration_options=ClientRegistrationOptions(
            enabled=True, valid_scopes=["weather"], default_scopes=["weather"]
        ),
        revocation_options=RevocationOptions(enabled=True),
    )

    assert str(metadata.issuer) == "https://example.com/weather"
    assert str(metadata.authorization_endpoint) == "https://example.com/weather/authorize"
    assert str(metadata.token_endpoint) == "https://example.com/weather/token"
    assert str(metadata.registration_endpoint) == "https://example.com/weather/register"
    assert str(metadata.revocation_endpoint) == "https://example.com/weather/revoke"

    # The failure mode was a doubled slash in the path, which is what made the
    # advertised endpoints unreachable - assert against it directly.
    for endpoint in (
        metadata.authorization_endpoint,
        metadata.token_endpoint,
        metadata.registration_endpoint,
        metadata.revocation_endpoint,
    ):
        assert "//" not in str(endpoint).removeprefix("https://")
