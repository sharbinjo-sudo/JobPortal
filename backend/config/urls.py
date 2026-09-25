from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
urlpatterns=[path('admin/',admin.site.urls),path('api/auth/login/',TokenObtainPairView.as_view()),path('api/auth/token/refresh/',TokenRefreshView.as_view()),path('api/',include('portal.urls')),path('api/schema/',SpectacularAPIView.as_view()),path('api/docs/',SpectacularSwaggerView.as_view(url_name='schema'))]
