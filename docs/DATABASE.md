# Database

User roles are `JOB_SEEKER`, `RECRUITER`, and `ADMIN`. Companies belong to recruiters. Jobs belong to both a company and recruiter. Applications have a unique `(job, applicant)` constraint and immutable job ownership. Every status change creates an `ApplicationHistory` row.
