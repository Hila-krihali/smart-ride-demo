import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import Base, engine
from .routes import auth, attendance_routes, route_routes, parent_routes, management_routes


# לא יוצרים טבלאות אוטומטית מול Supabase/PostgreSQL.
# הסכמה האמיתית נמצאת ב-Supabase וב-db_schema.sql.
# ב-SQLite מקומי אפשר ליצור טבלאות אוטומטית.
if engine.url.drivername.startswith("sqlite") or os.getenv("AUTO_CREATE_TABLES") == "true":
    Base.metadata.create_all(bind=engine)


app = FastAPI(
    title="Smart Ride Management API",
    description="Backend API for special education transportation management",
    version="1.0.0",
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://127.0.0.1",
        "http://localhost:3000",
        "http://localhost:5000",
        "http://localhost:8000",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5000",
        "http://127.0.0.1:8000",
    ],
    # מאפשר גם כתובות רשת מקומיות כמו:
    # http://192.168.1.37:5000
    # http://192.168.1.37:8000
    allow_origin_regex=r"^http://(localhost|127\.0\.0\.1|192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+|172\.(1[6-9]|2\d|3[0-1])\.\d+\.\d+)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


app.include_router(auth.router)
app.include_router(attendance_routes.router)
app.include_router(route_routes.router)
app.include_router(parent_routes.router)
app.include_router(management_routes.router)


@app.get("/")
def root():
    return {"message": "Smart Ride Management API", "version": "1.0.0"}


@app.get("/health")
def health():
    return {"status": "ok"}