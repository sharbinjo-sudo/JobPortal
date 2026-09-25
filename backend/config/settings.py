import os
from pathlib import Path
try:
    import dj_database_url
except ImportError:
    dj_database_url = None
BASE_DIR = Path(__file__).resolve().parent.parent
env_file = BASE_DIR / '.env'
if env_file.exists():
    for line in env_file.read_text().splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            key, value = line.split('=', 1); os.environ.setdefault(key.strip(), value.strip())
SECRET_KEY = os.getenv('DJANGO_SECRET_KEY', 'dev-only-local-prototype-secret-key-change-me')
DEBUG = os.getenv('DJANGO_DEBUG', 'true').lower() == 'true'
if not DEBUG and SECRET_KEY.startswith('dev-only-'):
    raise RuntimeError('DJANGO_SECRET_KEY must be set when DJANGO_DEBUG=false')
ALLOWED_HOSTS = [x.strip() for x in os.getenv('DJANGO_ALLOWED_HOSTS', 'localhost,127.0.0.1').split(',') if x.strip()]
INSTALLED_APPS = ['django.contrib.admin','django.contrib.auth','django.contrib.contenttypes','django.contrib.sessions','django.contrib.messages','django.contrib.staticfiles','corsheaders','rest_framework','django_filters','drf_spectacular','portal']
MIDDLEWARE = ['corsheaders.middleware.CorsMiddleware','django.middleware.security.SecurityMiddleware','whitenoise.middleware.WhiteNoiseMiddleware','django.contrib.sessions.middleware.SessionMiddleware','django.middleware.common.CommonMiddleware','django.middleware.csrf.CsrfViewMiddleware','django.contrib.auth.middleware.AuthenticationMiddleware','django.contrib.messages.middleware.MessageMiddleware','django.middleware.clickjacking.XFrameOptionsMiddleware']
ROOT_URLCONF = 'config.urls'
TEMPLATES = [{'BACKEND':'django.template.backends.django.DjangoTemplates','DIRS':[],'APP_DIRS':True,'OPTIONS':{'context_processors':['django.template.context_processors.request','django.contrib.auth.context_processors.auth','django.contrib.messages.context_processors.messages']}}]
WSGI_APPLICATION = 'config.wsgi.application'
DATABASES = {'default': dj_database_url.config(default=f'sqlite:///{BASE_DIR / "db.sqlite3"}', conn_max_age=600) if dj_database_url else {'ENGINE':'django.db.backends.sqlite3','NAME':BASE_DIR / 'db.sqlite3'}}
AUTH_USER_MODEL = 'portal.User'
AUTH_PASSWORD_VALIDATORS = [{'NAME':'django.contrib.auth.password_validation.MinimumLengthValidator'}]
LANGUAGE_CODE='en-us'; TIME_ZONE='UTC'; USE_I18N=True; USE_TZ=True
STATIC_URL='static/'; STATIC_ROOT=BASE_DIR / 'staticfiles'; DEFAULT_AUTO_FIELD='django.db.models.BigAutoField'
CORS_ALLOWED_ORIGINS = [x.strip() for x in os.getenv('CORS_ALLOWED_ORIGINS','http://localhost:8080').split(',') if x.strip()]
CORS_ALLOW_ALL_ORIGINS = DEBUG
CSRF_TRUSTED_ORIGINS = [x.strip() for x in os.getenv('CSRF_TRUSTED_ORIGINS','').split(',') if x.strip()]
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
REST_FRAMEWORK = {'DEFAULT_AUTHENTICATION_CLASSES':('rest_framework_simplejwt.authentication.JWTAuthentication',),'DEFAULT_PERMISSION_CLASSES':('rest_framework.permissions.IsAuthenticatedOrReadOnly',),'DEFAULT_FILTER_BACKENDS':('django_filters.rest_framework.DjangoFilterBackend','rest_framework.filters.SearchFilter','rest_framework.filters.OrderingFilter'),'DEFAULT_PAGINATION_CLASS':'config.api.StandardPagination','DEFAULT_SCHEMA_CLASS':'drf_spectacular.openapi.AutoSchema','EXCEPTION_HANDLER':'config.api.api_exception_handler','DEFAULT_THROTTLE_CLASSES':('rest_framework.throttling.AnonRateThrottle','rest_framework.throttling.UserRateThrottle'),'DEFAULT_THROTTLE_RATES':{'anon':'100/hour','user':'1000/hour'}}
SIMPLE_JWT = {'ACCESS_TOKEN_LIFETIME': __import__('datetime').timedelta(minutes=15), 'REFRESH_TOKEN_LIFETIME': __import__('datetime').timedelta(days=7), 'ROTATE_REFRESH_TOKENS': True, 'BLACKLIST_AFTER_ROTATION': False}
SPECTACULAR_SETTINGS={'TITLE':'Job Portal API','VERSION':'1.0.0','SERVE_INCLUDE_SCHEMA':False}
