#!/usr/bin/env python3
"""Unified server combining Flask web GUI and MCP SSE endpoint."""

import asyncio
import contextlib
import logging
import os
from pathlib import Path
from secrets import compare_digest
from typing import Any, Coroutine
from flask import Flask, render_template, request, jsonify
from mcp.server.auth.routes import create_auth_routes
from mcp.server.auth.settings import ClientRegistrationOptions, RevocationOptions
from pydantic import AnyHttpUrl
from weather import get_alerts, get_forecast, mcp as weather_mcp
from cities import get_all_cities, get_city_coordinates
from oauth_provider import UnknownAuthorizationRequestError, WeatherOAuthProvider
from asgiref.wsgi import WsgiToAsgi
from starlette.applications import Starlette
from starlette.datastructures import Headers
from starlette.requests import Request
from starlette.responses import HTMLResponse, JSONResponse, RedirectResponse, Response
from starlette.routing import Mount, Route
from starlette.middleware import Middleware
from starlette.middleware.cors import CORSMiddleware

# Create Flask app
flask_app = Flask(__name__)

def run_async(coro: Coroutine) -> Any:
    """Run an async coroutine in a new event loop (for Flask sync context).

    Args:
        coro: The coroutine to run

    Returns:
        The result of the coroutine
    """
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()

@flask_app.route('/')
def index():
    """Serve the main web interface."""
    return render_template('index.html')

@flask_app.route('/api/alerts', methods=['POST'])
def api_alerts():
    """API endpoint for weather alerts."""
    try:
        data = request.get_json()
        state = data.get('state', '').upper()

        if not state or len(state) != 2:
            return jsonify({'error': 'Please provide a valid 2-letter state code (e.g., CA, NY)'}), 400

        result = run_async(get_alerts(state))
        return jsonify({'result': result})

    except Exception as e:
        return jsonify({'error': f'Error fetching alerts: {str(e)}'}), 500

@flask_app.route('/api/cities', methods=['GET'])
def api_cities():
    """API endpoint to get all available cities."""
    try:
        cities = get_all_cities()
        return jsonify({'cities': cities})
    except Exception as e:
        return jsonify({'error': f'Error fetching cities: {str(e)}'}), 500

@flask_app.route('/api/city-coordinates', methods=['POST'])
def api_city_coordinates():
    """API endpoint to get coordinates for a specific city."""
    try:
        data = request.get_json()
        city = data.get('city', '').strip()

        if not city:
            return jsonify({'error': 'Please provide a city name'}), 400

        coords_result, newly_added = run_async(get_city_coordinates(city))
        if coords_result:
            latitude, longitude = coords_result
            return jsonify({
                'city': city,
                'latitude': latitude,
                'longitude': longitude,
                'newly_added': newly_added
            })
        else:
            return jsonify({'error': f'Could not find coordinates for "{city}"'}), 404

    except Exception as e:
        return jsonify({'error': f'Error fetching coordinates: {str(e)}'}), 500

@flask_app.route('/api/forecast', methods=['POST'])
def api_forecast():
    """API endpoint for weather forecast."""
    try:
        data = request.get_json()
        city = data.get('city')
        latitude = data.get('latitude')
        longitude = data.get('longitude')

        city_name = None
        was_newly_added = False

        # If city is provided, get coordinates from city lookup (with geocoding)
        if city:
            coords_result, newly_added = run_async(get_city_coordinates(city))
            if coords_result:
                latitude, longitude = coords_result
                city_name = city
                was_newly_added = newly_added
            else:
                return jsonify({'error': f'Could not find or geocode city "{city}"'}), 400

        if latitude is None or longitude is None:
            return jsonify({'error': 'Please provide either a city or both latitude and longitude'}), 400

        try:
            lat = float(latitude)
            lng = float(longitude)
        except ValueError:
            return jsonify({'error': 'Latitude and longitude must be valid numbers'}), 400

        if not (-90 <= lat <= 90) or not (-180 <= lng <= 180):
            return jsonify({'error': 'Invalid coordinates. Latitude: -90 to 90, Longitude: -180 to 180'}), 400

        result = run_async(get_forecast(lat, lng))

        response_data = {
            'result': result,
            'location': {
                'city': city_name,
                'latitude': lat,
                'longitude': lng,
                'newly_added': was_newly_added
            }
        }

        return jsonify(response_data)

    except Exception as e:
        return jsonify({'error': f'Error fetching forecast: {str(e)}'}), 500

# Convert Flask app to ASGI
wsgi_app = WsgiToAsgi(flask_app)

# Get MCP Streamable HTTP app - it has a route at /mcp.
# This also lazily creates weather_mcp's StreamableHTTPSessionManager.
mcp_app = weather_mcp.streamable_http_app()

# Create combined Starlette app
# Mount MCP app at root so /mcp is accessible
# Then mount Flask app to catch remaining routes
middleware = [
    Middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["mcp-session-id"],
    )
]


@contextlib.asynccontextmanager
async def lifespan(app):
    # streamable_http_app()'s own lifespan starts the session manager's task
    # group; merging only its routes (below) drops that lifespan, so we have
    # to re-enter it here or every /mcp request fails with
    # "Task group is not initialized".
    async with weather_mcp.session_manager.run():
        yield


# mcp_app.routes is just [Mount("/mcp", app=handle_streamable_http)]. A Mount's
# path-matching regex requires a literal "/" after the prefix, so it never
# matches the bare "/mcp" (no trailing slash) - only "/mcp/...". Without an
# explicit exact-path route, bare "/mcp" falls through to the Flask catch-all
# Mount below (which matches any path) and 404s there instead of reaching MCP.
mcp_mount = mcp_app.routes[0]

logger = logging.getLogger(__name__)

WEATHER_MCP_TOKEN_ENV_VAR = "WEATHER_MCP_TOKEN"

# Refusing to start beats warning-and-serving once this runs in a container:
# the shell wrapper that used to source .env is gone, so a missing variable is
# no longer something a human sees scroll past - it silently publishes /mcp to
# whoever has the URL. Deployments set WEATHER_MCP_REQUIRE_TOKEN=1; local dev
# and the test suite leave it unset and keep the old warn-only behaviour.
WEATHER_MCP_REQUIRE_TOKEN_ENV_VAR = "WEATHER_MCP_REQUIRE_TOKEN"

_NO_TOKEN_MESSAGE = (
    f"{WEATHER_MCP_TOKEN_ENV_VAR} is not set - the /mcp endpoint has NO auth "
    f"and is open to anyone with the URL. Set {WEATHER_MCP_TOKEN_ENV_VAR} in "
    "the environment before exposing this server remotely. Generate one with: "
    'python -c "import secrets; print(secrets.token_urlsafe(32))"'
)

if not os.environ.get(WEATHER_MCP_TOKEN_ENV_VAR):
    if os.environ.get(WEATHER_MCP_REQUIRE_TOKEN_ENV_VAR):
        raise RuntimeError(
            f"{_NO_TOKEN_MESSAGE} "
            f"({WEATHER_MCP_REQUIRE_TOKEN_ENV_VAR} is set, so refusing to "
            "start rather than serving an unauthenticated /mcp.)"
        )
    logger.warning("%s", _NO_TOKEN_MESSAGE)

# --- OAuth 2.1 (single-user, self-hosted Authorization Server) ---
#
# Coexists with the static WEATHER_MCP_TOKEN bearer check above rather than
# replacing it: Claude Desktop/curl/Perplexity keep using the static token
# unchanged, while claude.ai's web "Add custom connector" UI (which can only
# do OAuth discovery, not a custom header - see SSE_DEPLOYMENT.md) uses this
# flow instead. There is exactly one legitimate user of this server, so
# /login authenticates with the same WEATHER_MCP_TOKEN shared secret rather
# than a real per-user login system - see oauth_provider.py for why a full
# multi-tenant OAuth server is not proportionate here.
WEATHER_MCP_ISSUER_URL_ENV_VAR = "WEATHER_MCP_ISSUER_URL"
# The default is deliberately a loopback dev URL, not a public one: an unset
# variable should fail obviously in dev rather than advertise OAuth endpoints on
# a host this process does not control. Deployments always set it explicitly.
# It must stay localhost/127.0.0.1 - validate_issuer_url() rejects any other
# non-HTTPS host, so e.g. "http://0.0.0.0:5000" would raise at import.
_raw_issuer_url = os.environ.get(
    WEATHER_MCP_ISSUER_URL_ENV_VAR,
    "http://localhost:5000",
)
# Normalize once through pydantic and reuse the *exact* same string
# everywhere a client might compare it byte-for-byte against the AS
# metadata's "issuer" field (e.g. RFC 9728's authorization_servers) -
# AnyHttpUrl always adds a trailing "/" to a bare origin, so building that
# string separately (e.g. from the raw env var) would silently disagree
# with what create_auth_routes() emits and break spec-compliant discovery.
_issuer_url_model = AnyHttpUrl(_raw_issuer_url)
ISSUER_URL = str(_issuer_url_model)  # e.g. "https://weather.example/" - matches OAuthMetadata.issuer
ISSUER_ORIGIN = ISSUER_URL.rstrip("/")  # for concatenating paths without a double slash

WEATHER_MCP_OAUTH_STORE_PATH_ENV_VAR = "WEATHER_MCP_OAUTH_STORE_PATH"
OAUTH_STORE_PATH = os.environ.get(
    WEATHER_MCP_OAUTH_STORE_PATH_ENV_VAR,
    str(Path(__file__).parent / ".oauth_store.json"),
)

oauth_provider = WeatherOAuthProvider(issuer_url=ISSUER_ORIGIN, store_path=OAUTH_STORE_PATH)

auth_routes = create_auth_routes(
    oauth_provider,
    issuer_url=_issuer_url_model,
    client_registration_options=ClientRegistrationOptions(
        enabled=True, valid_scopes=["weather"], default_scopes=["weather"]
    ),
    revocation_options=RevocationOptions(enabled=True),
)

PROTECTED_RESOURCE_METADATA = {
    "resource": f"{ISSUER_ORIGIN}/mcp",
    "authorization_servers": [ISSUER_URL],
    "bearer_methods_supported": ["header"],
    "scopes_supported": ["weather"],
}


async def protected_resource_metadata(request: Request) -> Response:
    return JSONResponse(PROTECTED_RESOURCE_METADATA)


async def health(request: Request) -> Response:
    """Liveness probe for the container healthcheck and post-deploy verification.

    Deliberately does no I/O - it must stay cheap enough to poll every 30s and
    must not depend on NWS/Open-Meteo being reachable. Unauthenticated by
    construction: _BearerAuthASGIApp wraps only the /mcp mount, never a sibling
    Route, so this stays probeable with no token.
    """
    return JSONResponse({"status": "ok"})


_LOGIN_FORM_TEMPLATE = """<!doctype html>
<title>Weather MCP - Log in</title>
<body style="font-family: sans-serif; max-width: 24rem; margin: 4rem auto;">
<h1>Weather MCP</h1>
{message}
<form method="post">
  <label for="password">Password</label><br>
  <input id="password" type="password" name="password" autofocus>
  <button type="submit">Log in</button>
</form>
</body>
"""


async def login_handler(request: Request) -> Response:
    request_id = request.query_params.get("request_id")
    if not request_id:
        return HTMLResponse("Missing request_id.", status_code=400)

    if request.method == "GET":
        return HTMLResponse(_LOGIN_FORM_TEMPLATE.format(message=""))

    token = os.environ.get(WEATHER_MCP_TOKEN_ENV_VAR)
    if not token:
        return HTMLResponse(
            f"OAuth login is disabled because {WEATHER_MCP_TOKEN_ENV_VAR} is not "
            "set on the server.",
            status_code=503,
        )

    form = await request.form()
    password = form.get("password", "")
    if not isinstance(password, str) or not compare_digest(
        password.encode("utf-8"), token.encode("utf-8")
    ):
        return HTMLResponse(
            _LOGIN_FORM_TEMPLATE.format(
                message="<p style='color:red'>Incorrect password.</p>"
            ),
            status_code=401,
        )

    try:
        redirect_url = await oauth_provider.finish_authorization(request_id)
    except UnknownAuthorizationRequestError:
        return HTMLResponse(
            "This login link has expired or was already used. Please restart "
            "the connection from your MCP client.",
            status_code=400,
        )

    return RedirectResponse(url=redirect_url, status_code=302)


class _BearerAuthASGIApp:
    """Requires `Authorization: Bearer <token>` on every request to the
    wrapped app, scoped only to whatever it wraps.

    Applied only to mcp_mount.app below (shared by both the bare "/mcp"
    Route and the "/mcp/..." Mount) - never to the Flask-mounted routes,
    which don't hold a reference to this class at all.

    Reads WEATHER_MCP_TOKEN from the environment on every call (not cached
    at import time) so it stays open by default for local dev when unset,
    and so tests can toggle it with monkeypatch without reimporting this
    module (weather_mcp's session manager is a singleton that can only be
    started once per process - see test_mcp_http_endpoint.py).

    Also accepts a valid OAuth-issued access token (see oauth_provider.py)
    as an alternative to the static token, so clients that completed the
    OAuth flow (e.g. claude.ai's web connector) and clients using the static
    secret (Claude Desktop, curl, Perplexity) both work against the same
    /mcp endpoint without reconfiguration on either side.
    """

    def __init__(self, app, oauth_provider):
        self._app = app
        self._oauth_provider = oauth_provider

    async def __call__(self, scope, receive, send):
        token = os.environ.get(WEATHER_MCP_TOKEN_ENV_VAR)
        if scope["type"] != "http" or not token:
            # No token configured -> auth disabled (open), matches local-dev
            # default. Non-http scopes (lifespan) always pass through.
            await self._app(scope, receive, send)
            return

        if scope["method"] == "OPTIONS":
            # Real CORS preflights never reach here (CORSMiddleware, which
            # wraps this whole app, answers them itself - see
            # starlette.middleware.cors.CORSMiddleware.__call__). This is a
            # defensive no-op for any other OPTIONS request.
            await self._app(scope, receive, send)
            return

        headers = Headers(scope=scope)
        auth_header = headers.get("authorization", "")
        expected = f"Bearer {token}"
        # Compare as bytes: Starlette decodes headers latin-1, and
        # secrets.compare_digest raises TypeError on non-ASCII str input,
        # which would turn a malformed header into a 500 instead of a 401.
        if compare_digest(auth_header.encode("utf-8"), expected.encode("utf-8")):
            await self._app(scope, receive, send)
            return

        if auth_header.startswith("Bearer "):
            candidate = auth_header[len("Bearer "):]
            if await self._oauth_provider.load_access_token(candidate) is not None:
                await self._app(scope, receive, send)
                return

        response = JSONResponse(
            {
                "error": "unauthorized",
                "message": "Missing or invalid bearer token. Provide an "
                "'Authorization: Bearer <token>' header, either the static "
                "token or one obtained via OAuth.",
            },
            status_code=401,
            headers={
                "WWW-Authenticate": (
                    f'Bearer resource_metadata="{ISSUER_ORIGIN}'
                    '/.well-known/oauth-protected-resource"'
                ),
            },
        )
        await response(scope, receive, send)


# Wrap once, in place: both the explicit Route("/mcp", ...) below and the
# Mount("/mcp/...") itself read mcp_mount.app, so this single wrap covers
# both routing entries into the MCP app. This line MUST run before the
# Route("/mcp", ...) below is constructed, since Route captures
# mcp_mount.app by value - moving this after that line would silently
# leave bare "/mcp" unauthenticated. It never touches Mount("/", wsgi_app)
# (the Flask app), which holds no reference to this wrapper.
mcp_mount.app = _BearerAuthASGIApp(mcp_mount.app, oauth_provider)


class _ASGIEndpoint:
    """Route() treats a plain function endpoint as `func(request) -> response`;
    wrapping it in a callable class makes Route treat it as a raw ASGI app
    instead, matching handle_streamable_http's real (scope, receive, send)
    signature."""

    def __init__(self, app):
        self._app = app

    async def __call__(self, scope, receive, send):
        await self._app(scope, receive, send)


app = Starlette(
    routes=[
        Route("/mcp", endpoint=_ASGIEndpoint(mcp_mount.app), methods=["GET", "POST", "DELETE"]),
        mcp_mount,
        Route("/login", endpoint=login_handler, methods=["GET", "POST"]),
        *auth_routes,
        Route(
            "/.well-known/oauth-protected-resource",
            endpoint=protected_resource_metadata,
            methods=["GET"],
        ),
        Route(
            "/.well-known/oauth-protected-resource/mcp",
            endpoint=protected_resource_metadata,
            methods=["GET"],
        ),
        Route("/health", endpoint=health, methods=["GET"]),
        Mount("/", wsgi_app),
    ],
    middleware=middleware,
    lifespan=lifespan,
)

if __name__ == '__main__':
    import uvicorn
    # Single process, single worker, always: weather_mcp.session_manager is a
    # stateful module-level singleton entered once by lifespan(), so a second
    # worker would intermittently fail with "No valid session ID provided".
    uvicorn.run(
        app,
        host=os.environ.get("WEATHER_MCP_HOST", "0.0.0.0"),
        port=int(os.environ.get("WEATHER_MCP_PORT", "5000")),
    )
