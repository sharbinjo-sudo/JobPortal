# Setup

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
# edit .env and set DATABASE_URL to your Supabase connection string
python manage.py migrate
python manage.py seed_demo
python manage.py runserver
```

The backend requires a PostgreSQL database (Supabase) — there is no SQLite fallback, and the server refuses to start without `DATABASE_URL`. The console email backend prints any emails to the Django terminal, so the database is the only external service. Run `seed_demo` after migrations to load demo accounts, 2 companies (Northstar Labs, Helios Cloud), 6 jobs, and applications spread across every pipeline status, so filtering, dashboards, and reports have real data on first run. The seeder is idempotent — re-running it refreshes demo passwords and updates demo rows without duplicating anything, and `seed_demo --wipe-demo` deletes only the rows the seeder itself created.

## Database (Supabase PostgreSQL)

The database is configured via `backend/.env` (never committed):

```dotenv
DJANGO_DEBUG=false            # true for local development
DATABASE_URL=postgres://postgres.<project-ref>:<db-password>@aws-0-<region>.pooler.supabase.com:5432/postgres
```

- **Password:** the database password from Supabase → Project Settings → Database — *not* the dashboard login password.
- **Percent-encode special characters** in the password (`?`, `#`, `@`, `!`, `%`) — e.g. `!` becomes `%21`. An unencoded password is the most common cause of `Port could not be cast to integer value` startup errors.
- **SSL is always forced** for PostgreSQL connections.
- **Session pooler (5432)** works with Django's persistent connections (`conn_max_age=600`). Use port 6543 only if you exhaust connections.
- **Tests never touch Supabase:** `python manage.py test` always runs against a throwaway SQLite file, regardless of `.env`.
- **Audit trail:** every login (success and failure), registration, job create/update/close, application submission, status change, and resume/logo upload is recorded in the `portal_auditlog` table with actor, IP, user agent, and request ID. Every request also logs a JSON line with request ID, method, path, status, latency, and actor; responses carry an `X-Request-ID` header. Browse the trail in Django admin → Audit logs (read-only).

Verify the deployment:

```powershell
cd backend
python manage.py migrate
python manage.py check --deploy
python manage.py check_prod
python manage.py seed_demo   # demo data only — skip for a clean production DB
```

`check_prod` verifies DB connectivity, SSL, migration state, and the audit-log table against the live Supabase database.

```powershell
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

## Demo accounts

| Role | Email | Password |
| --- | --- | --- |
| Admin | `admin@demo.jobs` | `AdminDemo123!` |
| Recruiter (Northstar Labs) | `recruiter@demo.jobs` | `RecruiterDemo123!` |
| Recruiter (Helios Cloud) | `recruiter2@demo.jobs` | `RecruiterDemo123!` |
| Job seeker | `aarav@demo.jobs` | `SeekerDemo123!` |
| Job seekers (more) | `priya@`, `rohan@`, `sara@`, `vikram@` at `demo.jobs` | `SeekerDemo123!` |

The login page includes one-click chips for the three primary demo accounts. Change these credentials before any shared deployment.

## Login troubleshooting

The login screen diagnoses the two most common "stuck on login" causes for you:

- **Connectivity banner** — before you type anything, the form probes `GET /health/` on the configured API base URL. A green banner means the Django server is reachable; an amber banner shows the base URL it tried and the exact command to start the backend (`cd backend && python manage.py runserver`), with a **Check again** button once the server is up.
- **Sign in never hangs** — token storage races a 3-second timeout and falls back to in-memory/localStorage if `flutter_secure_storage` is blocked (common on web in private mode or with blocked third-party storage), so a storage failure can no longer wedge the sign-in flow. In the worst case the session is simply not persisted across reloads.

Still stuck? Check these in order:

1. `python manage.py runserver` is running in `backend/` and `flutter run` was started with `--dart-define=API_BASE_URL=http://127.0.0.1:8000/api` (Chrome caching an old define is fixed by a hard refresh with the dev tools open).
2. Chrome blocks insecure XHR only on `http://localhost` in some setups — run Chrome with `--disable-web-security --user-data-dir=<temp-dir>` for local development, or open the app via `http://localhost:<port>` rather than a LAN IP (the Django CORS allowlist in `config/settings.py` covers `localhost` origins).
3. `seed_demo` has been run at least once after `migrate`, otherwise none of the demo accounts exist.
4. If you see "Your session has ended. Please sign in again.", the stored refresh token expired or the database was recreated — sign in again rather than retrying an action.

## Walking through the core flows

1. **Seeker** — sign in as a seeker, complete **My profile** (headline, skills, experience, resume upload), then use **Explore jobs** filters (location, skill, employment type, work mode, experience, salary) and apply from the role detail sheet. Track status under **My applications**.
2. **Recruiter** — sign in as a recruiter, review **Overview** metrics, manage postings under **My jobs** (create, edit, close), open **Applicants** on a posting or the combined list, open a candidate to read the cover letter, download the resume, and move the status through Shortlisted → Interview → Selected/Rejected with an optional note. Company profiles and logos live under **Companies**.
3. **Admin** — sign in as the admin: **Overview** shows platform metrics and a status pie chart, **Users** supports deactivation, **Companies** and **Jobs** allow moderation, **Applications** exposes the full pipeline with history, and **Reports** shows most-applied jobs and pipeline conversion.

## Django admin

In addition to the Flutter client, the Django admin at `http://127.0.0.1:8000/admin/` offers full back-office management: user accounts with inline seeker profiles, companies with inline job listings, jobs, and applications with their complete status-history audit trail. Create a superuser with `python manage.py createsuperuser`, or sign in as the seeded `admin@demo.jobs / AdminDemo123!` demo account.

Swagger UI (`http://127.0.0.1:8000/api/docs/`) documents every endpoint with try-it-out requests against the local server.

## File uploads (Supabase Storage)

The Flutter Web client uses `file_picker` for cross-platform file selection. Job seekers select PDF, DOC, or DOCX resumes (maximum 5 MB) on **My profile**. Recruiters use **Companies** to select PNG, JPG, JPEG, or WEBP company logos (maximum 2 MB).

Uploads live in a **private Supabase Storage bucket** through the S3-compatible gateway (`django-storages` + `boto3`). Configure it in `backend/.env` (Supabase → Project Settings → Storage → S3 connection settings):

```dotenv
SUPABASE_S3_ENDPOINT_URL=https://<project-ref>.storage.supabase.co/storage/v1/s3
SUPABASE_S3_REGION=ap-south-1
SUPABASE_S3_BUCKET=resumes
SUPABASE_S3_ACCESS_KEY_ID=<access key>
SUPABASE_S3_SECRET_ACCESS_KEY=<secret key>
SUPABASE_S3_URL_EXPIRE=900
```

- **All five values required** — with any missing, uploads fall back to local disk under `backend/media/` (dev/tests only; `/media/` is served only while `DJANGO_DEBUG=true`).
- **Private by default** — objects are never publicly readable. Every download URL the API returns is a short-lived SigV4 **presigned link** (default 15 minutes, `SUPABASE_S3_URL_EXPIRE`), regenerated per response so links never go stale. Keep the secret key backend-only.
- **Verify** with `python manage.py check_prod` — it HEADs the bucket, uploads a sentinel object, presigns it, downloads it back, and deletes it.

## Verification

```powershell
cd backend; python manage.py test
cd ..\frontend; flutter analyze; flutter test
```

Swagger UI: `http://127.0.0.1:8000/api/docs/`.
