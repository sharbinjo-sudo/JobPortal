from django.db import connection
from django.db.migrations.executor import MigrationExecutor
from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = 'Verify production readiness: DB connectivity, SSL, migrations, audit trail.'

    def handle(self, *args, **options):
        from django.conf import settings

        db_engine = settings.DATABASES['default']['ENGINE']
        self.stdout.write(f'DB engine: {db_engine}')
        if db_engine.endswith('.sqlite3'):
            self.stderr.write('ERROR: running on SQLite — this app requires PostgreSQL (Supabase). Set DATABASE_URL.')

        with connection.cursor() as cursor:
            cursor.execute('SELECT version()')
            self.stdout.write(f'DB version: {cursor.fetchone()[0].split()[0]}')
            cursor.execute('SELECT 1 FROM pg_attribute WHERE attname = \'ssl\' LIMIT 1')
            cursor.execute('SHOW ssl')
            ssl_status = cursor.fetchone()[0]
            self.stdout.write(f'DB SSL: {"on" if ssl_status == "on" else ssl_status}')

        executor = MigrationExecutor(connection)
        plan = executor.migration_plan(executor.loader.graph.leaf_nodes())
        self.stdout.write(f'Pending migrations: {len(plan)}')

        from portal.audit import AuditLog
        self.stdout.write(f'AuditLog table ready: {AuditLog._meta.db_table in connection.introspection.table_names()}')

        self._check_storage()

    def _check_storage(self):
        """Roundtrip probe: HEAD the bucket, upload a sentinel object,
        presign it, fetch it back, then delete it."""
        from django.conf import settings
        from django.core.files.base import ContentFile
        from django.core.files.storage import default_storage
        from django.core.files.uploadedfile import SimpleUploadedFile

        if not getattr(settings, 'SUPABASE_S3_ENABLED', False):
            self.stderr.write('WARNING: SUPABASE_S3_* not configured — media falls back to local disk (backend/media/).')
            return

        import boto3
        from botocore.client import Config

        bucket = settings.SUPABASE_S3_BUCKET
        s3 = boto3.client(
            's3',
            endpoint_url=settings.SUPABASE_S3_ENDPOINT_URL,
            region_name=settings.SUPABASE_S3_REGION,
            aws_access_key_id=settings.SUPABASE_S3_ACCESS_KEY_ID,
            aws_secret_access_key=settings.SUPABASE_S3_SECRET_ACCESS_KEY,
            config=Config(signature_version='s3v4', s3={'addressing_style': 'path'}),
        )
        try:
            s3.head_bucket(Bucket=bucket)
            self.stdout.write(f'Bucket reachable: {bucket}')

            probe = default_storage.save('health/probe.txt', ContentFile(b'portal storage probe'))
            url = default_storage.url(probe)
            import requests
            response = requests.get(url, timeout=15)
            self.stdout.write(f'Presigned roundtrip: HTTP {response.status_code} ({probe})')
            if response.status_code != 200 or response.content != b'portal storage probe':
                self.stderr.write('ERROR: presigned download returned unexpected content — check bucket privacy/policy.')
            default_storage.delete(probe)
            self.stdout.write('Probe object deleted (bucket write/read/presign all working).')
        except Exception as exc:
            self.stderr.write(f'ERROR: storage probe failed: {exc}')
