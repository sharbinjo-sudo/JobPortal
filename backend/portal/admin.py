from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin

from .audit import AuditLog
from .models import Application, ApplicationHistory, Company, Job, SeekerProfile, User


class SeekerProfileInline(admin.StackedInline):
    model = SeekerProfile
    can_delete = False
    verbose_name_plural = 'Seeker profile'


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    ordering = ('-date_joined',)
    list_display = ('email', 'first_name', 'last_name', 'role', 'is_active', 'date_joined')
    list_filter = ('role', 'is_active')
    search_fields = ('email', 'first_name', 'last_name')
    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Personal info', {'fields': ('first_name', 'last_name', 'phone')}),
        ('Permissions', {'fields': ('role', 'is_active', 'is_staff', 'is_superuser')}),
        ('Important dates', {'fields': ('last_login', 'date_joined')}),
    )
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'password1', 'password2', 'role', 'first_name', 'last_name'),
        }),
    )
    inlines = (SeekerProfileInline,)


class JobInline(admin.TabularInline):
    model = Job
    extra = 0
    fields = ('title', 'status', 'employment_type', 'work_mode', 'location')
    show_change_link = True


@admin.register(Company)
class CompanyAdmin(admin.ModelAdmin):
    list_display = ('name', 'owner', 'industry', 'location', 'is_active', 'created_at')
    list_filter = ('is_active', 'industry')
    search_fields = ('name', 'owner__email')
    inlines = (JobInline,)


@admin.register(Job)
class JobAdmin(admin.ModelAdmin):
    list_display = ('title', 'company', 'recruiter', 'status', 'employment_type', 'work_mode', 'created_at')
    list_filter = ('status', 'employment_type', 'work_mode')
    search_fields = ('title', 'company__name', 'location')
    date_hierarchy = 'created_at'


class ApplicationHistoryInline(admin.TabularInline):
    model = ApplicationHistory
    extra = 0
    readonly_fields = ('old_status', 'new_status', 'changed_by', 'note', 'created_at')
    can_delete = False


@admin.register(Application)
class ApplicationAdmin(admin.ModelAdmin):
    list_display = ('job', 'applicant', 'status', 'applied_at', 'updated_at')
    list_filter = ('status',)
    search_fields = ('job__title', 'applicant__email')
    readonly_fields = ('applied_at', 'updated_at')
    inlines = (ApplicationHistoryInline,)


@admin.register(ApplicationHistory)
class ApplicationHistoryAdmin(admin.ModelAdmin):
    list_display = ('application', 'old_status', 'new_status', 'changed_by', 'created_at')
    list_filter = ('new_status',)
    search_fields = ('application__job__title',)


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    """Read-only audit trail in the Django admin (tamper-evident by convention)."""
    list_display = ('created_at', 'actor', 'action', 'object_type', 'object_id', 'ip', 'request_id')
    list_filter = ('action',)
    search_fields = ('actor__email', 'object_id', 'request_id')
    date_hierarchy = 'created_at'
    readonly_fields = [f.name for f in AuditLog._meta.get_fields()]

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
