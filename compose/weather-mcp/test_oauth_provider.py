"""Unit tests for WeatherOAuthProvider (oauth_provider.py).

These exercise the provider's storage/business-logic methods directly
(the OAuthAuthorizationServerProvider Protocol) rather than through HTTP -
PKCE verification, redirect_uri matching, and client authentication are
already handled by the mcp SDK's own handlers (see
mcp/server/auth/handlers/{authorize,token}.py) and are covered instead by
the end-to-end test_oauth_flow.py.
"""
import time

import pytest
from mcp.server.auth.provider import AuthorizationParams
from mcp.shared.auth import OAuthClientInformationFull, OAuthToken
from pydantic import AnyHttpUrl

from oauth_provider import UnknownAuthorizationRequestError, WeatherOAuthProvider


def make_client(client_id="client-1", redirect_uri="https://client.example/callback"):
    return OAuthClientInformationFull(
        client_id=client_id,
        redirect_uris=[AnyHttpUrl(redirect_uri)],
        token_endpoint_auth_method="none",
    )


def make_params(code_challenge="challenge", redirect_uri="https://client.example/callback", state="xyz"):
    return AuthorizationParams(
        state=state,
        scopes=["weather"],
        code_challenge=code_challenge,
        redirect_uri=AnyHttpUrl(redirect_uri),
        redirect_uri_provided_explicitly=True,
    )


@pytest.fixture
def provider(tmp_path):
    return WeatherOAuthProvider(
        issuer_url="https://weather.example",
        store_path=tmp_path / ".oauth_store.json",
    )


async def test_register_and_get_client(provider):
    client = make_client()

    await provider.register_client(client)

    assert await provider.get_client("client-1") is client


async def test_get_client_unknown_returns_none(provider):
    assert await provider.get_client("nope") is None


async def test_authorize_redirects_to_login_with_request_id(provider):
    client = make_client()

    redirect = await provider.authorize(client, make_params())

    assert redirect.startswith("https://weather.example/login?request_id=")


async def test_finish_authorization_unknown_request_id_raises(provider):
    with pytest.raises(UnknownAuthorizationRequestError):
        await provider.finish_authorization("does-not-exist")


async def test_finish_authorization_issues_code_and_redirects_to_client(provider):
    client = make_client()
    redirect = await provider.authorize(client, make_params(state="xyz"))
    request_id = redirect.split("request_id=")[1]

    final_redirect = await provider.finish_authorization(request_id)

    assert final_redirect.startswith("https://client.example/callback?")
    assert "code=" in final_redirect
    assert "state=xyz" in final_redirect


async def test_finish_authorization_consumes_the_pending_request(provider):
    client = make_client()
    redirect = await provider.authorize(client, make_params())
    request_id = redirect.split("request_id=")[1]
    await provider.finish_authorization(request_id)

    with pytest.raises(UnknownAuthorizationRequestError):
        await provider.finish_authorization(request_id)


async def test_load_authorization_code_returns_none_for_unknown_code(provider):
    client = make_client()
    assert await provider.load_authorization_code(client, "bogus-code") is None


async def test_load_authorization_code_returns_none_for_wrong_client(provider):
    client = make_client(client_id="client-1")
    other_client = make_client(client_id="client-2")
    redirect = await provider.authorize(client, make_params())
    request_id = redirect.split("request_id=")[1]
    final_redirect = await provider.finish_authorization(request_id)
    code = final_redirect.split("code=")[1].split("&")[0]

    assert await provider.load_authorization_code(other_client, code) is None


async def test_load_authorization_code_returns_code_for_correct_client(provider):
    client = make_client()
    redirect = await provider.authorize(client, make_params(code_challenge="chal123"))
    request_id = redirect.split("request_id=")[1]
    final_redirect = await provider.finish_authorization(request_id)
    code = final_redirect.split("code=")[1].split("&")[0]

    auth_code = await provider.load_authorization_code(client, code)

    assert auth_code is not None
    assert auth_code.code == code
    assert auth_code.code_challenge == "chal123"
    assert auth_code.client_id == "client-1"


async def _issue_authorization_code(provider, client, **params_kwargs):
    redirect = await provider.authorize(client, make_params(**params_kwargs))
    request_id = redirect.split("request_id=")[1]
    final_redirect = await provider.finish_authorization(request_id)
    code = final_redirect.split("code=")[1].split("&")[0]
    return await provider.load_authorization_code(client, code)


async def test_exchange_authorization_code_returns_tokens(provider):
    client = make_client()
    auth_code = await _issue_authorization_code(provider, client)

    tokens = await provider.exchange_authorization_code(client, auth_code)

    assert isinstance(tokens, OAuthToken)
    assert tokens.access_token
    assert tokens.refresh_token
    # RFC 6749 s7.1: token_type is case-insensitive. mcp >=1.10 emits "Bearer".
    assert tokens.token_type.lower() == "bearer"


async def test_exchange_authorization_code_consumes_the_code(provider):
    client = make_client()
    auth_code = await _issue_authorization_code(provider, client)
    await provider.exchange_authorization_code(client, auth_code)

    assert await provider.load_authorization_code(client, auth_code.code) is None


async def test_load_access_token_returns_none_for_unknown_token(provider):
    assert await provider.load_access_token("bogus") is None


async def test_load_access_token_returns_token_after_exchange(provider):
    client = make_client()
    auth_code = await _issue_authorization_code(provider, client)
    tokens = await provider.exchange_authorization_code(client, auth_code)

    access_token = await provider.load_access_token(tokens.access_token)

    assert access_token is not None
    assert access_token.client_id == "client-1"
    assert access_token.scopes == ["weather"]


async def test_load_access_token_expired_returns_none(provider):
    client = make_client()
    auth_code = await _issue_authorization_code(provider, client)
    tokens = await provider.exchange_authorization_code(client, auth_code)
    # Force expiry directly in the provider's store.
    stored = provider._access_tokens[tokens.access_token]
    provider._access_tokens[tokens.access_token] = stored.model_copy(
        update={"expires_at": int(time.time()) - 1}
    )

    assert await provider.load_access_token(tokens.access_token) is None


async def test_load_refresh_token_returns_none_for_wrong_client(provider):
    client = make_client(client_id="client-1")
    other_client = make_client(client_id="client-2")
    auth_code = await _issue_authorization_code(provider, client)
    tokens = await provider.exchange_authorization_code(client, auth_code)

    assert await provider.load_refresh_token(other_client, tokens.refresh_token) is None


async def test_exchange_refresh_token_rotates_tokens(provider):
    client = make_client()
    auth_code = await _issue_authorization_code(provider, client)
    first_tokens = await provider.exchange_authorization_code(client, auth_code)
    refresh_token = await provider.load_refresh_token(client, first_tokens.refresh_token)

    second_tokens = await provider.exchange_refresh_token(client, refresh_token, ["weather"])

    assert second_tokens.access_token != first_tokens.access_token
    assert second_tokens.refresh_token != first_tokens.refresh_token
    # Old refresh token is rotated out.
    assert await provider.load_refresh_token(client, first_tokens.refresh_token) is None
    # New access token is valid.
    assert await provider.load_access_token(second_tokens.access_token) is not None


async def test_revoke_token_removes_access_token(provider):
    client = make_client()
    auth_code = await _issue_authorization_code(provider, client)
    tokens = await provider.exchange_authorization_code(client, auth_code)
    access_token = await provider.load_access_token(tokens.access_token)

    await provider.revoke_token(access_token)

    assert await provider.load_access_token(tokens.access_token) is None


async def test_revoke_token_removes_refresh_token(provider):
    client = make_client()
    auth_code = await _issue_authorization_code(provider, client)
    tokens = await provider.exchange_authorization_code(client, auth_code)
    refresh_token = await provider.load_refresh_token(client, tokens.refresh_token)

    await provider.revoke_token(refresh_token)

    assert await provider.load_refresh_token(client, tokens.refresh_token) is None


async def test_revoke_unknown_token_is_a_noop(provider):
    client = make_client()
    from mcp.server.auth.provider import AccessToken

    bogus = AccessToken(token="bogus", client_id=client.client_id, scopes=[])
    await provider.revoke_token(bogus)  # must not raise


async def test_clients_and_refresh_tokens_persist_across_instances(tmp_path):
    store_path = tmp_path / ".oauth_store.json"
    provider = WeatherOAuthProvider(issuer_url="https://weather.example", store_path=store_path)
    client = make_client()
    await provider.register_client(client)
    auth_code = await _issue_authorization_code(provider, client)
    tokens = await provider.exchange_authorization_code(client, auth_code)

    reloaded = WeatherOAuthProvider(issuer_url="https://weather.example", store_path=store_path)

    assert await reloaded.get_client("client-1") is not None
    assert await reloaded.load_refresh_token(client, tokens.refresh_token) is not None


async def test_access_tokens_do_not_persist_across_instances(tmp_path):
    store_path = tmp_path / ".oauth_store.json"
    provider = WeatherOAuthProvider(issuer_url="https://weather.example", store_path=store_path)
    client = make_client()
    await provider.register_client(client)
    auth_code = await _issue_authorization_code(provider, client)
    tokens = await provider.exchange_authorization_code(client, auth_code)

    reloaded = WeatherOAuthProvider(issuer_url="https://weather.example", store_path=store_path)

    assert await reloaded.load_access_token(tokens.access_token) is None
