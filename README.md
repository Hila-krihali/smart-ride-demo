# 🚐 Smart Ride – Live Demo

**▶️ Try it in the browser:** https://hila-krihali.github.io/smart-ride-demo/

The demo runs fully in the browser – no server, no sign-up. It uses the built-in
demo backend (`lib/demo/`), which mirrors the FastAPI endpoints with the sample
data from `backend/seed_data.py`. Refreshing the page resets the data.

| Role | Email (tap it on the login screen) | What to try |
|------|------------------------------------|-------------|
| Manager / מנהלת | `yael@example.com` | Live dashboard: active rides, routes, alerts |
| Escort / מלווה | `sara@example.com` | Mark students as boarded / dropped off |
| Driver / נהג | `david@example.com` | Start the ride and watch the bus move on the map |
| Parent / הורה | `rachel@example.com` | See the child's status, report an absence |

Tip: log in as the parent and report an absence, then log out and log in as the
escort – the student appears as absent. Changes are shared between roles until
the page is refreshed.

To build the demo locally:

```bash
flutter run -d chrome --dart-define=DEMO_MODE=true
```

---

# Project: Smart Transportation System for Special Needs Students (Fast Hackathon MVP)

## Project Overview & Stack
This project is an enterprise-concept digital platform for managing special needs student transportation, optimized for rapid Hackathon development.
* **Frontend:** Flutter (Mobile App supporting Admin, Attendant, and Parent views).
* **Backend:** Python (FastAPI or Flask) - Handles business logic, AI routing, and API endpoints.
* **Database & Auth:** Supabase (Used strictly as a hosted PostgreSQL instance, accessed via Python ORM).
* **Media Storage:** Cloudinary (External Cloud Storage for images/files).

---

## AI & Copilot Developer Instructions (CRITICAL)
Whenever you assist with writing code, generating Flutter widgets, Python endpoints, or database queries for this project, you **MUST strictly adhere** to the following guardrails to maximize development speed:

### 1. Language & Layout (Hebrew & RTL)
* All user-facing text, buttons, alerts, and labels in Flutter **must be in Hebrew**.
* Flutter widgets must fully support **Right-to-Left (RTL)** layout rendering (using `Directionality` or localized `MaterialApp`).

### 2. Simplified Fast Security (No Complex Tokens)
* Do **NOT** implement complex OAuth, NextAuth, or JWT boilerplate from scratch. 
* Use **ID-Based Security**: Flutter will pass the raw `user_id` and `role` directly in the HTTP request headers or query parameters to the Python backend.
* **Data Isolation (Application-level):** Inside the Python logic, validate data ownership (e.g., Ensure the querying `user_id` is matched as the parent of the requested `student_id` before returning data).

### 3. Database Agnostic ORM Approach (PostgreSQL Ready)
* The cloud database is PostgreSQL (hosted on Supabase Free Tier), but the Python backend **MUST** interact with it using a **generic ORM approach (like SQLAlchemy models)**.
* Do **NOT** write raw, engine-specific SQL queries. All queries must be database-agnostic so that switching from cloud Supabase to a local SQLite/Postgres container requires zero business logic modifications.
* **Constraint Notice:** The Supabase Free Tier has a 500MB limit. Keep text/log data lightweight.
* **Crucial Rule for AI:** **NEVER** write or execute migration code that triggers database-level restarts or global configuration changes. All schema mutations must be handled strictly via raw DDL/SQL migrations or local ORM syncs.

### 4. Real-Time Tracking & AI Routing Logic
* **Dynamic Route Optimization:** The Python backend needs a lightweight endpoint that calculates/sorts the optimal pickup sequence of students for a specific route.
* **Live Coordinates:** The Attendant's app periodically sends GPS latitude/longitude updates via simple HTTP POST to the Python backend.
* **Parent Live Map & ETA:** The Parent app polls the Python backend for these live coordinates and displays a live **ETA (Estimated Time of Arrival)** back home on a map view.

---

## Targeted Demo Features & Technical Workflows

### 1. Attendant Mobile Interface (Flutter - ממשק מלווה)
* **Daily Attendance Screen:** Displays the optimized list of students in an RTL layout.
* **Check-in Actions:** Features prominent **"עלה" (Boarded)** and **"ירד" (Dropped Off)** buttons. Tapping them triggers an immediate HTTP POST request to the Python backend to update the live attendance state.
* **Pre-reported Absence:** Students marked absent by parents must appear greyed out and unclickable.

### 2. Parent Mobile Interface (Flutter - ממשק הורה)
* **Live Map Tracking Screen:** Renders a map showing the current vehicle location based on quick API polling from the Python backend. Features an ETA text overlay: **"זמן הגעה משוער הביתה: XX דקות"**.
* **Report Absence Form:** Allows parents to submit an upcoming absence date, which immediately signals the backend to update the status and re-sort the route.

### 3. Administrator Interface (Flutter - ממשק מנהל)
* **Live Monitor Console:** A master dashboard rendering real-time route execution data and live check-in logs received from the backend.

### 4. Simplified Backend Endpoints (Python & ORM)
* `POST /auth/login` - Simple verification. Returns `user_id` and `role`.
* `GET /route/{route_id}/optimize` - Returns the sorted array of student stops using ORM queries.
* `POST /route/{route_id}/location` - Updates the live longitude/latitude of the transit vehicle.
* `POST /attendance/status` - Records a student's check-in ('boarded'/'dropped_off').

---

## Media & Image Handling (Cloudinary Enforced Workflow)
To respect database storage limits and ensure zero-friction performance, binary media/images **MUST NOT** be stored in the SQL database. 

**The enforced workflow for handling file/image uploads is as follows:**
1. **Client File Selection:** The Flutter UI selects the image with `image_picker`.
2. **Backend Upload:** Flutter sends the image to FastAPI as `multipart/form-data`; FastAPI uploads it to Cloudinary using the configured upload preset.
3. **Asset Optimization:** Cloudinary can be configured via its dashboard with *Incoming Transformations* to automatically compress and convert incoming images to lightweight formats (e.g., `webp`, `quality: auto`).
4. **Database Storage:** Cloudinary returns a secure delivery URL string. The application stores **only this string URL** in the database table, currently `students.picture_url`.
5. **Rendering:** Flutter renders images globally using the stored URL directly.

---

## Environment Configurations & Robustness
* All API keys, secrets, Cloudinary configurations, and the Supabase Connection String **must** be stored securely in a local `.env` file.
* **Offline/Fail-safe Capability:** The ORM configuration must support switching to a local `localhost` PostgreSQL connection string (e.g., via Docker) in the event of upstream network constraints. Never hardcode absolute cloud URLs into application controllers.

# smart_ride_management

A Flutter frontend and FastAPI backend project for managing school rides.

## Prerequisites

Before running the project, install:

1. Flutter SDK: https://docs.flutter.dev/get-started/install
2. Python 3.10+ (or compatible) and pip
3. Chrome, for local web runs with `flutter run -d chrome`
4. A terminal or command prompt
5. A Cloudinary account with an unsigned upload preset

## Backend: FastAPI

### 1. Open a terminal in the backend folder

```powershell
cd c:\Users\lielk\smart_ride_management\backend
```

### 2. Create and activate a Python virtual environment

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
```

If you use Command Prompt:

```cmd
venv\Scripts\activate.bat
```

### 3. Install dependencies

```powershell
pip install -r requirements.txt
```

This installs the backend packages needed for the API, database, and uploads, including:

- `fastapi`
- `SQLAlchemy`
- `psycopg` / `psycopg2-binary`
- `python-dotenv`
- `cloudinary`
- `python-multipart`

### 4. Configure environment variables

Create or update `backend/.env`:

```env
DATABASE_URL=your_database_connection_string
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_UPLOAD_PRESET=your_unsigned_upload_preset
```

For student images, the database must include:

```sql
students.picture_url
```

`CLOUDINARY_API_KEY` and `CLOUDINARY_API_SECRET` are optional. If they are not set, the backend uses the unsigned upload preset.

### 5. Run the FastAPI server

```powershell
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

The backend API will be available at `http://127.0.0.1:8000`.

To connect from a phone on the same Wi-Fi network, run the backend on all
interfaces:

```powershell
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Then set the Flutter API address in `lib/config/app_config.dart`, for example:

```dart
defaultValue: 'http://YOUR_COMPUTER_IP:8000',
```

You can also override it without editing the file:

```powershell
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 5000
```

## Frontend: Flutter on Chrome

### 1. Open a terminal in the project root

```powershell
cd c:\Users\lielk\smart_ride_management
```

### 2. Get Flutter dependencies

```powershell
flutter pub get
```

This installs the Flutter packages needed by the app, including:

- `http`
- `http_parser`
- `image_picker`
- `flutter_map`
- `google_fonts`

### 3. Run the Flutter app on Chrome

```powershell
flutter run -d chrome --dart-define="API_BASE_URL=http://127.0.0.1:8000"
```

The frontend will launch in a Chrome browser window, and it should connect to the backend if the backend is running.

## Notes

- Start the backend first so the frontend can connect to the API.
- If Chrome is not available or not detected, install Chrome or run `flutter devices` to verify available targets.
- If you need to restart the backend, stop the server and run the `uvicorn` command again.
