"""Single-user OAuth 2.1 Authorization Server provider for the weather MCP
server's /mcp endpoint.

Implements mcp.server.auth.provider.OAuthAuthorizationServerProvider. The
SDK's own handlers (mcp/server/auth/handlers/{authorize,token}.py) already
own PKCE verification, redirect_uri matching, and Dynamic Client
Registration record-keeping - this class only owns storage and the
single-user login hop between /authorize and /token (see
UnknownAuthorizationRequestError / finish_authorization, called from the
/login route in unified_server.py after the shared-secret password check
passes there, not in this module).
"""
import json
import secrets
import time
from pathlib import Path

from mcp.server.auth.provider import (
    AccessToken,
    AuthorizationCode,
    AuthorizationParams,
    RefreshToken,
    construct_redirect_uri,
)
from mcp.shared.auth import OAuthClientInformationFull, OAuthToken

AUTHORIZATION_CODE_TTL_SECONDS = 5 * 60
ACCESS_TOKEN_TTL_SECONDS = 60 * 60


class UnknownAuthorizationRequestError(Exception):
    """Raised by finish_authorization() for an unknown/expired request_id."""


class WeatherOAuthProvider:
    def __init__(self, issuer_url: str, store_path: Path | str):
        self._issuer_url = issuer_url.rstrip("/")
        self._store_path = Path(store_path)

        self._clients: dict[str, OAuthClientInformationFull] = {}
        self._pending_authorizations: dict[
            str, tuple[OAuthClientInformationFull, AuthorizationParams]
        ] = {}
        self._auth_codes: dict[str, AuthorizationCode] = {}
        self._access_tokens: dict[str, AccessToken] = {}
        self._refresh_tokens: dict[str, RefreshToken] = {}

        self._load_store()

    def _load_store(self) -> None:
        if not self._store_path.exists():
            return
        data = json.loads(self._store_path.read_text())
        for client_id, client_data in data.get("clients", {}).items():
            self._clients[client_id] = OAuthClientInformationFull.model_validate(client_data)
        for token, token_data in data.get("refresh_tokens", {}).items():
            self._refresh_tokens[token] = RefreshToken.model_validate(token_data)

    def _save_store(self) -> None:
        data = {
            "clients": {
                client_id: client.model_dump(mode="json")
                for client_id, client in self._clients.items()
            },
            "refresh_tokens": {
                token: refresh_token.model_dump(mode="json")
                for token, refresh_token in self._refresh_tokens.items()
            },
        }
        self._store_path.write_text(json.dumps(data))

    async def get_client(self, client_id: str) -> OAuthClientInformationFull | None:
        return self._clients.get(client_id)

    async def register_client(self, client_info: OAuthClientInformationFull) -> None:
        self._clients[client_info.client_id] = client_info
        self._save_store()

    async def authorize(
        self, client: OAuthClientInformationFull, params: AuthorizationParams
    ) -> str:
        request_id = secrets.token_urlsafe(32)
        self._pending_authorizations[request_id] = (client, params)
        return f"{self._issuer_url}/login?request_id={request_id}"

    async def finish_authorization(self, request_id: str) -> str:
        """Called by the /login route once the shared-secret password check
        passes, to mint the authorization code and redirect back to the
        client's redirect_uri."""
        pending = self._pending_authorizations.pop(request_id, None)
        if pending is None:
            raise UnknownAuthorizationRequestError(request_id)
        client, params = pending

        code = secrets.token_urlsafe(32)
        auth_code = AuthorizationCode(
            code=code,
            scopes=params.scopes or [],
            expires_at=time.time() + AUTHORIZATION_CODE_TTL_SECONDS,
            client_id=client.client_id,
            code_challenge=params.code_challenge,
            redirect_uri=params.redirect_uri,
            redirect_uri_provided_explicitly=params.redirect_uri_provided_explicitly,
        )
        self._auth_codes[code] = auth_code

        return construct_redirect_uri(str(params.redirect_uri), code=code, state=params.state)

    async def load_authorization_code(
        self, client: OAuthClientInformationFull, authorization_code: str
    ) -> AuthorizationCode | None:
        auth_code = self._auth_codes.get(authorization_code)
        if auth_code is None or auth_code.client_id != client.client_id:
            return None
        return auth_code

    async def exchange_authorization_code(
        self, client: OAuthClientInformationFull, authorization_code: AuthorizationCode
    ) -> OAuthToken:
        # Single-use: remove so a replayed code is rejected by load_authorization_code.
        self._auth_codes.pop(authorization_code.code, None)
        return self._issue_tokens(client.client_id, authorization_code.scopes)

    async def load_refresh_token(
        self, client: OAuthClientInformationFull, refresh_token: str
    ) -> RefreshToken | None:
        token = self._refresh_tokens.get(refresh_token)
        if token is None or token.client_id != client.client_id:
            return None
        return token

    async def exchange_refresh_token(
        self,
        client: OAuthClientInformationFull,
        refresh_token: RefreshToken,
        scopes: list[str],
    ) -> OAuthToken:
        # Rotate: the old refresh token is single-use.
        self._refresh_tokens.pop(refresh_token.token, None)
        return self._issue_tokens(client.client_id, scopes)

    def _issue_tokens(self, client_id: str, scopes: list[str]) -> OAuthToken:
        access_token = secrets.token_urlsafe(32)
        refresh_token = secrets.token_urlsafe(32)
        expires_at = int(time.time()) + ACCESS_TOKEN_TTL_SECONDS

        self._access_tokens[access_token] = AccessToken(
            token=access_token, client_id=client_id, scopes=scopes, expires_at=expires_at
        )
        self._refresh_tokens[refresh_token] = RefreshToken(
            token=refresh_token, client_id=client_id, scopes=scopes
        )
        self._save_store()

        return OAuthToken(
            access_token=access_token,
            token_type="bearer",
            expires_in=ACCESS_TOKEN_TTL_SECONDS,
            scope=" ".join(scopes),
            refresh_token=refresh_token,
        )

    async def load_access_token(self, token: str) -> AccessToken | None:
        access_token = self._access_tokens.get(token)
        if access_token is None:
            return None
        if access_token.expires_at is not None and access_token.expires_at < time.time():
            return None
        return access_token

    async def revoke_token(self, token: AccessToken | RefreshToken) -> None:
        if token.token in self._access_tokens:
            del self._access_tokens[token.token]
        if token.token in self._refresh_tokens:
            del self._refresh_tokens[token.token]
            self._save_store()
