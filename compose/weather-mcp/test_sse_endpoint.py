"""Tests for the MCP tool layer exposed over HTTP (unified_server.py mounts
weather.mcp.streamable_http_app()).

Rather than requiring a live server and a real HTTP connection, these tests
exercise the same FastMCP tool-dispatch path (registration + `call_tool`)
in-process. That's what actually matters for correctness; the raw transport
plumbing is framework code (Starlette/FastMCP), not app logic. See
test_mcp_http_endpoint.py for a regression test covering the app-specific
route/lifespan wiring in unified_server.py itself.
"""
import httpx

from weather import mcp


class TestToolRegistration:
    async def test_expected_tools_are_registered(self):
        tools = await mcp.list_tools()
        tool_names = {tool.name for tool in tools}

        assert "get_alerts" in tool_names
        assert "get_forecast" in tool_names

    async def test_get_alerts_state_param_has_schema_description(self):
        """The per-parameter JSON schema description is what most tool-use
        implementations bind to "what should I put here?" - unlike the
        docstring's Args: section, it's only populated by an explicit
        Annotated[..., Field(description=...)] on the parameter (verified
        against mcp/server/fastmcp/utilities/func_metadata.py)."""
        tools = await mcp.list_tools()
        get_alerts_tool = next(t for t in tools if t.name == "get_alerts")

        assert get_alerts_tool.inputSchema["properties"]["state"].get("description")

    async def test_get_forecast_params_have_schema_descriptions(self):
        tools = await mcp.list_tools()
        get_forecast_tool = next(t for t in tools if t.name == "get_forecast")

        assert get_forecast_tool.inputSchema["properties"]["latitude"].get("description")
        assert get_forecast_tool.inputSchema["properties"]["longitude"].get("description")


class TestToolDispatch:
    async def test_call_tool_get_alerts(self, mock_nws_alerts):
        mock_nws_alerts(state="NY", features=[])

        # mcp >=1.10: call_tool returns (content_blocks, structured_content).
        content, _structured = await mcp.call_tool("get_alerts", {"state": "NY"})

        assert len(content) == 1
        assert content[0].text == "No active alerts for this state."

    async def test_call_tool_get_forecast(self, mock_nws_forecast):
        mock_nws_forecast(
            40.7128,
            -74.0060,
            periods=[
                {
                    "name": "This Afternoon",
                    "temperature": 75,
                    "temperatureUnit": "F",
                    "windSpeed": "12 mph",
                    "windDirection": "S",
                    "detailedForecast": "Partly sunny.",
                }
            ],
        )

        # mcp >=1.10: call_tool returns (content_blocks, structured_content).
        content, _structured = await mcp.call_tool(
            "get_forecast", {"latitude": 40.7128, "longitude": -74.0060}
        )

        assert len(content) == 1
        assert "This Afternoon" in content[0].text
        assert "Partly sunny." in content[0].text
