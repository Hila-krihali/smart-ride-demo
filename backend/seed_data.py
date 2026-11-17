"""Seed a local SQLite database with Hebrew schema-compatible demo data.

Do not use this script for Supabase.

For Supabase demo data, run:
backend/supabase_demo_data.sql

inside Supabase SQL Editor.
"""

from datetime import date, datetime, time

from app.database import Base, SessionLocal, engine
from app.models.models import (
    Alert,
    Attendance,
    ParentReport,
    ParentStudent,
    Ride,
    RideStudent,
    Route,
    RouteAssignment,
    RouteStudent,
    School,
    Student,
    User,
    Vehicle,
)


is_sqlite = engine.url.drivername.startswith("sqlite")

if not is_sqlite:
    raise SystemExit(
        "Refusing to run seed_data.py against a non-SQLite database. "
        "This script deletes and recreates demo data, so it is only safe for local SQLite. "
        "For Supabase, run backend/supabase_demo_data.sql in Supabase SQL Editor."
    )


Base.metadata.drop_all(bind=engine)
Base.metadata.create_all(bind=engine)

db = SessionLocal()

try:
    db.add_all(
        [
            User(
                id=1,
                first_name="שרה",
                last_name="כהן",
                phone_number="050-1234567",
                email="sara@example.com",
                role="escort",
            ),
            User(
                id=2,
                first_name="רחל",
                last_name="לוי",
                phone_number="050-2345678",
                email="rachel@example.com",
                role="parent",
            ),
            User(
                id=3,
                first_name="דוד",
                last_name="מזרחי",
                phone_number="050-3456789",
                email="david@example.com",
                role="driver",
            ),
            User(
                id=4,
                first_name="יעל",
                last_name="אברהם",
                phone_number="050-4567890",
                email="yael@example.com",
                role="manager",
            ),
            User(
                id=5,
                first_name="מיכל",
                last_name="פרץ",
                phone_number="050-5678901",
                email="michal@example.com",
                role="parent",
            ),
            User(
                id=6,
                first_name="אבי",
                last_name="גולד",
                phone_number="050-6789012",
                email="avi@example.com",
                role="escort",
            ),
            User(
                id=7,
                first_name="משה",
                last_name="ביטון",
                phone_number="050-7890123",
                email="moshe@example.com",
                role="driver",
            ),
        ]
    )

    db.add_all(
        [
            School(
                id=1,
                name="בית ספר אופק",
                address="רחוב הרצל 15, באר שבע",
                latitude=31.2530,
                longitude=34.7915,
            ),
            School(
                id=2,
                name="מרכז חינוכי שחר",
                address="רחוב ביאליק 8, באר שבע",
                latitude=31.2500,
                longitude=34.7890,
            ),
        ]
    )

    db.add_all(
        [
            Student(
                id=1,
                first_name="יוסי",
                last_name="לוי",
                address="שדרות רגר 22, באר שבע",
                latitude=31.2518,
                longitude=34.7913,
                notes="רגיש לרעש. מומלץ לעדכן מראש במקרה של שינוי במסלול.",
                mobility_status="רגיל",
                parent_id=2,
                school_id=1,
            ),
            Student(
                id=2,
                first_name="נועה",
                last_name="לוי",
                address="שדרות רגר 22, באר שבע",
                latitude=31.2518,
                longitude=34.7913,
                notes="זקוקה לתזכורת רגועה לפני העלייה להסעה.",
                mobility_status="רגיל",
                parent_id=2,
                school_id=1,
            ),
            Student(
                id=3,
                first_name="עומר",
                last_name="פרץ",
                address="רחוב הנשיאים 5, באר שבע",
                latitude=31.2545,
                longitude=34.7880,
                notes="זקוק לעזרה בעלייה לרכב.",
                mobility_status="כיסא גלגלים",
                parent_id=5,
                school_id=1,
            ),
            Student(
                id=4,
                first_name="תמר",
                last_name="דהן",
                address="שדרות בן גוריון 30, באר שבע",
                latitude=31.2490,
                longitude=34.7950,
                notes="יש לוודא שאחד ההורים נמצא בבית בזמן האיסוף.",
                mobility_status="רגיל",
                parent_id=2,
                school_id=1,
            ),
            Student(
                id=5,
                first_name="איתן",
                last_name="אזולאי",
                address="רחוב העצמאות 12, באר שבע",
                latitude=31.2560,
                longitude=34.7870,
                notes="זקוק לליווי צמוד בתחילת הנסיעה.",
                mobility_status="ליווי מיוחד",
                parent_id=5,
                school_id=2,
            ),
            Student(
                id=6,
                first_name="מאיה",
                last_name="גבאי",
                address="רחוב קרן קיימת 7, באר שבע",
                latitude=31.2475,
                longitude=34.7935,
                notes="מומלץ להושיב ליד החלון.",
                mobility_status="רגיל",
                parent_id=5,
                school_id=2,
            ),
        ]
    )

    db.add_all(
        [
            ParentStudent(parent_id=2, student_id=1),
            ParentStudent(parent_id=2, student_id=2),
            ParentStudent(parent_id=2, student_id=4),
            ParentStudent(parent_id=5, student_id=3),
            ParentStudent(parent_id=5, student_id=5),
            ParentStudent(parent_id=5, student_id=6),
        ]
    )

    db.add_all(
        [
            Vehicle(
                id=1,
                vehicle_number="12-345-67",
                vehicle_type="מיניבוס נגיש",
                seats_count=12,
                has_accessibility=True,
            ),
            Vehicle(
                id=2,
                vehicle_number="23-456-78",
                vehicle_type="מיניבוס רגיל",
                seats_count=8,
                has_accessibility=False,
            ),
        ]
    )
    db.add_all(
        [
            Route(
                id=1,
                school_id=1, # <--- הוספנו
                name="מסלול 1 - אופק בוקר",
                direction="morning",
                planned_departure_time=time(7, 15),
                driver_id=3,
                vehicle_number="12-345-67",
                vehicle_type="מיניבוס נגיש",
                status="active",
            ),
            Route(
                id=2,
                school_id=1, # <--- הוספנו
                name="מסלול 1 - אופק צהריים",
                direction="afternoon",
                planned_departure_time=time(14, 0),
                driver_id=3,
                vehicle_number="12-345-67",
                vehicle_type="מיניבוס נגיש",
                status="planned",
            ),
            Route(
                id=3,
                school_id=1, # <--- הוספנו (אפשר גם 2 אם יש בית ספר שני)
                name="מסלול 2 - שחר בוקר",
                direction="morning",
                planned_departure_time=time(7, 30),
                driver_id=7,
                vehicle_number="23-456-78",
                vehicle_type="מיניבוס רגיל",
                status="planned",
            ),
        ]
    )

    db.add_all(
        [
            RouteAssignment(
                id=1,
                route_id=1,
                student_id=1,
                escort_id=1,
                default_pickup_order=1,
            ),
            RouteAssignment(
                id=2,
                route_id=1,
                student_id=2,
                escort_id=1,
                default_pickup_order=2,
            ),
            RouteAssignment(
                id=3,
                route_id=1,
                student_id=3,
                escort_id=1,
                default_pickup_order=3,
            ),
            RouteAssignment(
                id=4,
                route_id=1,
                student_id=4,
                escort_id=1,
                default_pickup_order=4,
            ),
            RouteAssignment(
                id=5,
                route_id=2,
                student_id=1,
                escort_id=1,
                default_pickup_order=1,
            ),
            RouteAssignment(
                id=6,
                route_id=2,
                student_id=2,
                escort_id=1,
                default_pickup_order=2,
            ),
            RouteAssignment(
                id=7,
                route_id=3,
                student_id=5,
                escort_id=6,
                default_pickup_order=1,
            ),
            RouteAssignment(
                id=8,
                route_id=3,
                student_id=6,
                escort_id=6,
                default_pickup_order=2,
            ),
        ]
    )

    db.add_all(
        [
            RouteStudent(
                route_id=1,
                student_id=1,
                pickup_order=1,
                planned_pickup_time=time(7, 30),
            ),
            RouteStudent(
                route_id=1,
                student_id=2,
                pickup_order=2,
                planned_pickup_time=time(7, 35),
            ),
            RouteStudent(
                route_id=1,
                student_id=3,
                pickup_order=3,
                planned_pickup_time=time(7, 40),
            ),
            RouteStudent(
                route_id=1,
                student_id=4,
                pickup_order=4,
                planned_pickup_time=time(7, 50),
            ),
            RouteStudent(
                route_id=2,
                student_id=1,
                pickup_order=1,
                planned_pickup_time=time(14, 0),
            ),
            RouteStudent(
                route_id=2,
                student_id=2,
                pickup_order=2,
                planned_pickup_time=time(14, 5),
            ),
            RouteStudent(
                route_id=3,
                student_id=5,
                pickup_order=1,
                planned_pickup_time=time(7, 45),
            ),
            RouteStudent(
                route_id=3,
                student_id=6,
                pickup_order=2,
                planned_pickup_time=time(7, 55),
            ),
        ]
    )

    db.add_all(
        [
            Ride(
                id=1,
                route_id=1,
                ride_date=date.today(),
                status="active",
                current_latitude=31.2480,
                current_longitude=34.7900,
                last_location_update=datetime.now(),
            ),
            Ride(
                id=2,
                route_id=2,
                ride_date=date.today(),
                status="planned",
            ),
            Ride(
                id=3,
                route_id=3,
                ride_date=date.today(),
                status="planned",
            ),
        ]
    )

    db.add_all(
        [
            RideStudent(
                id=1,
                ride_id=1,
                student_id=1,
                escort_id=1,
                is_going=True,
                pickup_order=1,
                eta_minutes=0,
                status="picked_up",
                boarded_time=datetime.now(),
            ),
            RideStudent(
                id=2,
                ride_id=1,
                student_id=2,
                escort_id=1,
                is_going=True,
                pickup_order=2,
                eta_minutes=0,
                status="picked_up",
                boarded_time=datetime.now(),
            ),
            RideStudent(
                id=3,
                ride_id=1,
                student_id=3,
                escort_id=1,
                is_going=True,
                pickup_order=3,
                eta_minutes=8,
                status="waiting",
            ),
            RideStudent(
                id=4,
                ride_id=1,
                student_id=4,
                escort_id=1,
                is_going=True,
                pickup_order=4,
                eta_minutes=14,
                status="waiting",
            ),
        ]
    )

    db.add_all(
        [
            Attendance(
                id=1,
                ride_id=1,
                student_id=1,
                status="picked_up",
                updated_by=1,
                updated_at=datetime.now(),
            ),
            Attendance(
                id=2,
                ride_id=1,
                student_id=2,
                status="picked_up",
                updated_by=1,
                updated_at=datetime.now(),
            ),
            Attendance(
                id=3,
                ride_id=1,
                student_id=3,
                status="waiting",
                updated_at=datetime.now(),
            ),
            Attendance(
                id=4,
                ride_id=1,
                student_id=4,
                status="waiting",
                updated_at=datetime.now(),
            ),
        ]
    )

    db.add(
        ParentReport(
            id=1,
            parent_id=5,
            student_id=3,
            report_type="morning_absence",
            start_date=date.today(),
            message="עומר לא מרגיש טוב ולא יגיע היום להסעה.",
            status="open",
            created_at=datetime.now(),
        )
    )

    db.add_all(
        [
            Alert(
                id=1,
                ride_id=1,
                alert_type="delay",
                message="מסלול 1 בבוקר מתעכב בכ־5 דקות.",
                severity="low",
                status="open",
                created_at=datetime.now(),
            ),
            Alert(
                id=2,
                alert_type="parent_report",
                message="התקבל דיווח היעדרות חדש מהורה.",
                severity="medium",
                status="open",
                created_at=datetime.now(),
            ),
        ]
    )

    db.commit()
    print("Local SQLite Hebrew seed data loaded successfully.")

except Exception:
    db.rollback()
    raise

finally:
    db.close()