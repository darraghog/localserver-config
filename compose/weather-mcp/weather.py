from  typing import Annotated, Any
import httpx
from mcp.server.fastmcp import FastMCP
from pydantic import Field

# initialize fastmcp server
mcp = FastMCP("weather")

# constants
NWS_API_BASE = "https://api.weather.gov"
OPEN_METEO_API_BASE = "https://api.open-meteo.com/v1"
USER_AGENT = "weather-app/1.0"

# Weather code descriptions (WMO codes)
WEATHER_CODES = {
    0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
    45: "Foggy", 48: "Depositing rime fog",
    51: "Light drizzle", 53: "Moderate drizzle", 55: "Dense drizzle",
    61: "Slight rain", 63: "Moderate rain", 65: "Heavy rain",
    71: "Slight snow", 73: "Moderate snow", 75: "Heavy snow",
    77: "Snow grains",
    80: "Slight rain showers", 81: "Moderate rain showers", 82: "Violent rain showers",
    85: "Slight snow showers", 86: "Heavy snow showers",
    95: "Thunderstorm", 96: "Thunderstorm with slight hail", 99: "Thunderstorm with heavy hail"
}

async def make_api_request(url: str, params: dict[str, Any] | None = None, headers: dict[str, str] | None = None) -> dict[str, Any] | None:
    """Make an HTTP request with proper error handling.

    Args:
        url: The URL to request
        params: Optional query parameters
        headers: Optional HTTP headers

    Returns:
        JSON response or None if failed
    """
    async with httpx.AsyncClient(follow_redirects=True) as client:
        try:
            response = await client.get(url, params=params, headers=headers, timeout=30.0)
            response.raise_for_status()
            return response.json()
        except Exception:
            return None

def format_alert(feature: dict) -> str:
    """Format an alert feature into a readable string."""
    props = feature["properties"]
    return f"""
Event: {props.get('event', 'Unknown')}
Area: {props.get('areaDesc', 'Unknown')}
Severity: {props.get('severity', 'Unknown')}
Description: {props.get('description', 'No description available')}
Instructions: {props.get('instruction', 'No specific instructions provided')}
"""

@mcp.tool()
async def get_alerts(
    state: Annotated[
        str,
        Field(
            description="Two-letter US state or territory postal code (e.g. 'CA', "
            "'NY', 'PR'). Not a full state name."
        ),
    ],
) -> str:
    """Get active severe weather alerts (warnings, watches, and advisories) for a
    US state or territory, from the National Weather Service.

    Use this for questions about tornado warnings, flood watches, winter storm
    advisories, hurricane warnings, or any other *currently active* severe-weather
    alert in a specific US state. US/territories only - for any other location, or
    for a general forecast/outlook question anywhere in the world (including the
    US), use get_forecast instead. This tool does not return temperature,
    precipitation chance, or multi-day forecast data.

    Args:
        state: Two-letter US state code (e.g. CA, NY)
    """
    url = f"{NWS_API_BASE}/alerts/active/area/{state}"
    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "application/geo+json"
    }
    data = await make_api_request(url, headers=headers)

    if not data or "features" not in data:
        return "Unable to fetch alerts or no alerts found."

    if not data["features"]:
        return "No active alerts for this state."

    alerts = [format_alert(feature) for feature in data["features"]]
    return "\n---\n".join(alerts)

async def get_forecast_open_meteo(latitude: float, longitude: float) -> str | None:
    """Get weather forecast using Open-Meteo API (worldwide coverage).

    Args:
        latitude: Latitude of the location
        longitude: Longitude of the location

    Returns:
        Formatted forecast string or None if failed
    """
    # Request forecast data from Open-Meteo
    url = f"{OPEN_METEO_API_BASE}/forecast"
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "daily": "temperature_2m_max,temperature_2m_min,precipitation_sum,windspeed_10m_max,weathercode",
        "current_weather": "true",
        "temperature_unit": "fahrenheit",
        "windspeed_unit": "mph",
        "precipitation_unit": "inch",
        "timezone": "auto",
        "forecast_days": 5
    }

    data = await make_api_request(url, params=params)

    if not data or "daily" not in data:
        return None

    daily = data["daily"]
    current = data.get("current_weather", {})

    forecasts = []

    # Add current weather if available
    if current:
        current_temp = current.get("temperature", "N/A")
        current_wind = current.get("windspeed", "N/A")
        current_code = current.get("weathercode", 0)
        current_condition = WEATHER_CODES.get(current_code, "Unknown")

        forecasts.append(f"""
Current Weather:
Temperature: {current_temp}°F
Wind: {current_wind} mph
Conditions: {current_condition}
""")

    # Format daily forecast
    times = daily.get("time", [])
    max_temps = daily.get("temperature_2m_max", [])
    min_temps = daily.get("temperature_2m_min", [])
    precip = daily.get("precipitation_sum", [])
    wind = daily.get("windspeed_10m_max", [])
    codes = daily.get("weathercode", [])

    for i in range(min(5, len(times))):
        day_name = "Today" if i == 0 else times[i] if i < len(times) else f"Day {i+1}"
        max_temp = max_temps[i] if i < len(max_temps) else "N/A"
        min_temp = min_temps[i] if i < len(min_temps) else "N/A"
        precip_amt = precip[i] if i < len(precip) else 0
        wind_speed = wind[i] if i < len(wind) else "N/A"
        weather_code = codes[i] if i < len(codes) else 0
        condition = WEATHER_CODES.get(weather_code, "Unknown")

        forecast = f"""
{day_name}:
High: {max_temp}°F / Low: {min_temp}°F
Wind: {wind_speed} mph
Precipitation: {precip_amt} inches
Conditions: {condition}
"""
        forecasts.append(forecast)

    return "\n---\n".join(forecasts)

@mcp.tool()
async def get_forecast(
    latitude: Annotated[
        float,
        Field(
            description="Decimal latitude in degrees, e.g. 37.7749. Not a city "
            "name - geocode to coordinates first if you only have a place name."
        ),
    ],
    longitude: Annotated[
        float,
        Field(description="Decimal longitude in degrees, e.g. -122.4194."),
    ],
) -> str:
    """Get current conditions plus a 5-day weather forecast for any location
    worldwide, given its coordinates.

    Use this for questions about upcoming weather, temperature, precipitation
    chance, wind, or general conditions ("what's the weather like in Tokyo this
    week", "will it rain tomorrow in Denver", "should I bring a jacket"). Works
    anywhere in the world - uses the US National Weather Service for higher-detail
    US forecasts and falls back to Open-Meteo elsewhere. For currently active
    severe-weather warnings/watches/advisories in a US state specifically, use
    get_alerts instead - this tool does not return alert data.

    Args:
        latitude: Decimal latitude, e.g. 37.7749
        longitude: Decimal longitude, e.g. -122.4194
    """
    # Try NWS API first (US locations only, more detailed)
    # NWS covers roughly 24°N to 50°N, -125°W to -66°W
    is_likely_us = (24 <= latitude <= 50 and -125 <= longitude <= -66)

    if is_likely_us:
        points_url = f"{NWS_API_BASE}/points/{latitude},{longitude}"
        nws_headers = {
            "User-Agent": USER_AGENT,
            "Accept": "application/geo+json"
        }
        points_data = await make_api_request(points_url, headers=nws_headers)

        if points_data and "properties" in points_data:
            forecast_url = points_data["properties"].get("forecast")
            if forecast_url:
                forecast_data = await make_api_request(forecast_url, headers=nws_headers)

                if forecast_data and "properties" in forecast_data:
                    # Format NWS forecast
                    periods = forecast_data["properties"]["periods"]
                    forecasts = []
                    for period in periods[:5]:
                        forecast = f"""
{period['name']}:
Temperature: {period['temperature']}°{period['temperatureUnit']}
Wind: {period['windSpeed']} {period['windDirection']}
Forecast: {period['detailedForecast']}
"""
                        forecasts.append(forecast)
                    return "\n---\n".join(forecasts)

    # Fall back to Open-Meteo for international or if NWS fails
    open_meteo_result = await get_forecast_open_meteo(latitude, longitude)

    if open_meteo_result:
        return open_meteo_result

    return "Unable to fetch forecast data for this location."


if __name__ == "__main__":
    # Initialize and run the server
    mcp.run(transport='stdio')