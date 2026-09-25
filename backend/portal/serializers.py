from django.contrib.auth import authenticate
from django.db import transaction
from rest_framework import serializers
from .models import User,SeekerProfile,Company,Job,Application,ApplicationHistory

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model=User
        fields=['id','email','first_name','last_name','phone','role','is_active','date_joined']
        read_only_fields=['id','role','is_active','date_joined']
class RegisterSerializer(serializers.ModelSerializer):
    password=serializers.CharField(write_only=True,min_length=8)
    class Meta: model=User; fields=['email','password','first_name','last_name','phone','role']
    def create(self, data):
        if data.get('role')==User.Roles.ADMIN: raise serializers.ValidationError({'role':'Admin accounts are created by operators.'})
        user=User.objects.create_user(**data); SeekerProfile.objects.get_or_create(user=user); return user
class ProfileSerializer(serializers.ModelSerializer):
    user=UserSerializer(read_only=True)
    class Meta: model=SeekerProfile; fields='__all__'
class CompanySerializer(serializers.ModelSerializer):
    owner=UserSerializer(read_only=True)
    class Meta: model=Company; fields='__all__'
    def validate_name(self,value):
        if not value.strip(): raise serializers.ValidationError('Company name is required.')
        return value.strip()
class JobSerializer(serializers.ModelSerializer):
    company_name=serializers.CharField(source='company.name',read_only=True)
    recruiter=UserSerializer(read_only=True)
    is_open=serializers.BooleanField(read_only=True)
    class Meta:
        model=Job
        fields='__all__'
        read_only_fields=['recruiter','created_at','updated_at']
    def validate(self,attrs):
        low,high=attrs.get('salary_min'),attrs.get('salary_max')
        if low is not None and high is not None and low>high: raise serializers.ValidationError({'salary_max':'Salary maximum must be at least the minimum.'})
        if attrs.get('experience_min',0)<0: raise serializers.ValidationError({'experience_min':'Experience cannot be negative.'})
        return attrs
class HistorySerializer(serializers.ModelSerializer):
    changed_by=UserSerializer(read_only=True)
    class Meta: model=ApplicationHistory; fields='__all__'
class ApplicationSerializer(serializers.ModelSerializer):
    applicant=UserSerializer(read_only=True); job_title=serializers.CharField(source='job.title',read_only=True); history=HistorySerializer(many=True,read_only=True)
    class Meta: model=Application; fields='__all__'
