from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy import func
from sqlalchemy.orm import Session
from ..database import get_db
from ..models.models import Attendance, Ride, RideStudent, RouteAssignment
from ..models.schemas import AttendanceUpdate, AttendanceResponse

router = APIRouter(prefix="/attendance", tags=["attendance"])


STATUS_ALIASES = {
    "pending": "waiting",
    "boarded": "picked_up",
    "in_ride": "picked_up",
    "no_show": "absent",
}

ALLOWED_STATUSES = {"waiting", "picked_up", "dropped_off", "absent"}


def _normalized_status(status: str) -> str:
    normalized = STATUS_ALIASES.get(status.strip().lower(), status.strip().lower())
    if normalized not in ALLOWED_STATUSES:
        raise HTTPException(status_code=400, detail=f"Unsupported attendance status: {status}")
    return normalized


def _ensure_ride_student(
    db: Session,
    ride: Ride,
    student_id: int,
    user_id: int,
) -> RideStudent:
    ride_student = (
        db.query(RideStudent)
        .filter(
            RideStudent.ride_id == ride.id,
            RideStudent.student_id == student_id,
        )
        .first()
    )

    if ride_student:
        return ride_student

    assignment = (
        db.query(RouteAssignment)
        .filter(
            RouteAssignment.route_id == ride.route_id,
            RouteAssignment.student_id == student_id,
        )
        .first()
    )
    next_id = (db.query(func.max(RideStudent.id)).scalar() or 0) + 1
    ride_student = RideStudent(
        id=next_id,
        ride_id=ride.id,
        student_id=student_id,
        escort_id=assignment.escort_id if assignment else user_id,
        is_going=True,
        pickup_order=assignment.default_pickup_order if assignment else None,
        status="waiting",
    )
    db.add(ride_student)
    return ride_student


def _apply_ride_student_status(ride_student: RideStudent, status: str) -> None:
    now = datetime.utcnow()
    ride_student.status = status

    if status == "picked_up":
        ride_student.is_going = True
        ride_student.boarded_time = ride_student.boarded_time or now
    elif status == "dropped_off":
        ride_student.is_going = True
        ride_student.boarded_time = ride_student.boarded_time or now
        ride_student.dropped_off_time = ride_student.dropped_off_time or now
    elif status == "absent":
        ride_student.is_going = False
        ride_student.boarded_time = None
        ride_student.dropped_off_time = None
    elif status == "waiting":
        ride_student.is_going = True
        ride_student.boarded_time = None
        ride_student.dropped_off_time = None


@router.post("/status", response_model=AttendanceResponse)
def update_attendance(
    req: AttendanceUpdate,
    x_user_id: int = Header(...),
    x_role: str = Header(...),
    db: Session = Depends(get_db),
):
    """Record a student check-in status (boarded/dropped_off/absent)."""
    if x_role not in ("escort", "manager"):
        raise HTTPException(status_code=403, detail="Only escorts or managers can update attendance")

    status = _normalized_status(req.status)
    ride = db.query(Ride).filter(Ride.id == req.ride_id).first()
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")

    att = db.query(Attendance).filter(
        Attendance.ride_id == req.ride_id,
        Attendance.student_id == req.student_id,
    ).first()

    if not att:
        att = Attendance(
            ride_id=req.ride_id,
            student_id=req.student_id,
            status=status,
            updated_by=x_user_id,
            updated_at=datetime.utcnow(),
        )
        db.add(att)
    else:
        att.status = status
        att.updated_by = x_user_id
        att.updated_at = datetime.utcnow()

    ride_student = _ensure_ride_student(db, ride, req.student_id, x_user_id)
    _apply_ride_student_status(ride_student, status)

    db.commit()
    db.refresh(att)
    return att


@router.get("/ride/{ride_id}", response_model=list[AttendanceResponse])
def get_ride_attendance(ride_id: int, db: Session = Depends(get_db)):
    """Get all attendance records for a ride."""
    return db.query(Attendance).filter(Attendance.ride_id == ride_id).all()
