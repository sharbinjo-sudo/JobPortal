from django.contrib.auth import authenticate
from django.db import transaction
from rest_framework import serializers
from .models import User,SeekerProfile,Company,Job,Application,ApplicationHistory
from config.storage import resign_media_url


def file_download_url(request, file) -> str:
    """Fresh, working download URL for a stored file.

    Stored resume_url/logo_url snapshots are re-signed per response because
    presigned links expire; local media URLs pass through unchanged.
    """
    if not file:
        return ''
    return resign_media_url(request, str(file.url))

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model=User
        fields=['id','email','first_name','last_name','phone','role','is_active','date_joined']
        read_only_fields=['id','role','is_active','date_joined']
class AdminUserSerializer(serializers.ModelSerializer):
    application_count=serializers.IntegerField(read_only=True)
    class Meta:
        model=User
        fields=['id','email','first_name','last_name','phone','role','is_active','date_joined','application_count']
        read_only_fields=['id','role','date_joined','application_count']
class RegisterSerializer(serializers.ModelSerializer):
    password=serializers.CharField(write_only=True,min_length=8)
    class Meta: model=User; fields=['email','password','first_name','last_name','phone','role']
    def create(self, data):
        if data.get('role')==User.Roles.ADMIN: raise serializers.ValidationError({'role':'Admin accounts are created by operators.'})
        user=User.objects.create_user(**data); SeekerProfile.objects.get_or_create(user=user); return user
class ProfileSerializer(serializers.ModelSerializer):
    user=UserSerializer(read_only=True)
    resume_file_url=serializers.SerializerMethodField()
    class Meta: model=SeekerProfile; fields='__all__'; read_only_fields=['resume_file']
    def get_resume_file_url(self, obj):
        return file_download_url(self.context.get('request'), obj.resume_file)
class CompanySerializer(serializers.ModelSerializer):
    owner=UserSerializer(read_only=True); logo_file_url=serializers.SerializerMethodField(); open_jobs=serializers.IntegerField(read_only=True); job_count=serializers.IntegerField(read_only=True)
    class Meta: model=Company; fields='__all__'; read_only_fields=['owner','logo_file']
    def get_logo_file_url(self, obj):
        return file_download_url(self.context.get('request'), obj.logo_file)
    def validate_name(self,value):
        if not value.strip(): raise serializers.ValidationError('Company name is required.')
        return value.strip()
class JobSerializer(serializers.ModelSerializer):
    company_name=serializers.CharField(source='company.name',read_only=True)
    recruiter=UserSerializer(read_only=True)
    is_open=serializers.BooleanField(read_only=True)
    salary_min=serializers.SerializerMethodField()
    salary_max=serializers.SerializerMethodField()
    class Meta:
        model=Job
        fields='__all__'
        read_only_fields=['recruiter','created_at','updated_at']
    def get_salary_min(self,obj): return None if obj.salary_min is None else float(obj.salary_min)
    def get_salary_max(self,obj): return None if obj.salary_max is None else float(obj.salary_max)
    def validate(self,attrs):
        low,high=attrs.get('salary_min'),attrs.get('salary_max')
        if low is not None and high is not None and low>high: raise serializers.ValidationError({'salary_max':'Salary maximum must be at least the minimum.'})
        if attrs.get('experience_min',0)<0: raise serializers.ValidationError({'experience_min':'Experience cannot be negative.'})
        return attrs
class HistorySerializer(serializers.ModelSerializer):
    changed_by=UserSerializer(read_only=True)
    class Meta: model=ApplicationHistory; fields='__all__'
class ApplicationSerializer(serializers.ModelSerializer):
    applicant=UserSerializer(read_only=True); job_title=serializers.CharField(source='job.title',read_only=True); company_name=serializers.CharField(source='job.company.name',read_only=True); resume_url=serializers.SerializerMethodField(); history=HistorySerializer(many=True,read_only=True)
    class Meta: model=Application; fields='__all__'
    def get_resume_url(self,obj):
        if obj.resume_url: return resign_media_url(self.context.get('request'), obj.resume_url)
        return file_download_url(self.context.get('request'), obj.applicant.seeker_profile.resume_file)
