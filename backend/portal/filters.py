import django_filters
from .models import Job


class JobFilter(django_filters.FilterSet):
    skill = django_filters.CharFilter(method='filter_skill')
    location = django_filters.CharFilter(lookup_expr='icontains')
    min_experience = django_filters.NumberFilter(field_name='experience_min', lookup_expr='gte')
    max_experience = django_filters.NumberFilter(field_name='experience_min', lookup_expr='lte')
    min_salary = django_filters.NumberFilter(field_name='salary_max', lookup_expr='gte')
    max_salary = django_filters.NumberFilter(field_name='salary_min', lookup_expr='lte')

    class Meta:
        model = Job
        fields = ['employment_type', 'work_mode', 'status', 'company', 'location']

    def filter_skill(self, queryset, name, value):
        return queryset.filter(skills__icontains=value)
