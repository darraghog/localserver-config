"""Smoke tests for unified_server.py's Flask routes.

web_server.py and unified_server.py define the same routes as separate,
copy-pasted functions (not shared code), so exercising web_server.py's
routes elsewhere in the suite does not cover unified_server.py's. This
file gives unified_server.py - the module actually launched by
start_server.sh - its own direct coverage.
"""
import json


class TestUnifiedServerRoutes:
    def test_index_page_loads(self, unified_flask_client):
        response = unified_flask_client.get("/")
        assert response.status_code == 200

    def test_cities_endpoint(self, unified_flask_client):
        response = unified_flask_client.get("/api/cities")
        assert response.status_code == 200

        cities = json.loads(response.data)["cities"]
        assert "London, UK" in cities

    def test_alerts_endpoint(self, unified_flask_client, mock_nws_alerts):
        mock_nws_alerts(state="NY", features=[])

        response = unified_flask_client.post(
            "/api/alerts",
            data=json.dumps({"state": "NY"}),
            content_type="application/json",
        )

        assert response.status_code == 200
        assert json.loads(response.data)["result"] == "No active alerts for this state."

    def test_forecast_endpoint_for_static_city(self, unified_flask_client, mock_nws_forecast):
        mock_nws_forecast(40.7128, -74.0060, periods=[
            {
                "name": "Tonight",
                "temperature": 60,
                "temperatureUnit": "F",
                "windSpeed": "5 mph",
                "windDirection": "N",
                "detailedForecast": "Clear.",
            }
        ])

        response = unified_flask_client.post(
            "/api/forecast",
            data=json.dumps({"city": "New York City, NY"}),
            content_type="application/json",
        )

        assert response.status_code == 200
        data = json.loads(response.data)
        assert data["location"]["city"] == "New York City, NY"
        assert "Tonight" in data["result"]
