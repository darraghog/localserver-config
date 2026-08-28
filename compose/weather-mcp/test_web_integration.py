#!/usr/bin/env python3
"""Integration tests for web server and dynamic city functionality."""

import pytest
import json
from cities import DYNAMIC_CITIES


@pytest.fixture
def client(web_server_client):
    """Alias for the shared web_server_client fixture (kept for readability below)."""
    return web_server_client


class TestWebIntegration:
    """Test web server integration with dynamic cities."""

    def test_cities_endpoint_returns_static_cities(self, client):
        """Test that /api/cities returns static cities."""
        response = client.get('/api/cities')
        assert response.status_code == 200

        data = json.loads(response.data)
        assert 'cities' in data
        assert isinstance(data['cities'], list)
        assert len(data['cities']) > 0

        # Check for some known static cities
        cities = data['cities']
        assert 'London, UK' in cities
        assert 'Tokyo, Japan' in cities
        assert 'Summit, NJ' in cities

    def test_forecast_adds_city_to_dynamic_list(self, client, mock_geocode, mock_open_meteo_forecast):
        """Test that requesting forecast for new city adds it to the list."""
        test_city = "Lillehammer, Norway"
        mock_geocode(lat=61.1153, lon=10.4662)
        mock_open_meteo_forecast()

        # Get initial cities list
        response1 = client.get('/api/cities')
        initial_cities = json.loads(response1.data)['cities']
        assert test_city not in initial_cities

        # Request forecast for new city
        response2 = client.post(
            '/api/forecast',
            data=json.dumps({'city': test_city}),
            content_type='application/json'
        )
        assert response2.status_code == 200

        forecast_data = json.loads(response2.data)
        assert 'location' in forecast_data
        assert forecast_data['location']['city'] == test_city
        assert forecast_data['location']['newly_added'] is True

        # Verify city now appears in cities list
        response3 = client.get('/api/cities')
        updated_cities = json.loads(response3.data)['cities']
        assert test_city in updated_cities

    def test_city_coordinates_endpoint_adds_to_list(self, client, mock_geocode):
        """Test that /api/city-coordinates adds new cities to the list."""
        test_city = "Arendal, Norway"
        mock_geocode(lat=58.4614, lon=8.7726)

        # Get initial list
        response1 = client.get('/api/cities')
        initial_cities = json.loads(response1.data)['cities']
        assert test_city not in initial_cities

        # Request coordinates
        response2 = client.post(
            '/api/city-coordinates',
            data=json.dumps({'city': test_city}),
            content_type='application/json'
        )
        assert response2.status_code == 200

        coords_data = json.loads(response2.data)
        assert coords_data['city'] == test_city
        assert coords_data['newly_added'] is True

        # Verify city is now in the list
        response3 = client.get('/api/cities')
        updated_cities = json.loads(response3.data)['cities']
        assert test_city in updated_cities

    def test_multiple_cities_added_dynamically(self, client, mock_geocode, mock_open_meteo_forecast):
        """Test that multiple dynamically added cities all appear in the list."""
        test_cities = [
            "Drammen, Norway",
            "Kristiansand, Norway",
            "Haugesund, Norway"
        ]
        mock_geocode()
        mock_open_meteo_forecast()

        # Add cities via forecast requests
        for city in test_cities:
            client.post(
                '/api/forecast',
                data=json.dumps({'city': city}),
                content_type='application/json'
            )

        # Verify all appear in cities list
        response = client.get('/api/cities')
        all_cities = json.loads(response.data)['cities']

        for city in test_cities:
            assert city in all_cities, f"{city} should be in cities list"

    def test_second_request_not_marked_as_new(self, client, mock_geocode, mock_open_meteo_forecast):
        """Test that a city is not marked as new on the second request."""
        test_city = "Alesund, Norway"
        mock_geocode(lat=62.4722, lon=6.1495)
        mock_open_meteo_forecast()

        # First request
        response1 = client.post(
            '/api/forecast',
            data=json.dumps({'city': test_city}),
            content_type='application/json'
        )
        data1 = json.loads(response1.data)
        assert data1['location']['newly_added'] is True

        # Second request
        response2 = client.post(
            '/api/forecast',
            data=json.dumps({'city': test_city}),
            content_type='application/json'
        )
        data2 = json.loads(response2.data)
        assert data2['location']['newly_added'] is False

    def test_cities_list_sorted(self, client):
        """Test that cities list is returned in sorted order."""
        # Add some cities
        test_cities = ["Zulu City", "Alpha City", "Beta City"]
        for city in test_cities:
            DYNAMIC_CITIES[city] = (0.0, 0.0)

        response = client.get('/api/cities')
        all_cities = json.loads(response.data)['cities']

        # Verify sorting
        assert all_cities == sorted(all_cities), "Cities should be sorted alphabetically"


class TestDropdownIntegration:
    """Test that the dropdown will show dynamically added cities."""

    def test_dynamic_city_available_for_dropdown(self, client, mock_geocode, mock_open_meteo_forecast):
        """Test end-to-end: Add city, verify it's in /api/cities for dropdown."""
        test_city = "Molde, Norway"
        mock_geocode(lat=62.7372, lon=7.1607)
        mock_open_meteo_forecast()

        # Step 1: User enters new city in web form (simulated by forecast request)
        response1 = client.post(
            '/api/forecast',
            data=json.dumps({'city': test_city}),
            content_type='application/json'
        )
        assert response1.status_code == 200

        # Step 2: Frontend loads cities for dropdown (simulated by /api/cities request)
        response2 = client.get('/api/cities')
        cities_for_dropdown = json.loads(response2.data)['cities']

        # Step 3: Verify new city is available in dropdown
        assert test_city in cities_for_dropdown, \
            "Dynamically added city should be available in dropdown"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
