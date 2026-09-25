"""File storage for media (resumes, company logos).

SupabaseMediaStorage stores objects in a private Supabase Storage bucket
through the S3-compatible gateway using django-storages + boto3. Objects
are never public: every download URL is a short-lived SigV4 presigned
link, so a leaked resume URL stops working after the expiry window.

When SUPABASE_S3_* env vars are absent (local dev, tests), settings.py
falls back to django.core.files.storage.FileSystemStorage under
backend/media/ and this class is never instantiated.
"""
from django.conf import settings
from storages.backends.s3boto3 import S3Boto3Storage


class SupabaseMediaStorage(S3Boto3Storage):
    """Private Supabase bucket over the S3 gateway with presigned reads."""

    bucket_name = settings.SUPABASE_S3_BUCKET
    access_key = settings.SUPABASE_S3_ACCESS_KEY_ID
    secret_key = settings.SUPABASE_S3_SECRET_ACCESS_KEY
    endpoint_url = settings.SUPABASE_S3_ENDPOINT_URL
    region_name = settings.SUPABASE_S3_REGION

    # The gateway exposes buckets as URL path segments, not subdomains.
    addressing_style = 'path'
    signature_version = 's3v4'

    # Objects inherit the bucket's private policy; downloads are served via
    # expiring presigned links instead of public URLs. (The Supabase S3
    # gateway does not support per-object ACLs, so none are sent.)
    querystring_auth = True
    querystring_expire = settings.SUPABASE_S3_URL_EXPIRE

    # Match the local-disk behaviour: a new upload never silently replaces
    # an existing object (Django appends a random suffix on collision).
    file_overwrite = False


# ---------------------------------------------------------------------------
# URL helpers shared by views and serializers
# ---------------------------------------------------------------------------

def durable_media_url(request, file) -> str:
    """Persistable reference for an uploaded file: the object URL with any
    presigned querystring stripped, made absolute. Safe to store — it never
    expires — but private buckets only honour it after re-signing (see
    resign_media_url)."""
    if not file:
        return ''
    url = str(file.url)
    if '?' in url:
        url = url.split('?', 1)[0]
    return request.build_absolute_uri(url) if request is not None else url


def _s3_key_from_url(url: str) -> str | None:
    """Return the object key when url points inside the configured bucket."""
    endpoint_path = ''
    if settings.SUPABASE_S3_ENDPOINT_URL:
        from urllib.parse import urlsplit
        endpoint_path = urlsplit(settings.SUPABASE_S3_ENDPOINT_URL).path.rstrip('/')
    prefix = f'{endpoint_path}/{settings.SUPABASE_S3_BUCKET}/'
    from urllib.parse import urlsplit
    path = urlsplit(url).path
    if settings.SUPABASE_S3_BUCKET and path.startswith(prefix):
        return path[len(prefix):]
    return None


def resign_media_url(request, url: str) -> str:
    """Return a working link for a stored object URL.

    Presigned links expire, so stored URLs are re-signed on every response.
    URLs outside our storage (external links, demo data) pass through
    untouched. Local-media URLs keep working as-is.
    """
    if not url:
        return ''
    from django.core.files.storage import default_storage

    key = _s3_key_from_url(url) if getattr(settings, 'SUPABASE_S3_ENABLED', False) else None
    if key is not None:
        fresh = default_storage.url(key)  # freshly presigned
    else:
        from urllib.parse import urlsplit
        media_path = settings.MEDIA_URL
        if not urlsplit(url).path.startswith(media_path):
            return url  # external URL — serve unchanged
        fresh = url  # local media URL is already durable
    return request.build_absolute_uri(fresh) if request is not None else fresh
