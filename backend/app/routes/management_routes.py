from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..models.models import Alert, ParentReport, Ride, Route, RouteAssignment, School, Student, User, Vehicle

router = APIRouter(prefix="/management", tags=["management"])


def _require_manager(x_role: str) -> None:
    if x_role not in ("manager", "admin"):
        raise HTTPException(status_code=403, detail="Only managers can access this endpoint")


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
        "picture_url": student.picture_url,
    }


def _route_to_dict(route: Route, escort_id: int | None = None, student_count: int = 0) -> dict:
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
        "student_count": student_count,
    }


@router.get("/dashboard")
def get_dashboard(
    x_user_id: int = Header(...),
    x_role: str = Header(...),
    db: Session = Depends(get_db),
):
    _require_manager(x_role)
    return {
        "active_rides": db.query(Ride).filter(Ride.status == "active").count(),
        "students": db.query(Student).count(),
        "routes": db.query(Route).count(),
        "vehicles": db.query(Vehicle).count(),
        "alerts": db.query(Alert).filter(Alert.status == "open").count(),
        "reports": db.query(ParentReport).filter(ParentReport.status == "open").count(),
    }


@router.get("/students")
def get_students(
    x_user_id: int = Header(...),
    x_role: str = Header(...),
    db: Session = Depends(get_db),
):
    _require_manager(x_role)
    students = db.query(Student).order_by(Student.id).all()
    return [_student_to_dict(student) for student in students]


@router.get("/routes")
def get_routes(
    x_user_id: int = Header(...),
    x_role: str = Header(...),
    db: Session = Depends(get_db),
):
    _require_manager(x_role)
    routes = db.query(Route).order_by(Route.id).all()
    result = []
    for route in routes:
        assignments = db.query(RouteAssignment).filter(RouteAssignment.route_id == route.id).all()
        escort_id = assignments[0].escort_id if assignments else None
        result.append(_route_to_dict(route, escort_id, len(assignments)))
    return result


@router.get("/reports")
def get_reports(
    x_user_id: int = Header(...),
    x_role: str = Header(...),
    db: Session = Depends(get_db),
):
    _require_manager(x_role)
    reports = db.query(ParentReport).order_by(ParentReport.created_at.desc()).all()
    return reports


@router.get("/alerts")
def get_alerts(
    x_user_id: int = Header(...),
    x_role: str = Header(...),
    db: Session = Depends(get_db),
):
    _require_manager(x_role)
    alerts = db.query(Alert).order_by(Alert.created_at.desc()).all()
    return alerts


@router.get("/schools")
def get_schools(
    x_user_id: int = Header(...),
    x_role: str = Header(...),
    db: Session = Depends(get_db),
):
    _require_manager(x_role)
    return db.query(School).order_by(School.id).all()


@router.get("/users")
def get_users(
    x_user_id: int = Header(...),
    x_role: str = Header(...),
    db: Session = Depends(get_db),
):
    _require_manager(x_role)
    return db.query(User).order_by(User.id).all()
