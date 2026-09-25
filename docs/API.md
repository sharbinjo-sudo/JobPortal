# API quick reference

Base URL: `/api` with JWT `Authorization: Bearer <access>`.

- `POST /auth/register/` — register `email`, `password`, `first_name`, `last_name`, and `role` (`JOB_SEEKER` or `RECRUITER`).
- `POST /auth/login/` — returns `access` and `refresh`.
- `POST /auth/token/refresh/` — refresh access token.
- `GET/PATCH /auth/me/` — current account.
- `GET/PATCH /profiles/me/` — seeker profile; `POST /profiles/me/resume/` accepts a local prototype resume URL.
- `GET /jobs/` — public open jobs; supports `search`, `location`, `employment_type`, `work_mode`, `status`, `ordering`, `page`.
- `POST /jobs/`, `PATCH /jobs/{id}/`, `POST /jobs/{id}/close/` — recruiter-owned jobs.
- `GET/POST /companies/` — recruiter company management.
- `POST /applications/apply/{job_id}/` — seeker application; duplicate applications return `409`.
- `GET /applications/` — own seeker applications, recruiter job applications, or all admin applications.
- `PATCH /applications/{id}/status/` — recruiter/admin status change.
- `GET /admin/dashboard/` — admin aggregate counts and status breakdown.
- `/docs/` — Swagger UI; `/schema/` — OpenAPI JSON.

Responses use `{success, message, data}`. Paginated lists return records in `data` and paging information in `meta` (`count`, `page`, `page_size`, `next`, `previous`). Job listing also supports `skill`, `min_experience`, `max_experience`, `min_salary`, and `max_salary` filters.
