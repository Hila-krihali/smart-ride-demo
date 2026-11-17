from pydantic import BaseModel
from datetime import date, datetime
from typing import Optional


# --- Auth ---
class LoginRequest(BaseModel):
    email: str

class LoginResponse(BaseModel):
    id: int
    user_id: int
    role: str
    first_name: str
    last_name: str
    email: Optional[str] = None
    phone_number: Optional[str] = None


# --- Attendance ---
class AttendanceUpdate(BaseModel):
    ride_id: int
    student_id: int
    status: str  # waiting / picked_up / absent / dropped_off

class AttendanceResponse(BaseModel):
    id: int
    ride_id: int
    student_id: int
    status: str
    updated_by: Optional[int] = None
    updated_at: Optional[datetime] = None
    class Config:
        from_attributes = True


# --- Location ---
class LocationUpdate(BaseModel):
    latitude: float
    longitude: float

class LocationResponse(BaseModel):
    ride_id: int
    latitude: float
    longitude: float
    recorded_at: datetime
    class Config:
        from_attributes = True


# --- Route Optimization ---
class StopPoint(BaseModel):
    student_id: int
    student_name: str
    address: str
    latitude: float
    longitude: float
    pickup_order: int

class OptimizedRouteResponse(BaseModel):
    route_id: int
    route_name: str
    stops: list[StopPoint]
    geometry: list[list[float]] | None = None


# --- Parent Report ---
class ParentReportCreate(BaseModel):
    student_id: int
    report_type: str
    start_date: date
    end_date: Optional[date] = None
    message: Optional[str] = None

class ParentReportResponse(BaseModel):
    id: int
    parent_id: int
    student_id: int
    report_type: str
    start_date: date
    end_date: Optional[date] = None
    message: Optional[str] = None
    status: str
    created_at: Optional[datetime] = None
    class Config:
        from_attributes = True


# --- Student ---
class StudentResponse(BaseModel):
    id: int
    first_name: str
    last_name: str
    address: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    mobility_status: Optional[str] = None
    notes: Optional[str] = None
    parent_id: int
    school_id: int
    picture_url: Optional[str] = None
    attendance_status: Optional[str] = None
    ride_student_status: Optional[str] = None
    reported_absent_today: Optional[bool] = None
    effective_status: Optional[str] = None
    route_direction: Optional[str] = None
    active_ride_id: Optional[int] = None
    eta_minutes: Optional[int] = None
    class Config:
        from_attributes = True


# --- Route ---
class RouteResponse(BaseModel):
    id: int
    name: str
    route_name: str
    direction: str
    planned_departure_time: Optional[str] = None
    driver_id: int
    escort_id: Optional[int] = None
    vehicle_number: Optional[str] = None
    vehicle_type: Optional[str] = None
    status: str


class RideResponse(BaseModel):
    id: int
    route_id: int
    ride_date: date
    status: Optional[str] = None
    current_latitude: Optional[float] = None
    current_longitude: Optional[float] = None
    last_location_update: Optional[datetime] = None
    class Config:
        from_attributes = True


class RouteStudentResponse(BaseModel):
    route_id: int
    student_id: int
    pickup_order: Optional[int] = None
    planned_pickup_time: Optional[str] = None


class RouteAssignmentResponse(BaseModel):
    id: int
    route_id: int
    student_id: int
    escort_id: int
    default_pickup_order: Optional[int] = None
    pickup_order: Optional[int] = None
    attendance_status: Optional[str] = None
    ride_student_status: Optional[str] = None
    reported_absent_today: bool = False
    effective_status: Optional[str] = None
    route_direction: Optional[str] = None
    active_ride_id: Optional[int] = None
    student: StudentResponse


class RideStudentResponse(BaseModel):
    id: int
    ride_id: int
    student_id: int
    escort_id: int
    is_going: Optional[bool] = None
    pickup_order: Optional[int] = None
    eta_minutes: Optional[int] = None
    status: Optional[str] = None
    boarded_time: Optional[datetime] = None
    dropped_off_time: Optional[datetime] = None
    class Config:
        from_attributes = True
