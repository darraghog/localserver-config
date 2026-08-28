"""Unit tests for the weather MCP tools (weather.py): get_alerts and get_forecast.

All NWS / Open-Meteo calls are mocked via respx fixtures from conftest.py -
no real network access.
"""
import httpx

from weather import get_alerts, get_forecast


class TestGetAlerts:
    async def test_returns_formatted_alerts(self, mock_nws_alerts):
        mock_nws_alerts(
            state="CA",
            features=[
                {
                    "properties": {
                        "event": "Special Weather Statement",
                        "areaDesc": "Mono County",
                        "severity": "Moderate",
                        "description": "Strong thunderstorms expected.",
                        "instruction": "Seek shelter.",
                    }
                }
            ],
        )

        result = await get_alerts("CA")

        assert "Special Weather Statement" in result
        assert "Mono County" in result
        assert "Moderate" in result
        assert "Seek shelter." in result

    async def test_no_active_alerts(self, mock_nws_alerts):
        mock_nws_alerts(state="CA", features=[])

        result = await get_alerts("CA")

        assert result == "No active alerts for this state."

    async def test_api_failure_returns_friendly_message(self, respx_mock):
        respx_mock.get("https://api.weather.gov/alerts/active/area/CA").mock(
            return_value=httpx.Response(500)
        )

        result = await get_alerts("CA")

        assert result == "Unable to fetch alerts or no alerts found."


class TestGetForecast:
    async def test_us_location_uses_nws(self, mock_nws_forecast):
        # San Francisco - inside the NWS coverage bounding box
        mock_nws_forecast(
            37.7749,
            -122.4194,
            periods=[
                {
                    "name": "Tonight",
                    "temperature": 58,
                    "temperatureUnit": "F",
                    "windSpeed": "10 mph",
                    "windDirection": "W",
                    "detailedForecast": "Clear skies.",
                }
            ],
        )

        result = await get_forecast(37.7749, -122.4194)

        assert "Tonight" in result
        assert "Clear skies." in result

    async def test_non_us_location_falls_back_to_open_meteo(self, mock_open_meteo_forecast):
        # London - outside the NWS coverage bounding box
        mock_open_meteo_forecast()

        result = await get_forecast(51.5074, -0.1278)

        assert "Current Weather" in result
        assert "Conditions:" in result

    async def test_us_coords_falls_back_when_nws_has_no_forecast_url(
        self, respx_mock, mock_open_meteo_forecast
    ):
        # NWS /points succeeds but has no usable forecast URL - must fall back
        respx_mock.get("https://api.weather.gov/points/37.7749,-122.4194").mock(
            return_value=httpx.Response(200, json={"properties": {}})
        )
        mock_open_meteo_forecast()

        result = await get_forecast(37.7749, -122.4194)

        assert "Current Weather" in result

    async def test_all_sources_fail_returns_friendly_message(self, respx_mock):
        respx_mock.get("https://api.weather.gov/points/37.7749,-122.4194").mock(
            return_value=httpx.Response(500)
        )
        respx_mock.get("https://api.open-meteo.com/v1/forecast").mock(
            return_value=httpx.Response(500)
        )

        result = await get_forecast(37.7749, -122.4194)

        assert result == "Unable to fetch forecast data for this location."
