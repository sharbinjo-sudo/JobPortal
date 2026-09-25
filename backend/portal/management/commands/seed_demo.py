from datetime import timedelta

from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone

from portal.models import Application, ApplicationHistory, Company, Job, SeekerProfile, User

DEMO_DOMAIN = 'demo.jobs'

PEOPLE = [
    # local part, first, last, headline, location, skills, experience years
    ('seeker', 'Demo', 'Seeker', 'Job seeker exploring new opportunities', 'Remote', ['Python', 'Flutter', 'Communication'], 2),
    ('aarav', 'Aarav', 'Mehta', 'Python developer seeking product-focused teams', 'Bengaluru', ['Python', 'Django', 'PostgreSQL'], 5),
    ('priya', 'Priya', 'Nair', 'Frontend engineer focused on accessible UI', 'Remote', ['JavaScript', 'Flutter', 'CSS'], 3),
    ('rohan', 'Rohan', 'Gupta', 'Data analyst moving into analytics engineering', 'Pune', ['SQL', 'PostgreSQL', 'dbt'], 2),
    ('sara', 'Sara', 'Iqbal', 'DevOps engineer who enjoys automation', 'Bengaluru', ['Docker', 'Kubernetes', 'Terraform'], 6),
    ('vikram', 'Vikram', 'Rao', 'QA engineer with an automation-first mindset', 'Mumbai', ['Selenium', 'Python', 'Playwright'], 4),
]

JOBS = [
    # company, title, description, location, skills, exp, employment, work mode, salary min, salary max (INR)
    ('Northstar Labs', 'Senior Python Engineer', 'Build reliable services with Django and PostgreSQL.', 'Bengaluru / Remote', ['Python', 'Django', 'PostgreSQL'], 4, 'FULL_TIME', 'HYBRID', 1_800_000, 2_600_000),
    ('Northstar Labs', 'Flutter Developer', 'Craft a polished Material 3 experience across web and mobile.', 'Remote', ['Flutter', 'Dart', 'REST APIs'], 2, 'FULL_TIME', 'REMOTE', 1_200_000, 1_800_000),
    ('Northstar Labs', 'Data Analyst', 'Turn product data into decisions with SQL dashboards.', 'Bengaluru', ['SQL', 'Python', 'Tableau'], 1, 'FULL_TIME', 'ONSITE', 700_000, 1_100_000),
    ('Helios Cloud', 'DevOps Engineer', 'Own CI/CD, infrastructure as code, and on-call reliability.', 'Pune', ['Docker', 'Kubernetes', 'Terraform'], 3, 'FULL_TIME', 'HYBRID', 1_600_000, 2_400_000),
    ('Helios Cloud', 'Platform Intern', 'Support the platform team and learn production operations.', 'Pune', ['Linux', 'Python'], 0, 'INTERNSHIP', 'ONSITE', 300_000, 400_000),
    ('Helios Cloud', 'Solutions Architect', 'Design multi-tenant architectures for enterprise customers.', 'Mumbai', ['AWS', 'Python', 'Kafka'], 6, 'CONTRACT', 'REMOTE', 2_800_000, 3_600_000),
]

APPLICATION_STATUSES = ['APPLIED', 'SHORTLISTED', 'INTERVIEW', 'SELECTED', 'REJECTED']

STATUS_NOTES = {
    'APPLIED': 'Application received.',
    'SHORTLISTED': 'Recruiter shortlisted the candidate.',
    'INTERVIEW': 'Moved to interview stage.',
    'SELECTED': 'Offer extended and accepted.',
    'REJECTED': 'Not progressing with this candidate.',
}


class Command(BaseCommand):
    help = 'Seed production-safe demo data (idempotent; safe to re-run on any database).'

    def add_arguments(self, parser):
        parser.add_argument(
            '--wipe-demo',
            action='store_true',
            help='Delete only rows created by this seeder before seeding.',
        )

    def handle(self, *args, **options):
        with transaction.atomic():
            if options['wipe_demo']:
                self._wipe_demo()

            admin = self._user('admin@demo.jobs', 'System', 'Admin', 'ADMIN', 'AdminDemo123!', is_super=True)
            recruiter = self._user('recruiter@demo.jobs', 'Riya', 'Shah', 'RECRUITER', 'RecruiterDemo123!')
            second = self._user('recruiter2@demo.jobs', 'Kabir', 'Verma', 'RECRUITER', 'RecruiterDemo123!')

            for local, first, last, headline, location, skills, years in PEOPLE:
                seeker = self._user(f'{local}@demo.jobs', first, last, 'JOB_SEEKER', 'SeekerDemo123!')
                SeekerProfile.objects.update_or_create(
                    user=seeker,
                    defaults={
                        'headline': headline,
                        'location': location,
                        'skills': skills,
                        'experience_years': years,
                        'resume_url': f'https://{DEMO_DOMAIN}/resumes/{local}.pdf',
                    },
                )

            companies = {}
            for owner, name, industry, location in [
                (recruiter, 'Northstar Labs', 'Technology', 'Bengaluru'),
                (second, 'Helios Cloud', 'Cloud infrastructure', 'Pune'),
            ]:
                company, _ = Company.objects.update_or_create(
                    name=name,
                    defaults={
                        'owner': owner,
                        'description': f'{name} hires through this demo portal.',
                        'industry': industry,
                        'location': location,
                    },
                )
                companies[name] = company

            jobs = {}
            for company_name, title, description, location, skills, years, employment, work_mode, smin, smax in JOBS:
                job, _ = Job.objects.update_or_create(
                    company=companies[company_name],
                    title=title,
                    defaults={
                        'recruiter': companies[company_name].owner,
                        'description': description,
                        'location': location,
                        'skills': skills,
                        'experience_min': years,
                        'employment_type': employment,
                        'work_mode': work_mode,
                        'salary_min': smin,
                        'salary_max': smax,
                        'currency': 'INR',
                        'status': Job.Status.OPEN,
                    },
                )
                jobs[title] = job

            # Applications: every seeded job gets one applicant, statuses
            # spread across the whole pipeline so dashboards and reports
            # have data. Application history entries get realistic
            # backdated timestamps so the audit trail looks natural.
            seekers = [u for u in User.objects.filter(role='JOB_SEEKER', email__endswith='@demo.jobs') if u.email != 'aarav@demo.jobs']
            for index, (title, job) in enumerate(jobs.items()):
                applicant = seekers[index % len(seekers)]
                target = APPLICATION_STATUSES[index % len(APPLICATION_STATUSES)]
                application, created = Application.objects.get_or_create(
                    job=job,
                    applicant=applicant,
                    defaults={
                        'resume_url': f'https://{DEMO_DOMAIN}/resumes/{applicant.email.split("@")[0]}.pdf',
                        'cover_letter': f'I am excited about the {title} role.',
                        'status': target,
                    },
                )
                if created:
                    applied_at = timezone.now() - timedelta(days=len(jobs) - index)
                    ApplicationHistory.objects.create(
                        application=application,
                        new_status='APPLIED',
                        changed_by=applicant,
                        note=STATUS_NOTES['APPLIED'],
                    )
                    if target != 'APPLIED':
                        ApplicationHistory.objects.create(
                            application=application,
                            old_status='APPLIED',
                            new_status=target,
                            changed_by=job.recruiter,
                            note=STATUS_NOTES.get(target, ''),
                        )
                    # Backdate so charts show activity across recent days.
                    Application.objects.filter(pk=application.pk).update(applied_at=applied_at)

        self.stdout.write(self.style.SUCCESS(
            'Demo data ready: admin@demo.jobs / AdminDemo123!, recruiter@demo.jobs / RecruiterDemo123!, '
            'recruiter2@demo.jobs / RecruiterDemo123!, plus seeker/aarav/priya/rohan/sara/vikram@demo.jobs (SeekerDemo123!).'
        ))

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------
    def _user(self, email, first, last, role, password, is_super=False):
        user, created = User.objects.get_or_create(
            email=email,
            defaults={'first_name': first, 'last_name': last, 'role': role},
        )
        if is_super:
            user.is_staff = True
            user.is_superuser = True
        user.set_password(password)  # refresh so demo logins always work
        user.save()
        return user

    def _wipe_demo(self):
        """Delete only demo-owned rows; leaves any real data untouched."""
        demo_users = User.objects.filter(email__endswith='@demo.jobs')
        Application.objects.filter(applicant__in=demo_users).delete()
        Job.objects.filter(company__name__in=['Northstar Labs', 'Helios Cloud']).delete()
        Company.objects.filter(name__in=['Northstar Labs', 'Helios Cloud']).delete()
        SeekerProfile.objects.filter(user__in=demo_users).delete()
        demo_users.delete()
