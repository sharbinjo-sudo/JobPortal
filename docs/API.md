# API quick reference

Base URL: `/api` with JWT `Authorization: Bearer <access>`. Swagger UI: `/api/docs/`; OpenAPI schema: `/api/schema/`.

Responses use `{success, message, data}`. Paginated lists return records in `data` and paging info in `meta` (`count`, `page`, `page_size`, `next`, `previous`; default page size 12, max 100).

## Authentication & account

- `POST /auth/register/` — register `email`, `password`, `first_name`, `last_name`, `role` (`JOB_SEEKER` or `RECRUITER`). Admin accounts cannot self-register.
- `POST /auth/login/` — returns `access` and `refresh`.
- `POST /auth/token/refresh/` — refresh the access token.
- `GET/PATCH /auth/me/` — current account; `role`, `is_active` are server-managed.

## Job seekers

- `GET/PATCH /profiles/me/` — seeker profile: `headline`, `bio`, `location`, `skills` (list), `education`, `experience_years`.
- `POST /profiles/me/resume/` — multipart form data with a `resume` file (PDF, DOC, or DOCX; maximum 5 MB). Required before applying. Stored in a private Supabase Storage bucket; download links returned by the API are presigned and expire (default 15 minutes).
- `POST /applications/apply/{job_id}/` — apply with optional `cover_letter`; duplicate applications return `409`.
- `GET /applications/` — own applications with embedded `history` (status timeline).

## Jobs (public discovery)

- `GET /jobs/` — open jobs by default. Supports `search` (title/location/description), `location`, `skill`, `employment_type` (`FULL_TIME`, `PART_TIME`, `CONTRACT`, `INTERNSHIP`), `work_mode` (`REMOTE`, `HYBRID`, `ONSITE`), `min_experience`/`max_experience` (years), `min_salary`/`max_salary` (brackets against `salary_max`/`salary_min`), `company`, `status`, `ordering` (e.g. `-salary_max`), and pagination.
- Each job includes `company_name`, `is_open`, salary range, skills list, and `experience_min`.

## Recruiters

- `GET/POST /companies/`, `PATCH /companies/{id}/` — recruiter-owned companies (`open_jobs`/`job_count` included); admins see all.
- `POST /companies/{id}/logo/` — multipart `logo` image (PNG, JPG, JPEG, or WEBP; maximum 2 MB).
- `POST /jobs/`, `PATCH /jobs/{id}/` — create/update a job under `company` (must be owned by the requester).
- `POST /jobs/{id}/close/` — close a posting.
- `GET /applications/` — applications to the recruiter's jobs, with applicant details, `resume_url` (a short-lived presigned Supabase Storage link — fetch fresh data rather than caching it), cover letter, and full `history`.
- `PATCH /applications/{id}/status/` — set `status` to one of `APPLIED`, `SHORTLISTED`, `INTERVIEW`, `SELECTED`, `REJECTED` with optional `note`; every change is appended to the application's history.
- `GET /recruiter/dashboard/` — active/total jobs, applicant counts by stage, and the 5 most recent applications.

## Admin

- `GET /admin/users/`, `PATCH /admin/users/{id}/` — manage accounts; deactivate with `is_active: false` (blocked from sign-in, data preserved). Each user includes `application_count`.
- `GET/POST /admin/companies/`, `PATCH /admin/companies/{id}/` — manage every company profile, including `is_active` and job counts.
- `GET /jobs/` as admin returns all jobs regardless of status; `PATCH /jobs/{id}/` and `POST /jobs/{id}/close/` allow moderation.
- `GET /applications/` as admin returns every application; status updates allowed.
- `GET /admin/dashboard/` — platform counts (`users`, `seekers`, `recruiters`, `companies`, `open_jobs`, `closed_jobs`, `applications`, `selected`, `rejected`), `by_status` breakdown, `top_jobs` (5 most applied), and `recent_applications`.
