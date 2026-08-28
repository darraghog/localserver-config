#!/usr/bin/env python3
"""Web GUI for the Weather MCP Server."""

import asyncio
from typing import Any, Coroutine
from flask import Flask, render_template, request, jsonify, Response
from weather import get_alerts, get_forecast
from cities import get_all_cities, get_city_coordinates

app = Flask(__name__)

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

@app.route('/')
def index():
    """Serve the main web interface."""
    return render_template('index.html')

@app.route('/api/alerts', methods=['POST'])
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

@app.route('/api/cities', methods=['GET'])
def api_cities():
    """API endpoint to get all available cities."""
    try:
        cities = get_all_cities()
        return jsonify({'cities': cities})
    except Exception as e:
        return jsonify({'error': f'Error fetching cities: {str(e)}'}), 500

@app.route('/api/city-coordinates', methods=['POST'])
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

@app.route('/api/forecast', methods=['POST'])
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

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)