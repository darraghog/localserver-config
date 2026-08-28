"""Tests for the city-lookup -> forecast chain (cities.py + weather.py together).

Covers get_all_cities()/get_city_coordinates() for known static cities, and
the end-to-end flow of geocoding an unknown city and then fetching its
forecast - the path web_server.py's /api/forecast route relies on.
All network calls are mocked via respx fixtures from conftest.py.
"""
from cities import get_all_cities, get_city_coordinates
from weather import get_forecast


class TestCityLookup:
    def test_get_all_cities_includes_known_static_cities(self):
        cities = get_all_cities()

        assert len(cities) > 0
        for city in ("San Francisco, CA", "London, UK", "Tokyo, Japan", "Sydney, Australia"):
            assert city in cities

    async def test_get_city_coordinates_for_static_cities(self):
        expected = {
            "San Francisco, CA": (37.7749, -122.4194),
            "London, UK": (51.5074, -0.1278),
            "Tokyo, Japan": (35.6762, 139.6503),
            "New York City, NY": (40.7128, -74.0060),
        }

        for city, (expected_lat, expected_lon) in expected.items():
            coords, newly_added = await get_city_coordinates(city)

            assert coords == (expected_lat, expected_lon)
            assert newly_added is False


class TestGeocodeThenForecastChain:
    async def test_static_city_coordinates_feed_into_forecast(self, mock_nws_forecast):
        coords, _ = await get_city_coordinates("San Francisco, CA")
        lat, lng = coords
        mock_nws_forecast(lat, lng, periods=[
            {
                "name": "Today",
                "temperature": 65,
                "temperatureUnit": "F",
                "windSpeed": "8 mph",
                "windDirection": "W",
                "detailedForecast": "Sunny with fog clearing by afternoon.",
            }
        ])

        forecast = await get_forecast(lat, lng)

        assert "Today" in forecast
        assert "Sunny with fog clearing by afternoon." in forecast

    async def test_newly_geocoded_city_feeds_into_forecast(
        self, mock_geocode, mock_open_meteo_forecast
    ):
        mock_geocode(lat=64.1466, lon=-21.9426)  # Reykjavik, Iceland - not in MAJOR_CITIES
        mock_open_meteo_forecast()

        coords, newly_added = await get_city_coordinates("Reykjavik, Iceland")
        assert newly_added is True
        lat, lng = coords

        forecast = await get_forecast(lat, lng)

        assert "Current Weather" in forecast
