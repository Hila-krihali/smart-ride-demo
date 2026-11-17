import logging
import os
from io import BytesIO
from datetime import date, datetime

import cloudinary
import cloudinary.uploader
from fastapi import APIRouter, Depends, File, Header, HTTPException, UploadFile
from pydantic import BaseModel
from sqlalchemy import or_, func
from sqlalchemy.orm import Session

from ..database import get_db
from ..models.models import (
    Attendance,
    ParentReport,
    ParentStudent,
    Ride,
    RideStudent,
    Route,
    RouteAssignment,
    Student,
    User,
)
from ..models.schemas import ParentReportCreate, ParentReportResponse, StudentResponse

router = APIRouter(prefix="/parent", tags=["parent"])
logger = logging.getLogger(__name__)

ABSENT_STATUSES = {"absent", "no_show"}
BOARDED_STATUSES = {"picked_up", "boarded", "in_ride"}
MAX_STUDENT_IMAGE_BYTES = 5 * 1024 * 1024
ALLOWED_STUDENT_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}


class CancelAbsenceRequest(BaseModel):
    student_id: int
    ride_id: int | None = None


def _configure_cloudinary() -> tuple[str, bool]:
    cloud_name = os.getenv("CLOUDINARY_CLOUD_NAME")
    upload_preset = os.getenv("CLOUDINARY_UPLOAD_PRESET")
    api_key = os.getenv("CLOUDINARY_API_KEY")
    api_secret = os.getenv("CLOUDINARY_API_SECRET")

    if not cloud_name or not upload_preset:
        raise HTTPException(
            status_code=500,
            detail="Cloudinary configuration is missing",
        )

    cloudinary.config(
        cloud_name=cloud_name,
        api_key=api_key,
        api_secret=api_secret,
        secure=True,
    )

    return upload_preset, bool(api_key and api_secret)


def _normalized_role(role: str) -> str:
    return role.strip().lower()


def _student_parent_link_source(
    db: Session,
    parent_id: int,
    student_id: int,
) -> str | None:
    belongs_by_parent_id = (
        db.query(Student.id)
        .filter(
            Student.id == student_id,
            Student.parent_id == parent_id,
        )
        .first()
    )

    if belongs_by_parent_id:
        return "students.parent_id"

    belongs_by_link = (
        db.query(ParentStudent)
        .filter(
            ParentStudent.parent_id == parent_id,
            ParentStudent.student_id == student_id,
        )
        .first()
    )

    if belongs_by_link:
        return "parent_student"

    return None


def student_belongs_to_parent(
    db: Session,
    parent_id: int,
    student_id: int,
) -> bool:
    return _student_parent_link_source(db, parent_id, student_id) is not None


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


async def _upload_student_picture_to_cloudinary(
    file: UploadFile,
    student_id: int,
) -> str:
    if file.content_type not in ALLOWED_STUDENT_IMAGE_TYPES:
        raise HTTPException(
            status_code=400,
            detail="Only JPG, PNG, and WebP images are supported",
        )

    image_bytes = await file.read()

    if not image_bytes:
        raise HTTPException(status_code=400, detail="Image file is empty")

    if len(image_bytes) > MAX_STUDENT_IMAGE_BYTES:
        raise HTTPException(
            status_code=400,
            detail="Image file must be smaller than 5MB",
        )

    upload_preset, has_signed_credentials = _configure_cloudinary()
    image_file = BytesIO(image_bytes)
    image_file.name = file.filename or f"student_{student_id}.jpg"

    try:
        if has_signed_credentials:
            upload_result = cloudinary.uploader.upload(
                image_file,
                upload_preset=upload_preset,
                folder="smart-ride/students",
                public_id=f"student_{student_id}",
                overwrite=True,
                resource_type="image",
            )
        else:
            upload_result = cloudinary.uploader.unsigned_upload(
                image_file,
                upload_preset,
                resource_type="image",
            )
    except Exception as error:
        logger.exception("Cloudinary student image upload failed")
        raise HTTPException(
            status_code=502,
            detail="Image upload failed",
        ) from error

    secure_url = upload_result.get("secure_url")

    if not secure_url:
        raise HTTPException(
            status_code=502,
            detail="Cloudinary did not return an image URL",
        )

    return secure_url


def _absence_report_types_for_direction(direction: str | None) -> list[str]:
    if direction == "morning":
        return ["morning_absence", "date_range_absence"]

    if direction == "afternoon":
        return ["afternoon_absence", "date_range_absence"]

    return ["morning_absence", "afternoon_absence", "date_range_absence"]


def _directions_for_report_type(report_type: str) -> list[str]:
    if report_type == "morning_absence":
        return ["morning"]

    if report_type == "afternoon_absence":
        return ["afternoon"]

    if report_type == "date_range_absence":
        return ["morning", "afternoon"]

    return []


def _ride_departure_datetime(ride: Ride, route: Route) -> datetime | None:
    if ride.ride_date is None or route.planned_departure_time is None:
        return None

    return datetime.combine(ride.ride_date, route.planned_departure_time)


def _active_ride_rows_for_student(
    db: Session,
    student_id: int,
    directions: list[str] | None = None,
    ride_id: int | None = None,
) -> list[tuple[Ride, Route, RouteAssignment]]:
    query = (
        db.query(Ride, Route, RouteAssignment)
        .join(Route, Route.id == Ride.route_id)
        .join(RouteAssignment, RouteAssignment.route_id == Ride.route_id)
        .filter(
            RouteAssignment.student_id == student_id,
            Ride.status == "active",
        )
    )

    if ride_id is not None:
        query = query.filter(Ride.id == ride_id)

    if directions:
        query = query.filter(Route.direction.in_(directions))

    return query.order_by(Ride.ride_date.asc(), Ride.id.asc()).all()


def _has_reported_absence_for_date(
    db: Session,
    student_id: int,
    direction: str | None,
    target_date: date,
) -> bool:
    reports = (
        db.query(ParentReport)
        .filter(
            ParentReport.student_id == student_id,
            ParentReport.report_type.in_(
                _absence_report_types_for_direction(direction),
            ),
            ParentReport.start_date <= target_date,
            ParentReport.status != "cancelled",
        )
        .all()
    )

    return any(
        report.end_date is None or report.end_date >= target_date
        for report in reports
    )


def _effective_status(
    reported_absent_today: bool,
    attendance_status: str | None,
    ride_student_status: str | None,
) -> str:
    statuses = {
        status.strip().lower()
        for status in (attendance_status, ride_student_status)
        if status
    }

    if reported_absent_today:
        return "reported_absent"

    if "dropped_off" in statuses:
        return "dropped_off"

    if statuses & BOARDED_STATUSES:
        return "picked_up"

    if statuses & ABSENT_STATUSES:
        return "absent"

    return "waiting"


def _status_priority(status: str | None) -> int:
    if status == "reported_absent":
        return 50
    if status == "dropped_off":
        return 40
    if status == "picked_up":
        return 30
    if status == "absent":
        return 20
    if status == "waiting":
        return 10
    return 0


def _child_status_fields(db: Session, student_id: int) -> dict:
    """
    מחזיר להורה סטטוס עדכני של הילד מכל הנסיעות הפעילות.

    למה לא בוחרים רק Ride אחד?
    כי לילד יכולים להיות גם מסלול בוקר וגם מסלול חזור פעילים.
    אם המלווה עדכן בבוקר שהילד עלה להסעה, אסור שהמסך של ההורה
    יציג בטעות את נסיעת החזור שעדיין waiting.
    """

    active_rows = _active_ride_rows_for_student(
        db=db,
        student_id=student_id,
    )

    if not active_rows:
        reported_absent_today = _has_reported_absence_for_date(
            db=db,
            student_id=student_id,
            direction=None,
            target_date=date.today(),
        )

        return {
            "attendance_status": None,
            "ride_student_status": None,
            "reported_absent_today": reported_absent_today,
            "effective_status": _effective_status(
                reported_absent_today,
                None,
                None,
            ),
            "route_direction": None,
            "active_ride_id": None,
            "eta_minutes": None,
        }

    best_status_data: dict | None = None
    best_priority = -1

    for ride, route, _assignment in active_rows:
        ride_student = (
            db.query(RideStudent)
            .filter(
                RideStudent.ride_id == ride.id,
                RideStudent.student_id == student_id,
            )
            .first()
        )

        attendance = (
            db.query(Attendance)
            .filter(
                Attendance.ride_id == ride.id,
                Attendance.student_id == student_id,
            )
            .first()
        )

        attendance_status = attendance.status if attendance else None
        ride_student_status = ride_student.status if ride_student else None

        reported_absent_today = _has_reported_absence_for_date(
            db=db,
            student_id=student_id,
            direction=route.direction,
            target_date=ride.ride_date,
        )

        effective_status = _effective_status(
            reported_absent_today,
            attendance_status,
            ride_student_status,
        )

        status_data = {
            "attendance_status": attendance_status,
            "ride_student_status": ride_student_status,
            "reported_absent_today": reported_absent_today,
            "effective_status": effective_status,
            "route_direction": route.direction,
            "active_ride_id": ride.id,
            "eta_minutes": ride_student.eta_minutes if ride_student else None,
        }

        priority = _status_priority(effective_status)

        if priority > best_priority:
            best_priority = priority
            best_status_data = status_data

    return best_status_data or {
        "attendance_status": None,
        "ride_student_status": None,
        "reported_absent_today": False,
        "effective_status": "waiting",
        "route_direction": None,
        "active_ride_id": None,
        "eta_minutes": None,
    }


def _apply_parent_absence_to_rides(
    db: Session,
    parent_id: int,
    student_id: int,
    report_type: str,
    start_date: date,
    end_date: date | None,
) -> None:
    directions = _directions_for_report_type(report_type)

    if not directions:
        return

    effective_end_date = end_date or start_date

    rides_with_assignment = (
        db.query(Ride, RouteAssignment)
        .join(Route, Route.id == Ride.route_id)
        .join(RouteAssignment, RouteAssignment.route_id == Ride.route_id)
        .filter(
            RouteAssignment.student_id == student_id,
            Ride.status == "active",
            Ride.ride_date >= start_date,
            Ride.ride_date <= effective_end_date,
            Route.direction.in_(directions),
        )
        .all()
    )

    for ride, assignment in rides_with_assignment:
        attendance = (
            db.query(Attendance)
            .filter(
                Attendance.ride_id == ride.id,
                Attendance.student_id == student_id,
            )
            .first()
        )

        if attendance is None:
            attendance = Attendance(
                ride_id=ride.id,
                student_id=student_id,
                status="absent",
                updated_by=parent_id,
                updated_at=datetime.utcnow(),
            )
            db.add(attendance)
        else:
            attendance.status = "absent"
            attendance.updated_by = parent_id
            attendance.updated_at = datetime.utcnow()

        ride_student = (
            db.query(RideStudent)
            .filter(
                RideStudent.ride_id == ride.id,
                RideStudent.student_id == student_id,
            )
            .first()
        )

        if ride_student is None:
            next_ride_student_id = (
                db.query(func.max(RideStudent.id)).scalar() or 0
            ) + 1

            ride_student = RideStudent(
                id=next_ride_student_id,
                ride_id=ride.id,
                student_id=student_id,
                escort_id=assignment.escort_id,
                is_going=False,
                pickup_order=assignment.default_pickup_order,
                eta_minutes=None,
                status="absent",
                boarded_time=None,
                dropped_off_time=None,
            )
            db.add(ride_student)
        else:
            ride_student.is_going = False
            ride_student.status = "absent"
            ride_student.boarded_time = None
            ride_student.dropped_off_time = None


def _cancel_parent_absence_for_rides(
    db: Session,
    parent_id: int,
    student_id: int,
    ride_id: int | None,
) -> dict:
    now = datetime.now()

    ride_rows = _active_ride_rows_for_student(
        db=db,
        student_id=student_id,
        ride_id=ride_id,
    )

    if not ride_rows:
        raise HTTPException(
            status_code=404,
            detail="לא נמצאה הסעה פעילה עבור הילד",
        )

    rides_before_departure: list[tuple[Ride, Route, RouteAssignment]] = []

    for ride, route, assignment in ride_rows:
        departure_datetime = _ride_departure_datetime(ride, route)

        if departure_datetime is None:
            continue

        if now < departure_datetime:
            rides_before_departure.append((ride, route, assignment))

    if not rides_before_departure:
        raise HTTPException(
            status_code=400,
            detail="אי אפשר לעדכן שהילד יגיע, כי שעת יציאת ההסעה כבר עברה",
        )

    ride_dates = [
        ride.ride_date
        for ride, _, _ in rides_before_departure
    ]

    reports = (
        db.query(ParentReport)
        .filter(
            ParentReport.parent_id == parent_id,
            ParentReport.student_id == student_id,
            ParentReport.report_type.in_(
                ["morning_absence", "afternoon_absence", "date_range_absence"],
            ),
            ParentReport.status != "cancelled",
        )
        .all()
    )

    cancelled_reports_count = 0

    for report in reports:
        report_end_date = report.end_date or report.start_date

        for ride_date in ride_dates:
            if report.start_date <= ride_date <= report_end_date:
                report.status = "cancelled"
                cancelled_reports_count += 1
                break

    if cancelled_reports_count == 0:
        for report in reports:
            report.status = "cancelled"
            cancelled_reports_count += 1

    updated_ride_ids: list[int] = []

    for ride, route, assignment in rides_before_departure:
        attendance = (
            db.query(Attendance)
            .filter(
                Attendance.ride_id == ride.id,
                Attendance.student_id == student_id,
            )
            .first()
        )

        if attendance is None:
            attendance = Attendance(
                ride_id=ride.id,
                student_id=student_id,
                status="waiting",
                updated_by=parent_id,
                updated_at=datetime.utcnow(),
            )
            db.add(attendance)
        else:
            attendance.status = "waiting"
            attendance.updated_by = parent_id
            attendance.updated_at = datetime.utcnow()

        ride_student = (
            db.query(RideStudent)
            .filter(
                RideStudent.ride_id == ride.id,
                RideStudent.student_id == student_id,
            )
            .first()
        )

        if ride_student is None:
            next_ride_student_id = (
                db.query(func.max(RideStudent.id)).scalar() or 0
            ) + 1

            ride_student = RideStudent(
                id=next_ride_student_id,
                ride_id=ride.id,
                student_id=student_id,
                escort_id=assignment.escort_id,
                is_going=True,
                pickup_order=assignment.default_pickup_order,
                eta_minutes=None,
                status="waiting",
                boarded_time=None,
                dropped_off_time=None,
            )
            db.add(ride_student)
        else:
            ride_student.is_going = True
            ride_student.status = "waiting"
            ride_student.boarded_time = None
            ride_student.dropped_off_time = None

        updated_ride_ids.append(ride.id)

    return {
        "message": "הדיווח בוטל והילד סומן כממתין להסעה",
        "student_id": student_id,
        "updated_ride_ids": updated_ride_ids,
        "cancelled_reports_count": cancelled_reports_count,
    }


@router.get("/children", response_model=list[StudentResponse])
def get_my_children(
    x_user_id: int = Header(...),
    x_role: str = Header(...),
    db: Session = Depends(get_db),
):
    if _normalized_role(x_role) != "parent":
        raise HTTPException(
            status_code=403,
            detail="Only parents can access this endpoint",
        )

    linked_student_ids = [
        row.student_id
        for row in db.query(ParentStudent.student_id)
        .filter(ParentStudent.parent_id == x_user_id)
        .all()
    ]

    query = db.query(Student)

    if linked_student_ids:
        query = query.filter(
            or_(
                Student.parent_id == x_user_id,
                Student.id.in_(linked_student_ids),
            )
        )
    else:
        query = query.filter(Student.parent_id == x_user_id)

    children = query.order_by(Student.id).all()

    return [
        {
            **_student_to_dict(student),
            **_child_status_fields(db, student.id),
        }
        for student in children
    ]


@router.post("/children/{student_id}/picture", response_model=StudentResponse)
async def upload_child_picture(
    student_id: int,
    file: UploadFile = File(...),
    x_user_id: int = Header(...),
    x_role: str = Header(...),
    db: Session = Depends(get_db),
):
    if _normalized_role(x_role) != "parent":
        raise HTTPException(
            status_code=403,
            detail="Only parents can upload child pictures",
        )

    link_source = _student_parent_link_source(
        db,
        x_user_id,
        student_id,
    )

    if not link_source:
        raise HTTPException(
            status_code=403,
            detail=f"Student {student_id} does not belong to parent {x_user_id}",
        )

    student = db.query(Student).filter(Student.id == student_id).first()

    if student is None:
        raise HTTPException(status_code=404, detail="Student not found")

    picture_url = await _upload_student_picture_to_cloudinary(
        file=file,
        student_id=student_id,
    )

    student.picture_url = picture_url
    db.commit()
    db.refresh(student)

    return {
        **_student_to_dict(student),
        **_child_status_fields(db, student.id),
    }


@router.post("/report", response_model=ParentReportResponse)
def create_absence_report(
    req: ParentReportCreate,
    x_user_id: int = Header(...),
    x_role: str = Header(...),
    db: Session = Depends(get_db),
):
    normalized_role = _normalized_role(x_role)

    if normalized_role != "parent":
        raise HTTPException(
            status_code=403,
            detail="Only parents can submit reports",
        )

    link_source = _student_parent_link_source(
        db,
        x_user_id,
        req.student_id,
    )

    if not link_source:
        raise HTTPException(
            status_code=403,
            detail=f"Student {req.student_id} does not belong to parent {x_user_id}",
        )

    directions = _directions_for_report_type(req.report_type)

    report_start_date = req.start_date
    report_end_date = req.end_date

    active_ride_rows = _active_ride_rows_for_student(
        db=db,
        student_id=req.student_id,
        directions=directions,
    )

    if active_ride_rows:
        first_ride, _, _ = active_ride_rows[0]
        report_start_date = first_ride.ride_date

        if req.report_type != "date_range_absence":
            report_end_date = None

    report = ParentReport(
        parent_id=x_user_id,
        student_id=req.student_id,
        report_type=req.report_type,
        start_date=report_start_date,
        end_date=report_end_date,
        message=req.message,
        status="open",
        created_at=datetime.utcnow(),
    )

    db.add(report)

    _apply_parent_absence_to_rides(
        db=db,
        parent_id=x_user_id,
        student_id=req.student_id,
        report_type=req.report_type,
        start_date=report_start_date,
        end_date=report_end_date,
    )

    db.commit()
    db.refresh(report)

    return report


@router.post("/report/cancel")
def cancel_absence_report(
    req: CancelAbsenceRequest,
    x_user_id: int = Header(...),
    x_role: str = Header(...),
    db: Session = Depends(get_db),
):
    normalized_role = _normalized_role(x_role)

    if normalized_role != "parent":
        raise HTTPException(
            status_code=403,
            detail="Only parents can cancel absence reports",
        )

    link_source = _student_parent_link_source(
        db,
        x_user_id,
        req.student_id,
    )

    if not link_source:
        raise HTTPException(
            status_code=403,
            detail=f"Student {req.student_id} does not belong to parent {x_user_id}",
        )

    result = _cancel_parent_absence_for_rides(
        db=db,
        parent_id=x_user_id,
        student_id=req.student_id,
        ride_id=req.ride_id,
    )

    db.commit()

    return result


@router.get("/escorts")
def get_my_children_escorts(
    x_user_id: int = Header(...),
    x_role: str = Header(...),
    db: Session = Depends(get_db),
):
    if _normalized_role(x_role) != "parent":
        raise HTTPException(
            status_code=403,
            detail="Only parents can access escort contacts",
        )

    linked_student_ids = [
        row.student_id
        for row in db.query(ParentStudent.student_id)
        .filter(ParentStudent.parent_id == x_user_id)
        .all()
    ]

    children_query = db.query(Student)

    if linked_student_ids:
        children_query = children_query.filter(
            or_(
                Student.parent_id == x_user_id,
                Student.id.in_(linked_student_ids),
            )
        )
    else:
        children_query = children_query.filter(Student.parent_id == x_user_id)

    children = children_query.order_by(Student.id).all()
    child_ids = [child.id for child in children]

    if not child_ids:
        return []

    rows = (
        db.query(User, Student, Route)
        .join(RouteAssignment, RouteAssignment.escort_id == User.id)
        .join(Student, Student.id == RouteAssignment.student_id)
        .join(Route, Route.id == RouteAssignment.route_id)
        .filter(
            RouteAssignment.student_id.in_(child_ids),
            User.role == "escort",
        )
        .order_by(User.id, Student.id, Route.id)
        .all()
    )

    result_by_key: dict[tuple[int, int], dict] = {}

    for escort, student, route in rows:
        # חשוב:
        # לא כוללים route.id במפתח, כדי שאותו מלווה לא יופיע פעמיים
        # אם הוא מלווה את אותו ילד גם בבוקר וגם בחזור.
        key = (escort.id, student.id)

        if key not in result_by_key:
            result_by_key[key] = {
                "escort_id": escort.id,
                "first_name": escort.first_name,
                "last_name": escort.last_name,
                "phone_number": escort.phone_number,
                "email": escort.email,
                "student_id": student.id,
                "student_name": f"{student.first_name} {student.last_name}",
                "route_id": route.id,
                "route_name": route.name,
                "direction": route.direction,
                "routes": [],
                "route_names": [],
            }

        result_by_key[key]["routes"].append(
            {
                "route_id": route.id,
                "route_name": route.name,
                "direction": route.direction,
            }
        )

        result_by_key[key]["route_names"].append(route.name)

    result = []

    for item in result_by_key.values():
        # משאירים route_name כמחרוזת אחת כדי שהפרונט הקיים יעבוד בלי שינוי ב-api_service.
        unique_route_names = []
        for route_name in item["route_names"]:
            if route_name not in unique_route_names:
                unique_route_names.append(route_name)

        item["route_name"] = " / ".join(unique_route_names)
        result.append(item)

    return result


@router.get("/reports", response_model=list[ParentReportResponse])
def get_my_reports(
    x_user_id: int = Header(...),
    db: Session = Depends(get_db),
):
    return (
        db.query(ParentReport)
        .filter(ParentReport.parent_id == x_user_id)
        .order_by(ParentReport.created_at.desc())
        .all()
    )