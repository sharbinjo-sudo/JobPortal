from rest_framework.permissions import BasePermission
from .models import User
class IsAdmin(BasePermission):
    def has_permission(self, request, view): return bool(request.user.is_authenticated and request.user.role==User.Roles.ADMIN)
class IsRecruiter(BasePermission):
    def has_permission(self, request, view): return bool(request.user.is_authenticated and request.user.role in [User.Roles.RECRUITER,User.Roles.ADMIN])
class IsSeeker(BasePermission):
    def has_permission(self, request, view): return bool(request.user.is_authenticated and request.user.role==User.Roles.SEEKER)
