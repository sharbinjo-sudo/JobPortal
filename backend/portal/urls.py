from django.urls import include,path
from rest_framework.routers import DefaultRouter
from .views import RegisterView,MeView,ProfileView,CompanyViewSet,JobViewSet,ApplicationViewSet,AdminUserViewSet,AdminCompanyViewSet,dashboard,recruiter_dashboard
r=DefaultRouter(); r.register('companies',CompanyViewSet,basename='companies'); r.register('jobs',JobViewSet,basename='jobs'); r.register('applications',ApplicationViewSet,basename='applications'); r.register('admin/users',AdminUserViewSet,basename='admin-users'); r.register('admin/companies',AdminCompanyViewSet,basename='admin-companies')
urlpatterns=[path('auth/register/',RegisterView.as_view()),path('auth/me/',MeView.as_view()),path('profiles/me/',ProfileView.as_view()),path('profiles/me/resume/',ProfileView.as_view()),path('admin/dashboard/',dashboard),path('recruiter/dashboard/',recruiter_dashboard),path('',include(r.urls))]
