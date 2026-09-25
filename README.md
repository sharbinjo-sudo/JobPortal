# Job Portal & Recruitment Management System

A Django REST + Flutter local prototype for job seekers, recruiters, and administrators. It includes JWT authentication, role-protected APIs, recruiter-owned companies/jobs, job search and filtering, duplicate-safe applications, application status history, admin metrics, Swagger documentation, seed data, and a Material 3 Flutter client.

## Readiness status

This repository is suitable for local prototyping, not a production launch. The local resume flow accepts a URL; Supabase Storage multipart upload, EmailJS notifications, persistent Flutter secure-token storage/refresh, and the full recruiter/admin Flutter screens still require implementation and external-service configuration before production deployment.

## Repository

`backend/` contains Django, DRF, JWT, filtering, OpenAPI, admin, seed data, and API tests. `frontend/` contains the Flutter client, typed API models, API service, role-aware login/dashboard shell, and a model test. `docs/` contains API, data, architecture, and setup notes.

## Run locally

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
python manage.py migrate
python manage.py seed_demo
python manage.py runserver
```

```powershell
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

Demo accounts: `admin@example.com / AdminDemo123!`, `recruiter@example.com / RecruiterDemo123!`, `seeker@example.com / SeekerDemo123!`. The Flutter login page has one-click demo account selectors: admins receive system metrics, recruiters receive only their hiring data, and job seekers receive the job-search workspace. Change these credentials before any shared deployment.

## Verification

```powershell
cd backend; python manage.py test
cd ..\frontend; flutter test
```

Swagger is at `http://127.0.0.1:8000/api/docs/`. The backend defaults to SQLite for local development and accepts a PostgreSQL `DATABASE_URL` for Supabase/Render. Configure CORS, allowed hosts, and secrets in `backend/.env`; never commit `.env` or the Supabase service-role key.

## Deployment

Render build: `pip install -r backend/requirements.txt && python backend/manage.py collectstatic --noinput && python backend/manage.py migrate`; start: `cd backend && gunicorn config.wsgi:application`. Flutter Web: `flutter build web --release --dart-define=API_BASE_URL=https://your-api.example.com/api`. Android: `flutter build appbundle --release --dart-define=API_BASE_URL=https://your-api.example.com/api`.

See [docs/SETUP.md](docs/SETUP.md), [docs/API.md](docs/API.md), and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for configuration and endpoint details.

## Flutter Web

The rontend/web/ bootstrap is included, so run lutter run -d chrome directly from rontend after starting Django. If Flutter reports a stale tool process, close previous Flutter sessions and retry with lutter pub get --offline before launching.
