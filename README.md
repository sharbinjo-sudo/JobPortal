# Job Portal & Recruitment Management System

A Django REST + Flutter local prototype covering the full recruitment lifecycle: job seekers register and upload resumes, recruiters create companies and post jobs, candidates apply and track their status through the pipeline (Applied → Shortlisted → Interview → Selected/Rejected), and admins manage users, companies, postings, applications, and reports.

## Feature checklist

1. **Job seekers** — register, build a profile (headline, bio, skills, experience, location), and upload PDF/DOC/DOCX resumes up to 5 MB.
2. **Recruiters** — create and edit company profiles with logo uploads (PNG/JPG/JPEG/WEBP up to 2 MB), and publish, edit, and close job vacancies.
3. **Job display** — title, company, location, salary range with currency, skills, and required experience on every card and detail sheet.
4. **Search & filters** — server-side filtering by title/description search, location, skill, employment type, work mode, experience, and minimum salary.
5. **Applications** — seekers apply with an optional cover letter; duplicate applications are blocked; the My Applications page tracks live status per application.
6. **Recruiter pipeline** — per-job and combined applicant views with candidate details, resume download links, and one-click status updates with notes.
7. **Statuses** — Applied, Shortlisted, Interview, Selected, Rejected, with a complete change-history audit trail on every application.
8. **Admin** — manage users (deactivate/activate), companies, all job postings (with moderation close), all applications, and a reports view (status pie chart, most-applied jobs bar chart, pipeline conversion breakdown).

## Repository

`backend/` contains Django, DRF, JWT, filtering, OpenAPI, a fully configured admin, seed data, and 21 API tests. `frontend/` contains the Flutter client, typed API models, API service, role-aware workspaces, and model tests. `docs/` contains API, setup, and architecture notes.

## Run locally

The backend requires a PostgreSQL database (Supabase) — there is no SQLite fallback. Copy `backend/.env.example` to `backend/.env`, set `DATABASE_URL` to your Supabase connection string (percent-encode special characters in the password: `?`, `#`, `@`, `!`, `%`), then:

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

Uploads (resumes, logos) are stored on disk in `backend/media/`, and the console email backend prints emails to the terminal — so only the database is external. The demo seeder is idempotent and safe to re-run; it never deletes data it did not create (`seed_demo --wipe-demo` removes only its own rows).

### Database (Supabase PostgreSQL)

The database is Supabase PostgreSQL, configured via `DATABASE_URL` in `backend/.env` (ignored by Git) with SSL always forced. Tests always run against a throwaway SQLite database and never touch Supabase data. The audit trail (`portal_auditlog`) captures logins, job and application lifecycle events with actor, IP, and request ID; every request logs a structured JSON line and carries an `X-Request-ID` header.

```powershell
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

Demo accounts: `admin@demo.jobs / AdminDemo123!`, `recruiter@demo.jobs / RecruiterDemo123!`, `recruiter2@demo.jobs / RecruiterDemo123!`, `aarav@demo.jobs / SeekerDemo123!`, plus `priya`, `rohan`, `sara`, and `vikram` at `demo.jobs` (all `SeekerDemo123!`). The seed loads 2 companies, 6 jobs, and applications spread across every pipeline status so dashboards, filters, and reports have real data on first run. The Flutter login page has one-click demo account selectors. Change these credentials before any shared deployment.

The local website includes registration for job seekers and recruiters, persistent JWT session restoration, role-based workspaces, job discovery with filters, profile/resume management, job application tracking, recruiter hiring metrics and applicant pipeline, and admin user/company/job/application management with reports. Admin accounts cannot be created through public registration.

Resume uploads use the Flutter `file_picker` package and accept PDF, DOC, and DOCX files up to 5 MB. Recruiter company assets use the same picker for logo files up to 2 MB. In local development, Django stores these assets in `backend/media/`.

## Verification

```powershell
cd backend; python manage.py test
cd ..\frontend; flutter analyze; flutter test
```

Swagger is at `http://127.0.0.1:8000/api/docs/`. The backend needs only the Supabase `DATABASE_URL`; uploads stay on local disk and emails print to the terminal. SMTP can be layered in later via `DJANGO_EMAIL_BACKEND` in `backend/.env` — no code changes required. Never commit `.env`.

## Deployment

Render build: `pip install -r backend/requirements.txt && python backend/manage.py collectstatic --noinput && python backend/manage.py migrate`; start: `cd backend && gunicorn config.wsgi:application`. Flutter Web: `flutter build web --release --dart-define=API_BASE_URL=https://your-api.example.com/api`. Android: `flutter build appbundle --release --dart-define=API_BASE_URL=https://your-api.example.com/api`.

## Readiness status

This repository is **cloud-DB ready**: it runs end-to-end against a Supabase PostgreSQL database with local media storage (resumes/logos in `backend/media/`) and a console email backend. Remaining cloud integrations (object storage, transactional email, push notifications) can be layered in later through `backend/.env` settings without code changes.

A real internet-facing launch still needs managed object storage, production secrets and hosts, HTTPS, and email delivery — see the deployment notes above.

See [docs/SETUP.md](docs/SETUP.md), [docs/API.md](docs/API.md), and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for configuration and endpoint details.

## Flutter Web

The `frontend/web/` bootstrap is included, so run `flutter run -d chrome` directly from `frontend` after starting Django. If Flutter reports a stale tool process, close previous Flutter sessions and retry with `flutter pub get --offline` before launching.
