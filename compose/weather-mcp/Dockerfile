# Weather MCP server. Named Dockerfile, not Containerfile: localserver-config's
# scripts/build-stack.sh tests for "$dir/Dockerfile" and would otherwise skip the
# build silently.
#
# Both stages share one base image on purpose. The venv symlinks its interpreter
# by absolute path, so a .venv built on a different base (e.g. the uv image's
# bookworm-slim) would not run here. Copy in the uv binary instead.

# ---------- build: resolve deps from the lockfile, then gate on the tests ----------
FROM docker.io/library/python:3.13-slim AS build

COPY --from=ghcr.io/astral-sh/uv:0.9 /uv /bin/uv

WORKDIR /app
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never

# Lockfile first so the dependency layer caches independently of source edits.
# --frozen makes uv.lock authoritative: it errors rather than re-resolving if
# pyproject.toml has drifted.
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --extra dev

COPY . .

# The suite is fully offline - conftest.py's autouse respx_mock blocks every
# outbound request - so running it here is hermetic and needs nothing installed
# on the deploy target (beeblebox has neither uv nor Python 3.13).
RUN WEATHER_MCP_OAUTH_STORE_PATH=/tmp/oauth-store.json uv run pytest -q

# Rebuild the venv without dev deps for the runtime stage.
RUN rm -rf /app/.venv && uv sync --frozen --no-dev

# ---------- runtime ----------
FROM docker.io/library/python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/app/.venv/bin:$PATH" \
    WEATHER_MCP_HOST=0.0.0.0 \
    WEATHER_MCP_PORT=8094 \
    WEATHER_MCP_OAUTH_STORE_PATH=/data/oauth_store.json

# /data holds registered OAuth clients and refresh tokens. Creating and chowning
# it in the image means podman's copy-up gives the named volume this ownership on
# first mount; without it the non-root user cannot write the store.
RUN useradd -r -u 10001 -s /usr/sbin/nologin weather \
 && mkdir -p /app /data \
 && chown -R 10001:10001 /app /data

WORKDIR /app
COPY --from=build --chown=10001:10001 /app/.venv /app/.venv
COPY --chown=10001:10001 unified_server.py weather.py cities.py oauth_provider.py ./
COPY --chown=10001:10001 templates/ ./templates/

USER 10001
EXPOSE 8094

# Single process, single worker: weather_mcp.session_manager is a stateful
# module-level singleton entered once by the app's lifespan.
CMD ["python", "unified_server.py"]
