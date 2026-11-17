from collections import defaultdict
from datetime import date, datetime

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..models.models import (
    Attendance,
    ParentReport,
    Ride,
    RideLocation,
    RideStudent,
    Route,
    RouteAssignment,
    RouteStudent,
    School,
    Student,
)
from ..models.schemas import (
    LocationResponse,
    LocationUpdate,
    OptimizedRouteResponse,
    StopPoint,
)

try:
    from ..services.route_optimizer import optimize_route_with_osrm
except ImportError:
    optimize_route_with_osrm = None


router = APIRouter(prefix="/route", tags=["routes"])

ABSENT_STATUSES = {"absent", "no_show"}
BOARDED_STATUSES = {"picked_up", "boarded", "in_ride"}


def _simple_distance(
    lat1: float,
    lon1: float,
    lat2: float,
    lon2: float,
) -> float:
    return ((lat1 - lat2) ** 2 + (lon1 - lon2) ** 2) ** 0.5


def optimize_pickup_order(
    start_lat: float,
    start_lon: float,
    stops: list[tuple[int, float, float]],
    end_lat: float,
    end_lon: float,
) -> list[int]:
    if not stops:
        return []

    remaining = stops[:]
    ordered_ids: list[int] = []

    current_lat = start_lat
    current_lon = start_lon

    while remaining:
        nearest = min(
            remaining,
            key=lambda stop: _simple_distance(
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


def _absence_report_types_for_direction(direction: str | None) -> list[str]:
    if direction == "morning":
        return ["morning_absence", "date_range_absence"]

    if direction == "afternoon":
        return ["afternoon_absence", "date_range_absence"]

    return ["morning_absence", "afternoon_absence", "date_range_absence"]


def _reported_absent_student_ids(
    db: Session,
    student_ids: list[int],
    direction: str | None,
    target_date: date,
) -> set[int]:
    if not student_ids:
        return set()

    reports = (
        db.query(ParentReport)
        .filter(
            ParentReport.student_id.in_(student_ids),
            ParentReport.report_type.in_(
                _absence_report_types_for_direction(direction),
            ),
            ParentReport.start_date <= target_date,
            ParentReport.status != "cancelled",
        )
        .all()
    )

    return {
        report.student_id
        for report in reports
        if report.end_date is None or report.end_date >= target_date
    }


def _effective_status(
    reported_absent_today: bool,
    attendance_status: str | None,
    ride_student_status: str | None,
) -> str:
    statuses = {
        status
        for status in (attendance_status, ride_student_status)
        if status
    }

    if reported_absent_today:
        return "reported_absent"

    if statuses & ABSENT_STATUSES:
        return "absent"

    if "dropped_off" in statuses:
        return "dropped_off"

    if statuses & BOARDED_STATUSES:
        return "picked_up"

    return "waiting"


def _route_to_dict(route: Route, escort_id: int | None = None) -> dict:
    return {
        "id": route.id,
        "name": route.name,
        "route_name": route.name,
        "direction": route.direction,
        "planned_departure_time": route.planned_departure_time.isoformat()
        if route.planned_departure_time
        else None,
        "driver_id": route.driver_id,
        "escort_id": escort_id,
        "vehicle_number": route.vehicle_number,
        "vehicle_type": route.vehicle_type,
        "status": route.status,
    }


def _student_to_dict(student: Student) -> dict:
    return {
        "id": student.id,
        "first_name": student.first_name,
        "last_name": student.last_name,
        "address": student.address,
        "latitude": student.latitude,
        "longitude": student.longitude,
        "notes": student.notes,
        "mobility_status": student.mobility_status,
        "parent_id": student.parent_id,
        "school_id": student.school_id,
        "picture_url": getattr(student, "picture_url", None),
    }


def _student_coord_key(student: Student) -> tuple[float, float]:
    return (
        round(float(student.latitude or 0), 6),
        round(float(student.longitude or 0), 6),
    )


def _extract_ordered_student_ids_from_osrm_result(osrm_result) -> list[int]:
    if osrm_result is None:
        return []

    ordered_part = osrm_result

    if isinstance(osrm_result, tuple):
        ordered_part = osrm_result[0]

    ordered_ids: list[int] = []

    for item in ordered_part:
        if isinstance(item, int):
            ordered_ids.append(item)
        elif hasattr(item, "id"):
            ordered_ids.append(item.id)

    return ordered_ids


def _extract_geometry_from_osrm_result(osrm_result) -> list[list[float]]:
    if isinstance(osrm_result, tuple) and len(osrm_result) > 1:
        geometry = osrm_result[1]
        return geometry if isinstance(geometry, list) else []

    return []


def _optimize_students_order(
    active_students: list[Student],
    school: School | None,
) -> tuple[list[Student], list[list[float]]]:
    if not active_students:
        return [], []

    student_groups: dict[tuple[float, float], list[Student]] = defaultdict(list)

    for student in active_students:
        student_groups[_student_coord_key(student)].append(student)

    unique_students = [
        group[0]
        for group in student_groups.values()
    ]

    ordered_unique_ids: list[int] = []
    geometry: list[list[float]] = []

    if optimize_route_with_osrm is not None:
        try:
            osrm_result = optimize_route_with_osrm(unique_students)
            ordered_unique_ids = _extract_ordered_student_ids_from_osrm_result(
                osrm_result,
            )
            geometry = _extract_geometry_from_osrm_result(osrm_result)
        except Exception:
            ordered_unique_ids = []
            geometry = []

    if not ordered_unique_ids:
        stops = [
            (student.id, student.latitude or 0, student.longitude or 0)
            for student in unique_students
        ]

        ordered_unique_ids = optimize_pickup_order(
            start_lat=(school.latitude if school else 0) or 0,
            start_lon=(school.longitude if school else 0) or 0,
            stops=stops,
            end_lat=(school.latitude if school else 0) or 0,
            end_lon=(school.longitude if school else 0) or 0,
        )

    unique_by_id = {
        student.id: student
        for student in unique_students
    }

    final_students: list[Student] = []

    for unique_student_id in ordered_unique_ids:
        unique_student = unique_by_id.get(unique_student_id)

        if unique_student is None:
            continue

        coord_key = _student_coord_key(unique_student)

        for original_student in student_groups[coord_key]:
            final_students.append(original_student)

    existing_ids = {
        student.id
        for student in final_students
    }

    for student in active_students:
        if student.id not in existing_ids:
            final_students.append(student)

    return final_students, geometry


@router.get("")
@router.get("/")
def get_routes(db: Session = Depends(get_db)):
    routes = db.query(Route).order_by(Route.id).all()

    result = []

    for route in routes:
        assignment = (
            db.query(RouteAssignment)
            .filter(RouteAssignment.route_id == route.id)
            .first()
        )

        result.append(
            _route_to_dict(
                route,
                assignment.escort_id if assignment else None,
            )
        )

    return result


@router.get("/driver/{driver_id}")
def get_routes_for_driver(driver_id: int, db: Session = Depends(get_db)):
    routes = (
        db.query(Route)
        .filter(Route.driver_id == driver_id)
        .order_by(Route.id)
        .all()
    )

    result = []

    for route in routes:
        assignment = (
            db.query(RouteAssignment)
            .filter(RouteAssignment.route_id == route.id)
            .first()
        )

        result.append(
            _route_to_dict(
                route,
                assignment.escort_id if assignment else None,
            )
        )

    return result


@router.get("/escort/{escort_id}")
def get_routes_for_escort(escort_id: int, db: Session = Depends(get_db)):
    route_ids = [
        row.route_id
        for row in db.query(RouteAssignment.route_id)
        .filter(RouteAssignment.escort_id == escort_id)
        .distinct()
        .all()
    ]

    if not route_ids:
        return []

    routes = (
        db.query(Route)
        .filter(Route.id.in_(route_ids))
        .order_by(Route.id)
        .all()
    )

    return [
        _route_to_dict(route, escort_id)
        for route in routes
    ]


@router.get("/{route_id}/active-ride")
def get_active_ride(route_id: int, db: Session = Depends(get_db)):
    ride = (
        db.query(Ride)
        .filter(
            Ride.route_id == route_id,
            Ride.status == "active",
        )
        .first()
    )

    if not ride:
        return None

    return ride


@router.get("/{route_id}/students")
def get_route_students(route_id: int, db: Session = Depends(get_db)):
    route = db.query(Route).filter(Route.id == route_id).first()

    if not route:
        raise HTTPException(status_code=404, detail="Route not found")

    ride = (
        db.query(Ride)
        .filter(
            Ride.route_id == route_id,
            Ride.status == "active",
        )
        .first()
    )

    target_date = ride.ride_date if ride else date.today()

    assignment_rows = (
        db.query(RouteAssignment, Student)
        .join(Student, Student.id == RouteAssignment.student_id)
        .filter(RouteAssignment.route_id == route_id)
        .order_by(
            RouteAssignment.default_pickup_order.asc().nullslast(),
            Student.id,
        )
        .all()
    )

    result = []

    student_ids = [
        student.id
        for _, student in assignment_rows
    ]

    reported_absent_ids = _reported_absent_student_ids(
        db=db,
        student_ids=student_ids,
        direction=route.direction,
        target_date=target_date,
    )

    for assignment, student in assignment_rows:
        attendance_status = None
        ride_student_status = None
        ride_student_pickup_order = None
        eta_minutes = None

        if ride:
            attendance = (
                db.query(Attendance)
                .filter(
                    Attendance.ride_id == ride.id,
                    Attendance.student_id == student.id,
                )
                .first()
            )

            attendance_status = attendance.status if attendance else None

            ride_student = (
                db.query(RideStudent)
                .filter(
                    RideStudent.ride_id == ride.id,
                    RideStudent.student_id == student.id,
                )
                .first()
            )

            ride_student_status = ride_student.status if ride_student else None
            ride_student_pickup_order = (
                ride_student.pickup_order if ride_student else None
            )
            eta_minutes = ride_student.eta_minutes if ride_student else None

        reported_absent_today = student.id in reported_absent_ids

        result.append(
            {
                "id": assignment.id,
                "route_id": assignment.route_id,
                "student_id": assignment.student_id,
                "escort_id": assignment.escort_id,
                "default_pickup_order": assignment.default_pickup_order,
                "pickup_order": ride_student_pickup_order
                or assignment.default_pickup_order,
                "attendance_status": attendance_status,
                "ride_student_status": ride_student_status,
                "reported_absent_today": reported_absent_today,
                "effective_status": _effective_status(
                    reported_absent_today,
                    attendance_status,
                    ride_student_status,
                ),
                "route_direction": route.direction,
                "active_ride_id": ride.id if ride else None,
                "eta_minutes": eta_minutes,
                "student": _student_to_dict(student),
            }
        )

    if result:
        return result

    route_student_rows = (
        db.query(RouteStudent, Student)
        .join(Student, Student.id == RouteStudent.student_id)
        .filter(RouteStudent.route_id == route_id)
        .order_by(
            RouteStudent.pickup_order.asc().nullslast(),
            Student.id,
        )
        .all()
    )

    student_ids = [
        student.id
        for _, student in route_student_rows
    ]

    reported_absent_ids = _reported_absent_student_ids(
        db=db,
        student_ids=student_ids,
        direction=route.direction,
        target_date=target_date,
    )

    for index, (route_student, student) in enumerate(
        route_student_rows,
        start=1,
    ):
        attendance_status = None
        ride_student_status = None
        ride_student_pickup_order = None
        eta_minutes = None

        if ride:
            attendance = (
                db.query(Attendance)
                .filter(
                    Attendance.ride_id == ride.id,
                    Attendance.student_id == student.id,
                )
                .first()
            )

            attendance_status = attendance.status if attendance else None

            ride_student = (
                db.query(RideStudent)
                .filter(
                    RideStudent.ride_id == ride.id,
                    RideStudent.student_id == student.id,
                )
                .first()
            )

            ride_student_status = ride_student.status if ride_student else None
            ride_student_pickup_order = (
                ride_student.pickup_order if ride_student else None
            )
            eta_minutes = ride_student.eta_minutes if ride_student else None

        reported_absent_today = student.id in reported_absent_ids

        result.append(
            {
                "id": index,
                "route_id": route_student.route_id,
                "student_id": route_student.student_id,
                "escort_id": None,
                "default_pickup_order": route_student.pickup_order,
                "pickup_order": ride_student_pickup_order
                or route_student.pickup_order,
                "attendance_status": attendance_status,
                "ride_student_status": ride_student_status,
                "reported_absent_today": reported_absent_today,
                "effective_status": _effective_status(
                    reported_absent_today,
                    attendance_status,
                    ride_student_status,
                ),
                "route_direction": route.direction,
                "active_ride_id": ride.id if ride else None,
                "eta_minutes": eta_minutes,
                "student": _student_to_dict(student),
            }
        )

    return result


@router.get("/{route_id}/optimize", response_model=OptimizedRouteResponse)
def get_optimized_route(route_id: int, db: Session = Depends(get_db)):
    route = db.query(Route).filter(Route.id == route_id).first()

    if not route:
        raise HTTPException(status_code=404, detail="Route not found")

    assignments = (
        db.query(RouteAssignment)
        .filter(RouteAssignment.route_id == route_id)
        .all()
    )

    student_ids = [
        assignment.student_id
        for assignment in assignments
    ]

    if not student_ids:
        route_students = (
            db.query(RouteStudent)
            .filter(RouteStudent.route_id == route_id)
            .all()
        )

        student_ids = [
            route_student.student_id
            for route_student in route_students
        ]

    students = (
        db.query(Student)
        .filter(Student.id.in_(student_ids))
        .all()
    )

    school = None

    if students:
        school = (
            db.query(School)
            .filter(School.id == students[0].school_id)
            .first()
        )

    target_date = date.today()

    active_ride = (
        db.query(Ride)
        .filter(
            Ride.route_id == route_id,
            Ride.status == "active",
        )
        .first()
    )

    if active_ride:
        target_date = active_ride.ride_date

    absent_ids = _reported_absent_student_ids(
        db=db,
        student_ids=student_ids,
        direction=route.direction,
        target_date=target_date,
    )

    active_students = [
        student
        for student in students
        if student.id not in absent_ids
    ]

    ordered_students, geometry = _optimize_students_order(
        active_students=active_students,
        school=school,
    )

    result_stops = []

    for index, student in enumerate(ordered_students, start=1):
        result_stops.append(
            StopPoint(
                student_id=student.id,
                student_name=f"{student.first_name} {student.last_name}",
                address=student.address,
                latitude=student.latitude or 0,
                longitude=student.longitude or 0,
                pickup_order=index,
            )
        )

    return OptimizedRouteResponse(
        route_id=route.id,
        route_name=route.name,
        stops=result_stops,
        geometry=geometry,
    )


@router.post("/{route_id}/location", response_model=LocationResponse)
def update_location(
    route_id: int,
    loc: LocationUpdate,
    x_user_id: int = Header(...),
    db: Session = Depends(get_db),
):
    ride = (
        db.query(Ride)
        .filter(
            Ride.route_id == route_id,
            Ride.status == "active",
        )
        .first()
    )

    if not ride:
        raise HTTPException(
            status_code=404,
            detail="No active ride for this route",
        )

    location = RideLocation(
        ride_id=ride.id,
        latitude=loc.latitude,
        longitude=loc.longitude,
        recorded_at=datetime.utcnow(),
    )

    ride.current_latitude = loc.latitude
    ride.current_longitude = loc.longitude
    ride.last_location_update = location.recorded_at

    db.add(location)
    db.commit()
    db.refresh(location)

    return location


@router.get("/{route_id}/location", response_model=LocationResponse)
def get_latest_location(route_id: int, db: Session = Depends(get_db)):
    ride = (
        db.query(Ride)
        .filter(
            Ride.route_id == route_id,
            Ride.status == "active",
        )
        .first()
    )

    if not ride:
        raise HTTPException(
            status_code=404,
            detail="No active ride for this route",
        )

    location = (
        db.query(RideLocation)
        .filter(RideLocation.ride_id == ride.id)
        .order_by(RideLocation.recorded_at.desc())
        .first()
    )

    if not location:
        raise HTTPException(
            status_code=404,
            detail="No location data yet",
        )

    return location