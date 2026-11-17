from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    Time,
)
from ..database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=False)
    first_name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    phone_number = Column(String)
    email = Column(String)
    role = Column(String, nullable=False)
    picture_url = Column(String)


class School(Base):
    __tablename__ = "schools"

    id = Column(Integer, primary_key=True, autoincrement=False)
    name = Column(String, nullable=False)
    address = Column(String, nullable=False)
    latitude = Column(Numeric)
    longitude = Column(Numeric)


class Student(Base):
    __tablename__ = "students"

    id = Column(Integer, primary_key=True, autoincrement=False)
    first_name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    address = Column(String, nullable=False)
    latitude = Column(Numeric)
    longitude = Column(Numeric)
    notes = Column(String)
    mobility_status = Column(String)
    parent_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    school_id = Column(Integer, ForeignKey("schools.id"), nullable=False)
    picture_url = Column(String)
    is_active = Column(Boolean, default=True)


class ParentStudent(Base):
    __tablename__ = "parent_student"

    parent_id = Column(Integer, ForeignKey("users.id"), primary_key=True)
    student_id = Column(Integer, ForeignKey("students.id"), primary_key=True)


class Vehicle(Base):
    __tablename__ = "vehicles"

    id = Column(Integer, primary_key=True)
    vehicle_number = Column(String, nullable=False)
    vehicle_type = Column(String)
    seats_count = Column(Integer)
    has_accessibility = Column(Boolean)
    notes = Column(Text)


class Route(Base):
    __tablename__ = "routes"

    id = Column(Integer, primary_key=True, autoincrement=False)
    school_id = Column(Integer, ForeignKey("schools.id"), nullable=False)
    name = Column(String, nullable=False)
    direction = Column(String, nullable=False)
    planned_departure_time = Column(Time, nullable=False)
    driver_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    vehicle_number = Column(String)
    vehicle_type = Column(String)
    status = Column(String)


class RouteAssignment(Base):
    __tablename__ = "route_assignments"

    id = Column(Integer, primary_key=True, autoincrement=False)
    route_id = Column(Integer, ForeignKey("routes.id"), nullable=False)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False)
    escort_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    default_pickup_order = Column(Integer)


class RouteStudent(Base):
    __tablename__ = "route_students"

    route_id = Column(Integer, ForeignKey("routes.id"), primary_key=True)
    student_id = Column(Integer, ForeignKey("students.id"), primary_key=True)
    pickup_order = Column(Integer)
    planned_pickup_time = Column(Time)


class Ride(Base):
    __tablename__ = "rides"

    id = Column(Integer, primary_key=True, autoincrement=False)
    route_id = Column(Integer, ForeignKey("routes.id"), nullable=False)
    ride_date = Column(Date, nullable=False)
    status = Column(String)
    current_latitude = Column(Numeric)
    current_longitude = Column(Numeric)
    last_location_update = Column(DateTime)


class RideStudent(Base):
    __tablename__ = "ride_students"

    id = Column(Integer, primary_key=True, autoincrement=False)
    ride_id = Column(Integer, ForeignKey("rides.id"), nullable=False)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False)
    escort_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    is_going = Column(Boolean)
    pickup_order = Column(Integer)
    eta_minutes = Column(Integer)
    status = Column(String)
    boarded_time = Column(DateTime)
    dropped_off_time = Column(DateTime)


class Attendance(Base):
    __tablename__ = "attendance"

    id = Column(Integer, primary_key=True)
    ride_id = Column(Integer, ForeignKey("rides.id"), nullable=False)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False)
    status = Column(String, nullable=False)
    updated_by = Column(Integer, ForeignKey("users.id"))
    updated_at = Column(DateTime)


class ParentReport(Base):
    __tablename__ = "parent_reports"

    id = Column(Integer, primary_key=True)
    parent_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False)
    report_type = Column(String, nullable=False)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date)
    message = Column(Text)
    status = Column(String)
    created_at = Column(DateTime)


class RideLocation(Base):
    __tablename__ = "ride_locations"

    id = Column(Integer, primary_key=True)
    ride_id = Column(Integer, ForeignKey("rides.id"), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    recorded_at = Column(DateTime, nullable=False)


class Alert(Base):
    __tablename__ = "alerts"

    id = Column(Integer, primary_key=True)
    ride_id = Column(Integer, ForeignKey("rides.id"))
    alert_type = Column(String, nullable=False)
    message = Column(Text, nullable=False)
    severity = Column(String)
    status = Column(String)
    created_at = Column(DateTime)


class Document(Base):
    __tablename__ = "documents"

    id = Column(Integer, primary_key=True)
    owner_type = Column(String, nullable=False)
    owner_id = Column(Integer)
    document_name = Column(String, nullable=False)
    document_url = Column(Text, nullable=False)
    uploaded_at = Column(DateTime)
