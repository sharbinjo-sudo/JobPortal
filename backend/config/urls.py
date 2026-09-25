from django.contrib import admin
from django.conf import settings
from django.conf.urls.static import static
from django.http import JsonResponse
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView
from rest_framework_simplejwt.views import TokenRefreshView
from portal.views import LoginView

def health(request):
    from portal.audit import db_logger

    db_ok = _database_ok()
    db_backend = settings.DATABASES['default']['ENGINE'].rsplit('.', 1)[-1]
    db_logger.info(
        'health_check',
        extra={'event': 'health_check', 'db': db_backend, 'status_code': 200 if db_ok else 503},
    )
    return JsonResponse({'status': 'ok' if db_ok else 'degraded', 'database': 'connected' if db_ok else 'unavailable'}, status=200 if db_ok else 503)

def _database_ok():
    from django.db import connection
    try:
        with connection.cursor() as cursor:
            cursor.execute('SELECT 1')
        return True
    except Exception:
        return False

urlpatterns=[path('admin/',admin.site.urls),path('api/health/',health),path('api/auth/login/',LoginView.as_view()),path('api/auth/token/refresh/',TokenRefreshView.as_view()),path('api/',include('portal.urls')),path('api/schema/',SpectacularAPIView.as_view(),name='schema'),path('api/docs/',SpectacularSwaggerView.as_view(url_name='schema'))]
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
