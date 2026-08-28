#!/usr/bin/env python3
"""City lookup table with major world cities and their coordinates."""

import httpx
import asyncio

# In-memory cache for dynamically discovered cities
DYNAMIC_CITIES = {}

MAJOR_CITIES = {
    # North America
    "New York City, NY": (40.7128, -74.0060),
    "Los Angeles, CA": (34.0522, -118.2437),
    "Chicago, IL": (41.8781, -87.6298),
    "Houston, TX": (29.7604, -95.3698),
    "Phoenix, AZ": (33.4484, -112.0740),
    "Philadelphia, PA": (39.9526, -75.1652),
    "San Antonio, TX": (29.4241, -98.4936),
    "San Diego, CA": (32.7157, -117.1611),
    "Dallas, TX": (32.7767, -96.7970),
    "San Jose, CA": (37.3382, -121.8863),
    "Austin, TX": (30.2672, -97.7431),
    "Jacksonville, FL": (30.3322, -81.6557),
    "Fort Worth, TX": (32.7555, -97.3308),
    "Columbus, OH": (39.9612, -82.9988),
    "Charlotte, NC": (35.2271, -80.8431),
    "San Francisco, CA": (37.7749, -122.4194),
    "Indianapolis, IN": (39.7684, -86.1581),
    "Seattle, WA": (47.6062, -122.3321),
    "Denver, CO": (39.7392, -104.9903),
    "Washington, DC": (38.9072, -77.0369),
    "Boston, MA": (42.3601, -71.0589),
    "El Paso, TX": (31.7619, -106.4850),
    "Nashville, TN": (36.1627, -86.7816),
    "Detroit, MI": (42.3314, -83.0458),
    "Oklahoma City, OK": (35.4676, -97.5164),
    "Portland, OR": (45.5152, -122.6784),
    "Las Vegas, NV": (36.1699, -115.1398),
    "Memphis, TN": (35.1495, -90.0490),
    "Louisville, KY": (38.2527, -85.7585),
    "Baltimore, MD": (39.2904, -76.6122),
    "Milwaukee, WI": (43.0389, -87.9065),
    "Albuquerque, NM": (35.0844, -106.6504),
    "Tucson, AZ": (32.2226, -110.9747),
    "Fresno, CA": (36.7378, -119.7871),
    "Sacramento, CA": (38.5816, -121.4944),
    "Mesa, AZ": (33.4152, -111.8315),
    "Kansas City, MO": (39.0997, -94.5786),
    "Atlanta, GA": (33.7490, -84.3880),
    "Long Beach, CA": (33.7701, -118.1937),
    "Colorado Springs, CO": (38.8339, -104.8214),
    "Raleigh, NC": (35.7796, -78.6382),
    "Miami, FL": (25.7617, -80.1918),
    "Virginia Beach, VA": (36.8529, -75.9780),
    "Omaha, NE": (41.2565, -95.9345),
    "Oakland, CA": (37.8044, -122.2712),
    "Minneapolis, MN": (44.9778, -93.2650),
    "Tulsa, OK": (36.1540, -95.9928),
    "Arlington, TX": (32.7357, -97.1081),
    "New Orleans, LA": (29.9511, -90.0715),
    "Wichita, KS": (37.6872, -97.3301),

    # New Jersey
    "Newark, NJ": (40.7357, -74.1724),
    "Jersey City, NJ": (40.7178, -74.0431),
    "Paterson, NJ": (40.9168, -74.1718),
    "Elizabeth, NJ": (40.6640, -74.2107),
    "Edison, NJ": (40.5187, -74.4121),
    "Trenton, NJ": (40.2171, -74.7429),
    "Atlantic City, NJ": (39.3643, -74.4229),
    "Princeton, NJ": (40.3573, -74.6672),
    "Hoboken, NJ": (40.7439, -74.0323),
    "Summit, NJ": (40.7157, -74.3649),

    # Canada
    "Toronto, Canada": (43.6532, -79.3832),
    "Vancouver, Canada": (49.2827, -123.1207),
    "Montreal, Canada": (45.5017, -73.5673),
    "Calgary, Canada": (51.0447, -114.0719),
    "Edmonton, Canada": (53.5461, -113.4938),
    "Ottawa, Canada": (45.4215, -75.6972),
    "Winnipeg, Canada": (49.8951, -97.1384),
    "Quebec City, Canada": (46.8139, -71.2080),
    
    # Mexico
    "Mexico City, Mexico": (19.4326, -99.1332),
    "Guadalajara, Mexico": (20.6597, -103.3496),
    "Monterrey, Mexico": (25.6866, -100.3161),
    "Puebla, Mexico": (19.0414, -98.2063),
    "Tijuana, Mexico": (32.5027, -117.0039),
    "León, Mexico": (21.1619, -101.6971),
    "Juárez, Mexico": (31.6904, -106.4245),
    "Zapopan, Mexico": (20.7214, -103.3918),
    
    # Europe
    "London, UK": (51.5074, -0.1278),
    "Berlin, Germany": (52.5200, 13.4050),
    "Madrid, Spain": (40.4168, -3.7038),
    "Rome, Italy": (41.9028, 12.4964),
    "Paris, France": (48.8566, 2.3522),
    "Vienna, Austria": (48.2082, 16.3738),
    "Warsaw, Poland": (52.2297, 21.0122),
    "Budapest, Hungary": (47.4979, 19.0402),
    "Barcelona, Spain": (41.3851, 2.1734),
    "Munich, Germany": (48.1351, 11.5820),
    "Milan, Italy": (45.4642, 9.1900),
    "Prague, Czech Republic": (50.0755, 14.4378),
    "Amsterdam, Netherlands": (52.3676, 4.9041),
    "Brussels, Belgium": (50.8503, 4.3517),
    "Zurich, Switzerland": (47.3769, 8.5417),
    "Stockholm, Sweden": (59.3293, 18.0686),
    "Oslo, Norway": (59.9139, 10.7522),
    "Copenhagen, Denmark": (55.6761, 12.5683),
    "Helsinki, Finland": (60.1699, 24.9384),
    "Dublin, Ireland": (53.3498, -6.2603),
    "Lisbon, Portugal": (38.7223, -9.1393),
    "Athens, Greece": (37.9755, 23.7348),
    "Istanbul, Turkey": (41.0082, 28.9784),
    "Moscow, Russia": (55.7558, 37.6176),
    "St. Petersburg, Russia": (59.9311, 30.3609),
    
    # Asia
    "Tokyo, Japan": (35.6762, 139.6503),
    "Beijing, China": (39.9042, 116.4074),
    "Shanghai, China": (31.2304, 121.4737),
    "Mumbai, India": (19.0760, 72.8777),
    "Delhi, India": (28.7041, 77.1025),
    "Bangalore, India": (12.9716, 77.5946),
    "Kolkata, India": (22.5726, 88.3639),
    "Chennai, India": (13.0827, 80.2707),
    "Hyderabad, India": (17.3850, 78.4867),
    "Pune, India": (18.5204, 73.8567),
    "Seoul, South Korea": (37.5665, 126.9780),
    "Bangkok, Thailand": (13.7563, 100.5018),
    "Manila, Philippines": (14.5995, 120.9842),
    "Jakarta, Indonesia": (6.2088, 106.8456),
    "Singapore": (1.3521, 103.8198),
    "Kuala Lumpur, Malaysia": (3.1390, 101.6869),
    "Ho Chi Minh City, Vietnam": (10.8231, 106.6297),
    "Hanoi, Vietnam": (21.0285, 105.8542),
    "Taipei, Taiwan": (25.0330, 121.5654),
    "Hong Kong": (22.3193, 114.1694),
    "Macau": (22.1987, 113.5439),
    "Dhaka, Bangladesh": (23.8103, 90.4125),
    "Karachi, Pakistan": (24.8607, 67.0011),
    "Lahore, Pakistan": (31.5204, 74.3587),
    "Islamabad, Pakistan": (33.6844, 73.0479),
    "Kathmandu, Nepal": (27.7172, 85.3240),
    "Colombo, Sri Lanka": (6.9271, 79.8612),
    
    # Middle East
    "Dubai, UAE": (25.2048, 55.2708),
    "Abu Dhabi, UAE": (24.4539, 54.3773),
    "Riyadh, Saudi Arabia": (24.7136, 46.6753),
    "Kuwait City, Kuwait": (29.3759, 47.9774),
    "Doha, Qatar": (25.2854, 51.5310),
    "Manama, Bahrain": (26.0667, 50.5577),
    "Muscat, Oman": (23.5859, 58.4059),
    "Tehran, Iran": (35.6892, 51.3890),
    "Baghdad, Iraq": (33.3152, 44.3661),
    "Damascus, Syria": (33.5138, 36.2765),
    "Beirut, Lebanon": (33.8938, 35.5018),
    "Amman, Jordan": (31.9454, 35.9284),
    "Jerusalem, Israel": (31.7683, 35.2137),
    "Tel Aviv, Israel": (32.0853, 34.7818),
    
    # Africa
    "Cairo, Egypt": (30.0444, 31.2357),
    "Lagos, Nigeria": (6.5244, 3.3792),
    "Johannesburg, South Africa": (26.2041, 28.0473),
    "Cape Town, South Africa": (33.9249, 18.4241),
    "Casablanca, Morocco": (33.5731, -7.5898),
    "Tunis, Tunisia": (36.8065, 10.1815),
    "Algiers, Algeria": (36.7539, 3.0588),
    "Tripoli, Libya": (32.8872, 13.1913),
    "Khartoum, Sudan": (15.5007, 32.5599),
    "Addis Ababa, Ethiopia": (9.1450, 38.7451),
    "Nairobi, Kenya": (1.2921, 36.8219),
    "Dar es Salaam, Tanzania": (6.7924, 39.2083),
    "Kampala, Uganda": (0.3476, 32.5825),
    "Kigali, Rwanda": (1.9441, 30.0619),
    "Accra, Ghana": (5.6037, -0.1870),
    "Abidjan, Ivory Coast": (5.3600, -4.0083),
    "Dakar, Senegal": (14.7167, -17.4677),
    "Bamako, Mali": (12.6392, -8.0029),
    "Ouagadougou, Burkina Faso": (12.3714, -1.5197),
    "Niamey, Niger": (13.5116, 2.1254),
    "N'Djamena, Chad": (12.1348, 15.0557),
    
    # South America
    "São Paulo, Brazil": (-23.5505, -46.6333),
    "Rio de Janeiro, Brazil": (-22.9068, -43.1729),
    "Buenos Aires, Argentina": (-34.6118, -58.3960),
    "Lima, Peru": (-12.0464, -77.0428),
    "Bogotá, Colombia": (4.7110, -74.0721),
    "Santiago, Chile": (-33.4489, -70.6693),
    "Caracas, Venezuela": (10.4806, -66.9036),
    "Quito, Ecuador": (-0.1807, -78.4678),
    "La Paz, Bolivia": (-16.5000, -68.1193),
    "Asunción, Paraguay": (-25.2637, -57.5759),
    "Montevideo, Uruguay": (-34.9011, -56.1645),
    "Georgetown, Guyana": (6.8013, -58.1551),
    "Paramaribo, Suriname": (5.8520, -55.2038),
    "Brasília, Brazil": (-15.8267, -47.9218),
    "Salvador, Brazil": (-12.9714, -38.5014),
    "Fortaleza, Brazil": (-3.7319, -38.5267),
    "Belo Horizonte, Brazil": (-19.8157, -43.9542),
    "Manaus, Brazil": (-3.1190, -60.0217),
    "Curitiba, Brazil": (-25.4284, -49.2733),
    "Recife, Brazil": (-8.0476, -34.8770),
    "Porto Alegre, Brazil": (-30.0346, -51.2177),
    
    # Oceania
    "Sydney, Australia": (-33.8688, 151.2093),
    "Melbourne, Australia": (-37.8136, 144.9631),
    "Brisbane, Australia": (-27.4698, 153.0251),
    "Perth, Australia": (-31.9505, 115.8605),
    "Adelaide, Australia": (-34.9285, 138.6007),
    "Canberra, Australia": (-35.2809, 149.1300),
    "Darwin, Australia": (-12.4634, 130.8456),
    "Hobart, Australia": (-42.8821, 147.3272),
    "Auckland, New Zealand": (-36.8485, 174.7633),
    "Wellington, New Zealand": (-41.2865, 174.7762),
    "Christchurch, New Zealand": (-43.5321, 172.6362),
    "Suva, Fiji": (-18.1248, 178.4501),
    "Port Moresby, Papua New Guinea": (-9.4438, 147.1803),
    "Nuku'alofa, Tonga": (-21.1789, -175.1982),
    "Apia, Samoa": (-13.8506, -171.7513),
}

async def geocode_city(city_name: str) -> tuple[float, float] | None:
    """Geocode a city using OpenStreetMap Nominatim API."""
    try:
        # Use Nominatim API for geocoding
        url = "https://nominatim.openstreetmap.org/search"
        params = {
            "q": city_name,
            "format": "json",
            "limit": 1
        }
        headers = {
            "User-Agent": "weather-app/1.0"
        }

        async with httpx.AsyncClient() as client:
            response = await client.get(url, params=params, headers=headers, timeout=10.0)
            response.raise_for_status()
            results = response.json()

            if results and len(results) > 0:
                lat = float(results[0]["lat"])
                lon = float(results[0]["lon"])
                return (lat, lon)
            return None
    except Exception as e:
        print(f"Geocoding error for '{city_name}': {e}")
        return None

async def get_city_coordinates(city_name: str) -> tuple[tuple[float, float] | None, bool]:
    """Get coordinates for a city by name.

    Checks in order:
    1. Dynamic cache (previously geocoded cities)
    2. Static MAJOR_CITIES list
    3. Geocode using Nominatim API and cache result

    Returns:
        Tuple of (coordinates, was_newly_added)
        coordinates: (lat, lon) or None if not found
        was_newly_added: True if city was just geocoded and added to cache
    """
    # Check dynamic cache first
    if city_name in DYNAMIC_CITIES:
        return (DYNAMIC_CITIES[city_name], False)

    # Check static list
    if city_name in MAJOR_CITIES:
        return (MAJOR_CITIES[city_name], False)

    # Try geocoding
    coords = await geocode_city(city_name)
    if coords:
        # Cache the result
        DYNAMIC_CITIES[city_name] = coords
        print(f"Geocoded and cached: {city_name} -> {coords}")
        return (coords, True)

    return (None, False)

def _get_all_city_names() -> set[str]:
    """Get combined set of all city names (static + dynamic).

    Returns:
        Set of all available city names
    """
    return set(MAJOR_CITIES.keys()) | set(DYNAMIC_CITIES.keys())

def get_all_cities() -> list[str]:
    """Get all available city names (static + dynamic).

    Returns:
        Sorted list of all city names
    """
    return sorted(_get_all_city_names())