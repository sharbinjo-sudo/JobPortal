# Architecture

The Django `portal` app owns the normalized user, profile, company, job, application, and history models. API authorization is enforced server-side with JWT and role permissions. Flutter is a single Material 3 client with role-aware presentation and a repository-facing API service. PostgreSQL is the production database; SQLite is the zero-configuration local fallback. Resume storage is represented by a URL field and is ready for a backend Supabase Storage adapter; service-role credentials must remain backend-only.
