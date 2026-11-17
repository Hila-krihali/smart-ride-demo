from typing import List, Tuple
import requests
from app.models.models import Student

def optimize_route_with_osrm(active_students: List[Student]) -> Tuple[List[Student], list[list[float]]]:
    """
    Fetches the optimized pickup order from OSRM and the real road geometry
    using a SINGLE API call for maximum performance.
    """
    if len(active_students) < 2:
        return active_students, []

    coords = [f"{student.longitude},{student.latitude}" for student in active_students]
    coords_str = ";".join(coords)

    # הוספנו פה בקשה גם לגיאומטריה (הכבישים) וגם לסקירה מלאה
    trip_url = (
        "http://router.project-osrm.org/trip/v1/driving/"
        f"{coords_str}?roundtrip=false&source=first&geometries=geojson&overview=full"
    )

    try:
        trip_response = requests.get(trip_url, timeout=15)
        trip_response.raise_for_status()
        trip_data = trip_response.json()

        waypoints = trip_data.get("waypoints", []) or []
        trips = trip_data.get("trips", []) or []

        if not waypoints or not trips:
            return active_students, []

        # 1. סידור התלמידים לפי המסלול האופטימלי
        ordered_students = [None] * len(active_students)
        for waypoint_index, waypoint in enumerate(waypoints):
            optimized_index = waypoint.get("waypoint_index")
            if optimized_index is not None and optimized_index < len(ordered_students):
                ordered_students[optimized_index] = active_students[waypoint_index]

        final_route = [student for student in ordered_students if student is not None]
        if len(final_route) != len(active_students):
            return active_students, []

        # 2. חילוץ הנקודות של הכבישים (Geometry) ישירות מהתשובה
        geometry = []
        trip_geometry = trips[0].get("geometry", {})
        if isinstance(trip_geometry, dict):
            coordinates = trip_geometry.get("coordinates", []) or []
            # המרה של הקואורדינטות למערך [lon, lat]
            geometry = [[float(lon), float(lat)] for lon, lat in coordinates]

        return final_route, geometry

    except requests.exceptions.RequestException as exc:
        print(f"OSRM Error: {exc}")
        return active_students, []
    
    import math


def _distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    return math.sqrt((lat1 - lat2) ** 2 + (lon1 - lon2) ** 2)


def optimize_pickup_order(
    start_lat: float,
    start_lon: float,
    stops: list[tuple[int, float, float]],
    end_lat: float,
    end_lon: float,
) -> list[int]:
    """
    Simple fallback route optimizer.

    Receives:
    - start point
    - list of stops: (student_id, latitude, longitude)
    - end point

    Returns:
    - ordered list of student IDs

    This is used only as a safe fallback when OSRM is not available.
    """
    if not stops:
        return []

    remaining = stops[:]
    ordered_ids: list[int] = []

    current_lat = start_lat
    current_lon = start_lon

    while remaining:
        nearest = min(
            remaining,
            key=lambda stop: _distance(
                current_lat,
                current_lon,
                stop[1],
                stop[2],
            ),
        )

        ordered_ids.append(nearest[0])
        current_lat = nearest[1]
        current_lon = nearest[2]

        remaining.remove(nearest)

    return ordered_ids