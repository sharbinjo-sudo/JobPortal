"""
Django settings for the job portal.

Local development runs fully offline (SQLite, local media, console email).
Production settings are driven entirely by environment variables in
backend/.env — no code changes required.
"""
import os
import sys
from datetime import timedelta
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# ---------------------------------------------------------------------------
# Environment loading
# A tiny dependency-free .env reader; python-dotenv is intentionally not
# required for local setup. Real environment variables always win over .env.
# ---------------------------------------------------------------------------
env_file = BASE_DIR / '.env'
if env_file.exists():
    for line in env_file.read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if line and not line.startswith('#') and '=' in line:
            key, _, value = line.partition('=')
            os.environ.setdefault(key.strip(), value.strip())


def env_list(name: str, default: str) -> list[str]:
    return [item.strip() for item in os.getenv(name, default).split(',') if item.strip()]


def env_bool(name: str, default: str) -> bool:
    return os.getenv(name, default).lower() in ('true', '1', 'yes')


# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------
SECRET_KEY = os.getenv('DJANGO_SECRET_KEY', 'dev-only-local-prototype-secret-key-change-me')
# Test runs (manage.py test) and the Django dev server must never inherit
# prod-only behaviors (SECURE_SSL_REDIRECT, strict CORS) from a production
# .env — SSL redirect answers every http:// request with a 301 that local
# clients cannot follow. Production is always served by gunicorn (see
# Procfile), never by runserver, so forcing DEBUG for manage.py runserver is
# safe and keeps `runserver` usable with a production-shaped .env.
RUNNING_TESTS = 'test' in sys.argv or 'pytest' in sys.argv
RUNNING_DEVSERVER = 'runserver' in sys.argv
DEBUG = env_bool('DJANGO_DEBUG', 'true') or RUNNING_TESTS or RUNNING_DEVSERVER
ALLOWED_HOSTS = env_list('DJANGO_ALLOWED_HOSTS', 'localhost,127.0.0.1')

if not DEBUG and SECRET_KEY.startswith('dev-only-'):
    raise RuntimeError('DJANGO_SECRET_KEY must be set when DJANGO_DEBUG=false')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'corsheaders',
    'rest_framework',
    'django_filters',
    'drf_spectacular',
    'portal',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'portal.middleware.RequestAuditMiddleware',
]

ROOT_URLCONF = 'config.urls'
WSGI_APPLICATION = 'config.wsgi.application'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

# ---------------------------------------------------------------------------
# Database — PostgreSQL (Supabase) only. There is no local SQLite fallback.
# DATABASE_URL is required, e.g.
#   postgres://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres
# Special characters in the password (?, #, @, !, %) must be percent-encoded.
# SSL is always forced for PostgreSQL. Test runs never touch the real DB:
# they use a throwaway SQLite file regardless of what .env contains.
# ---------------------------------------------------------------------------
import dj_database_url

if RUNNING_TESTS:
    DATABASE_URL = f'sqlite:///{BASE_DIR / "test-db.sqlite3"}'
else:
    DATABASE_URL = os.getenv('DATABASE_URL', f'sqlite:///{BASE_DIR / "db.sqlite3"}')

# parse() (not config()) so an inherited DATABASE_URL env var cannot
# silently override the explicit value chosen above.
DATABASES = {
    'default': dj_database_url.parse(
        DATABASE_URL,
        conn_max_age=600,
        ssl_require=DATABASE_URL.startswith('postgres'),
    ),
}

# Fail fast on unreachable databases instead of hanging worker threads.
DATABASES['default'].setdefault('OPTIONS', {})
if DATABASE_URL.startswith('postgres'):
    DATABASES['default']['OPTIONS'].setdefault('connect_timeout', 10)

# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------
AUTH_USER_MODEL = 'portal.User'

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
]

# ---------------------------------------------------------------------------
# Email — console backend by default so registration and notification flows
# can be exercised offline. Emails print to the runserver terminal. Swap
# DJANGO_EMAIL_BACKEND for an SMTP backend when a provider is added later.
# ---------------------------------------------------------------------------
EMAIL_BACKEND = os.getenv(
    'DJANGO_EMAIL_BACKEND',
    'django.core.mail.backends.console.EmailBackend',
)
DEFAULT_FROM_EMAIL = os.getenv('DJANGO_FROM_EMAIL', 'noreply@localhost')

# ---------------------------------------------------------------------------
# EmailJS
# ---------------------------------------------------------------------------
EMAILJS_SERVICE_ID = os.getenv('EMAILJS_SERVICE_ID', '')
EMAILJS_TEMPLATE_ID = os.getenv('EMAILJS_TEMPLATE_ID', '')
EMAILJS_USER_ID = os.getenv('EMAILJS_USER_ID', '')
EMAILJS_ACCESS_TOKEN = os.getenv('EMAILJS_ACCESS_TOKEN', '')

# ---------------------------------------------------------------------------
# i18n
# ---------------------------------------------------------------------------
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# ---------------------------------------------------------------------------
# Static & media — media (resumes, logos) lives in a private Supabase
# Storage bucket over the S3 gateway when SUPABASE_S3_* is configured;
# otherwise it falls back to local disk under backend/media/ (dev/tests).
# ---------------------------------------------------------------------------
STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'
FILE_UPLOAD_MAX_MEMORY_SIZE = 6 * 1024 * 1024
DATA_UPLOAD_MAX_MEMORY_SIZE = 8 * 1024 * 1024

# Supabase Storage (S3-compatible gateway). All four SUPABASE_S3_* values
# must be present to activate the bucket; otherwise local disk is used.
SUPABASE_S3_ENDPOINT_URL = os.getenv('SUPABASE_S3_ENDPOINT_URL', '').strip()
SUPABASE_S3_REGION = os.getenv('SUPABASE_S3_REGION', '').strip()
SUPABASE_S3_BUCKET = os.getenv('SUPABASE_S3_BUCKET', '').strip()
SUPABASE_S3_ACCESS_KEY_ID = os.getenv('SUPABASE_S3_ACCESS_KEY_ID', '').strip()
SUPABASE_S3_SECRET_ACCESS_KEY = os.getenv('SUPABASE_S3_SECRET_ACCESS_KEY', '').strip()
SUPABASE_S3_URL_EXPIRE = int(os.getenv('SUPABASE_S3_URL_EXPIRE', '900'))
SUPABASE_S3_ENABLED = all(
    (SUPABASE_S3_ENDPOINT_URL, SUPABASE_S3_REGION, SUPABASE_S3_BUCKET,
     SUPABASE_S3_ACCESS_KEY_ID, SUPABASE_S3_SECRET_ACCESS_KEY),
)

STORAGES = {
    'default': (
        {'BACKEND': 'config.storage.SupabaseMediaStorage'}
        if SUPABASE_S3_ENABLED and not RUNNING_TESTS
        else {'BACKEND': 'django.core.files.storage.FileSystemStorage'}
    ),
    'staticfiles': {'BACKEND': 'django.contrib.staticfiles.storage.StaticFilesStorage'},
}

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ---------------------------------------------------------------------------
# CORS / CSRF
# ---------------------------------------------------------------------------
CORS_ALLOWED_ORIGINS = env_list(
    'CORS_ALLOWED_ORIGINS',
    'http://localhost:8080,http://127.0.0.1:8080',
)
# Flutter Web selects an available development port at runtime. Keep this
# narrowly scoped to loopback hosts so a locally launched app works whether
# Django is run with DEBUG enabled or production-style environment values.
CORS_ALLOWED_ORIGIN_REGEXES = env_list(
    'CORS_ALLOWED_ORIGIN_REGEXES',
    r'^http://localhost:[0-9]+$,^http://127\.0\.0\.1:[0-9]+$',
)
CORS_ALLOW_ALL_ORIGINS = DEBUG
CSRF_TRUSTED_ORIGINS = env_list('CSRF_TRUSTED_ORIGINS', '')

# ---------------------------------------------------------------------------
# Security hardening (only enforced when running with DEBUG=false)
# ---------------------------------------------------------------------------
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'
SECURE_REFERRER_POLICY = 'same-origin'

if not DEBUG:
    SECURE_SSL_REDIRECT = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = 31536000
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

# ---------------------------------------------------------------------------
# Logging — console JSON lines locally, structured records in production.
# Every request is audited by portal.middleware.RequestAuditMiddleware.
# ---------------------------------------------------------------------------
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'json': {
            '()': 'config.settings.json_log_formatter',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'json',
        },
    },
    'root': {
        'handlers': ['console'],
        'level': os.getenv('DJANGO_LOG_LEVEL', 'INFO'),
    },
    'loggers': {
        'django.server': {'handlers': ['console'], 'level': 'INFO', 'propagate': False},
        'django.request': {'handlers': ['console'], 'level': 'WARNING', 'propagate': False},
        'portal.audit': {'handlers': ['console'], 'level': 'INFO', 'propagate': False},
        'portal.db': {'handlers': ['console'], 'level': 'INFO', 'propagate': False},
    },
}


def json_log_formatter():
    """Emit one JSON object per log line (parseable by most log drains)."""
    import json
    import logging

    class JsonFormatter(logging.Formatter):
        def format(self, record: logging.LogRecord) -> str:
            payload = {
                'ts': self.formatTime(record, '%Y-%m-%dT%H:%M:%S%z'),
                'level': record.levelname,
                'logger': record.name,
                'message': record.getMessage(),
            }
            for key in ('event', 'method', 'path', 'status_code', 'duration_ms',
                        'user_id', 'user_email', 'ip', 'request_id', 'db', 'backend'):
                value = getattr(record, key, None)
                if value is not None:
                    payload[key] = value
            if record.exc_info:
                payload['exc'] = self.formatException(record.exc_info)
            return json.dumps(payload)

    return JsonFormatter()


# ---------------------------------------------------------------------------
# DRF
# ---------------------------------------------------------------------------
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticatedOrReadOnly',
    ),
    'DEFAULT_FILTER_BACKENDS': (
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.SearchFilter',
        'rest_framework.filters.OrderingFilter',
    ),
    'DEFAULT_PAGINATION_CLASS': 'config.api.StandardPagination',
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
    'EXCEPTION_HANDLER': 'config.api.api_exception_handler',
    'DEFAULT_THROTTLE_CLASSES': (
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
    ),
    'DEFAULT_THROTTLE_RATES': {
        'anon': '100/hour',
        'user': '1000/hour',
    },
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=60),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': False,
}

SPECTACULAR_SETTINGS = {
    'TITLE': 'Job Portal API',
    'VERSION': '1.0.0',
    'SERVE_INCLUDE_SCHEMA': False,
}
