from django.contrib.auth.models import AbstractUser, UserManager
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.db import models
from django.utils import timezone

class EmailUserManager(UserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email: raise ValueError('Email is required')
        user=self.model(email=self.normalize_email(email), **extra_fields); user.set_password(password); user.save(using=self._db); return user
    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True); extra_fields.setdefault('is_superuser', True); extra_fields.setdefault('role', 'ADMIN'); return self.create_user(email, password, **extra_fields)

class User(AbstractUser):
    class Roles(models.TextChoices):
        SEEKER='JOB_SEEKER','Job seeker'; RECRUITER='RECRUITER','Recruiter'; ADMIN='ADMIN','Admin'
    username=None; email=models.EmailField(unique=True); role=models.CharField(max_length=20,choices=Roles.choices,default=Roles.SEEKER); phone=models.CharField(max_length=30,blank=True)
    objects=EmailUserManager()
    USERNAME_FIELD='email'; REQUIRED_FIELDS=['first_name','last_name']

class SeekerProfile(models.Model):
    user=models.OneToOneField(User,on_delete=models.CASCADE,related_name='seeker_profile'); headline=models.CharField(max_length=160,blank=True); bio=models.TextField(blank=True); location=models.CharField(max_length=160,blank=True); skills=models.JSONField(default=list,blank=True); education=models.CharField(max_length=255,blank=True); experience_years=models.PositiveIntegerField(default=0); resume_url=models.URLField(blank=True); updated_at=models.DateTimeField(auto_now=True)

class Company(models.Model):
    owner=models.ForeignKey(User,on_delete=models.CASCADE,related_name='companies'); name=models.CharField(max_length=180); description=models.TextField(blank=True); industry=models.CharField(max_length=120,blank=True); website=models.URLField(blank=True); location=models.CharField(max_length=160,blank=True); logo_url=models.URLField(blank=True); is_active=models.BooleanField(default=True); created_at=models.DateTimeField(auto_now_add=True)

class Job(models.Model):
    class Employment(models.TextChoices):
        FULL_TIME='FULL_TIME','Full time'; PART_TIME='PART_TIME','Part time'; CONTRACT='CONTRACT','Contract'; INTERNSHIP='INTERNSHIP','Internship'
    class WorkMode(models.TextChoices):
        REMOTE='REMOTE','Remote'; HYBRID='HYBRID','Hybrid'; ONSITE='ONSITE','On-site'
    class Status(models.TextChoices):
        DRAFT='DRAFT','Draft'; OPEN='OPEN','Open'; CLOSED='CLOSED','Closed'; ARCHIVED='ARCHIVED','Archived'
    company=models.ForeignKey(Company,on_delete=models.PROTECT,related_name='jobs'); recruiter=models.ForeignKey(User,on_delete=models.PROTECT,related_name='jobs'); title=models.CharField(max_length=180); description=models.TextField(); location=models.CharField(max_length=160); salary_min=models.DecimalField(max_digits=12,decimal_places=2,null=True,blank=True); salary_max=models.DecimalField(max_digits=12,decimal_places=2,null=True,blank=True); currency=models.CharField(max_length=5,default='USD'); skills=models.JSONField(default=list); experience_min=models.PositiveIntegerField(default=0); employment_type=models.CharField(max_length=20,choices=Employment.choices,default=Employment.FULL_TIME); work_mode=models.CharField(max_length=20,choices=WorkMode.choices,default=WorkMode.HYBRID); application_deadline=models.DateTimeField(null=True,blank=True); status=models.CharField(max_length=20,choices=Status.choices,default=Status.OPEN); created_at=models.DateTimeField(auto_now_add=True); updated_at=models.DateTimeField(auto_now=True)
    class Meta:
        ordering=['-created_at']; indexes=[models.Index(fields=['status','created_at']),models.Index(fields=['location','employment_type'])]
    @property
    def is_open(self): return self.status==self.Status.OPEN and (not self.application_deadline or self.application_deadline>=timezone.now())

class Application(models.Model):
    class Status(models.TextChoices):
        APPLIED='APPLIED','Applied'; SHORTLISTED='SHORTLISTED','Shortlisted'; INTERVIEW='INTERVIEW','Interview'; SELECTED='SELECTED','Selected'; REJECTED='REJECTED','Rejected'
    job=models.ForeignKey(Job,on_delete=models.PROTECT,related_name='applications'); applicant=models.ForeignKey(User,on_delete=models.PROTECT,related_name='applications'); resume_url=models.URLField(blank=True); cover_letter=models.TextField(blank=True); status=models.CharField(max_length=20,choices=Status.choices,default=Status.APPLIED); applied_at=models.DateTimeField(auto_now_add=True); updated_at=models.DateTimeField(auto_now=True)
    class Meta:
        constraints=[models.UniqueConstraint(fields=['job','applicant'],name='unique_job_applicant')]

class ApplicationHistory(models.Model):
    application=models.ForeignKey(Application,on_delete=models.CASCADE,related_name='history'); old_status=models.CharField(max_length=20,blank=True); new_status=models.CharField(max_length=20); changed_by=models.ForeignKey(User,on_delete=models.PROTECT); note=models.TextField(blank=True); created_at=models.DateTimeField(auto_now_add=True)

@receiver(post_save, sender=User)
def create_seeker_profile(sender, instance, created, **kwargs):
    if created and instance.role == User.Roles.SEEKER:
        SeekerProfile.objects.get_or_create(user=instance)
