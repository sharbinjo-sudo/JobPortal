"""Verify the remote services required for a production deployment."""
from django.core.management.base import BaseCommand, CommandError
from django.db import connection
from django.db.migrations.executor import MigrationExecutor


class Command(BaseCommand):
    help = 'Verify Supabase PostgreSQL, Supabase Storage, EmailJS, and migrations.'

    def handle(self, *args, **options):
        from django.conf import settings
        from portal.emailing import is_emailjs_configured

        db_engine = settings.DATABASES['default']['ENGINE']
        self.stdout.write(f'DB engine: {db_engine}')
        if db_engine.endswith('.sqlite3'):
            raise CommandError('Production check requires PostgreSQL/Supabase. Set DATABASE_URL to the managed database URL.')
        if not settings.SUPABASE_S3_ENABLED:
            raise CommandError('Production check requires Supabase Storage. Set every SUPABASE_S3_* value.')
        if not is_emailjs_configured():
            raise CommandError('Production check requires EmailJS service, template, public key, and private key.')

        with connection.cursor() as cursor:
            cursor.execute('SELECT version()')
            self.stdout.write(f'DB version: {cursor.fetchone()[0].split()[0]}')
            cursor.execute('SHOW ssl')
            self.stdout.write(f'DB SSL: {cursor.fetchone()[0]}')

        executor = MigrationExecutor(connection)
        plan = executor.migration_plan(executor.loader.graph.leaf_nodes())
        self.stdout.write(f'Pending migrations: {len(plan)}')

        from portal.audit import AuditLog
        self.stdout.write(f'AuditLog table ready: {AuditLog._meta.db_table in connection.introspection.table_names()}')
        self._check_storage()

    def _check_storage(self):
        """Write, presign, read, and remove a harmless bucket probe object."""
        import boto3
        import requests
        from botocore.client import Config
        from django.conf import settings
        from django.core.files.base import ContentFile
        from django.core.files.storage import default_storage

        s3 = boto3.client(
            's3', endpoint_url=settings.SUPABASE_S3_ENDPOINT_URL,
            region_name=settings.SUPABASE_S3_REGION,
            aws_access_key_id=settings.SUPABASE_S3_ACCESS_KEY_ID,
            aws_secret_access_key=settings.SUPABASE_S3_SECRET_ACCESS_KEY,
            config=Config(signature_version='s3v4', s3={'addressing_style': 'path'}),
        )
        try:
            s3.head_bucket(Bucket=settings.SUPABASE_S3_BUCKET)
            self.stdout.write(f'Bucket reachable: {settings.SUPABASE_S3_BUCKET}')
            probe = default_storage.save('health/probe.txt', ContentFile(b'portal storage probe'))
            response = requests.get(default_storage.url(probe), timeout=15)
            if response.status_code != 200 or response.content != b'portal storage probe':
                raise CommandError('Presigned storage download returned unexpected content.')
            default_storage.delete(probe)
            self.stdout.write('Storage write/read/presign probe passed.')
        except Exception as error:
            raise CommandError(f'Supabase Storage probe failed: {error}') from error
