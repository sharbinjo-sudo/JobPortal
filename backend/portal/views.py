from django.db import transaction
from django.db.models import Count, Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status,viewsets
from rest_framework.decorators import action,api_view,permission_classes
from rest_framework.permissions import AllowAny,IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework.views import APIView
from .models import *
from .audit import record_audit
from .filters import JobFilter
from .uploads import validate_logo, validate_resume
from .permissions import IsAdmin,IsRecruiter,IsSeeker
from .serializers import *
from config.storage import durable_media_url

def envelope(data=None,message='OK',success=True,status_code=200,**kwargs): return Response({'success':success,'message':message,'data':data,**kwargs},status=status_code)
class LoginView(APIView):
    """JWT login with success/failure auditing."""
    permission_classes=[AllowAny]
    def post(self,request):
        from django.contrib.auth import authenticate
        email=request.data.get('email',''); password=request.data.get('password','')
        user=authenticate(request,email=email,password=password)
        if user is None:
            record_audit(request, action='LOGIN_FAILED', metadata={'email':email[:120]})
            return Response({'success':False,'message':'No active account found with the given credentials.'},status=401)
        if not user.is_active:
            record_audit(request, action='LOGIN_FAILED', metadata={'email':email[:120],'deactivated':True})
            return Response({'success':False,'message':'This account has been deactivated.'},status=403)
        record_audit(request, action='LOGIN', obj=user)
        refresh=RefreshToken.for_user(user)
        return envelope({'access':str(refresh.access_token),'refresh':str(refresh),'user':UserSerializer(user).data},'Login successful.')
class RegisterView(APIView):
    permission_classes=[AllowAny]
    def post(self,request):
        s=RegisterSerializer(data=request.data); s.is_valid(raise_exception=True); u=s.save(); record_audit(request, action='REGISTER', obj=u); return envelope(UserSerializer(u).data,'Registration successful.',True,status_code=status.HTTP_201_CREATED)
class MeView(APIView):
    def get(self,request): return envelope(UserSerializer(request.user).data)
    def patch(self,request):
        s=UserSerializer(request.user,data=request.data,partial=True); s.is_valid(raise_exception=True); s.save(); return envelope(s.data,'Profile updated.')
class ProfileView(APIView):
    permission_classes=[IsSeeker]
    def get(self,request):
        profile,_=SeekerProfile.objects.get_or_create(user=request.user); return envelope(ProfileSerializer(profile,context={'request':request}).data)
    def patch(self,request):
        profile,_=SeekerProfile.objects.get_or_create(user=request.user); s=ProfileSerializer(profile,data=request.data,partial=True,context={'request':request}); s.is_valid(raise_exception=True); s.save(); return envelope(s.data,'Profile updated.')
    def post(self,request):
        profile,_=SeekerProfile.objects.get_or_create(user=request.user)
        upload=request.FILES.get('resume')
        if not upload: return Response({'success':False,'message':'Attach a resume file using the resume field.'},status=400)
        validate_resume(upload)
        profile.resume_file=upload
        # Persist the file before deriving its durable URL — storage backends
        # may not expose a final URL until the upload has landed.
        profile.save(update_fields=['resume_file','updated_at'])
        profile.resume_url=durable_media_url(request,profile.resume_file)
        profile.save(update_fields=['resume_url','updated_at'])
        record_audit(request, action='RESUME_UPLOADED', obj=profile.user)
        return envelope(ProfileSerializer(profile,context={'request':request}).data,'Resume uploaded successfully.')
class CompanyViewSet(viewsets.ModelViewSet):
    serializer_class=CompanySerializer; permission_classes=[IsRecruiter]
    def get_queryset(self):
        base=Company.objects.annotate(open_jobs=Count('jobs',filter=Q(jobs__status=Job.Status.OPEN)),job_count=Count('jobs'))
        return base if getattr(self.request.user,'role',None)==User.Roles.ADMIN else base.filter(owner=self.request.user)
    def perform_create(self,serializer): serializer.save(owner=self.request.user)
    @action(detail=True,methods=['post'],permission_classes=[IsRecruiter])
    def logo(self,request,pk=None):
        company=self.get_object()
        upload=request.FILES.get('logo')
        if not upload: return Response({'success':False,'message':'Attach an image using the logo field.'},status=400)
        validate_logo(upload)
        company.logo_file=upload
        company.save(update_fields=['logo_file'])
        company.logo_url=durable_media_url(request,company.logo_file)
        company.save(update_fields=['logo_url'])
        record_audit(request, action='LOGO_UPLOADED', obj=company)
        return envelope(CompanySerializer(company,context={'request':request}).data,'Company logo uploaded successfully.')

class AdminUserViewSet(viewsets.ModelViewSet):
    serializer_class=AdminUserSerializer
    permission_classes=[IsAdmin]
    queryset=User.objects.annotate(application_count=Count('applications')).order_by('-date_joined')
    http_method_names=['get','patch','head','options']
class JobViewSet(viewsets.ModelViewSet):
    serializer_class=JobSerializer; filterset_class=JobFilter; search_fields=['title','location','description']; ordering_fields=['created_at','salary_min','salary_max','title']; permission_classes=[AllowAny]
    def get_queryset(self):
        qs=Job.objects.select_related('company','recruiter')
        if self.request.user.is_authenticated and self.request.user.role==User.Roles.RECRUITER: return qs.filter(recruiter=self.request.user)
        if self.request.user.is_authenticated and self.request.user.role==User.Roles.ADMIN: return qs
        return qs.filter(status=Job.Status.OPEN)
    def get_permissions(self): return [IsRecruiter()] if self.action in ['create','update','partial_update','destroy','close'] else [AllowAny()]
    def perform_create(self,serializer):
        company=get_object_or_404(Company,pk=self.request.data.get('company'),owner=self.request.user); job=serializer.save(recruiter=self.request.user,company=company); record_audit(self.request, action='JOB_CREATED', obj=job, metadata={'title':job.title})
    def perform_update(self,serializer):
        if serializer.instance.recruiter!=self.request.user and self.request.user.role!=User.Roles.ADMIN: from rest_framework.exceptions import PermissionDenied; raise PermissionDenied()
        job=serializer.save(); record_audit(self.request, action='JOB_UPDATED', obj=job, metadata={'title':job.title})
    @action(detail=True,methods=['post'])
    def close(self,request,pk=None):
        job=self.get_object(); job.status=Job.Status.CLOSED; job.save(update_fields=['status','updated_at']); record_audit(request, action='JOB_CLOSED', obj=job); return envelope(JobSerializer(job).data,'Job closed.')
class ApplicationViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class=ApplicationSerializer; permission_classes=[IsAuthenticated]; queryset=Application.objects.all()
    def get_queryset(self):
        u=self.request.user; qs=Application.objects.select_related('job','job__company','applicant').prefetch_related('history').order_by('-applied_at')
        if getattr(u,'role',None)==User.Roles.ADMIN:return qs
        if getattr(u,'role',None)==User.Roles.RECRUITER:return qs.filter(job__recruiter=u)
        return qs.filter(applicant=u)
    @action(detail=False,methods=['post'],url_path='apply/(?P<job_id>[^/.]+)',permission_classes=[IsSeeker])
    def apply(self,request,job_id=None):
        job=get_object_or_404(Job,pk=job_id)
        if not job.is_open:return Response({'success':False,'message':'This job is closed or expired.'},status=400)
        if Application.objects.filter(job=job,applicant=request.user).exists(): return Response({'success':False,'message':'You already applied to this job.'},status=409)
        profile,created=SeekerProfile.objects.get_or_create(user=request.user)
        if not profile.resume_url and not profile.resume_file:return Response({'success':False,'message':'Upload a resume before applying.'},status=400)
        try:
            with transaction.atomic():
                resume_url=profile.resume_url or durable_media_url(request,profile.resume_file)
                app=Application.objects.create(job=job,applicant=request.user,resume_url=resume_url,cover_letter=request.data.get('cover_letter',''))
                ApplicationHistory.objects.create(application=app,new_status=app.status,changed_by=request.user)
                record_audit(request, action='APPLICATION_SUBMITTED', obj=app, metadata={'job_id':job.id,'job_title':job.title})
        except Exception as exc:
            if 'unique_job_applicant' in str(exc): return Response({'success':False,'message':'You already applied to this job.'},status=409)
            raise
        return envelope(ApplicationSerializer(app).data,'Application submitted.',True)
    @action(detail=True,methods=['patch'],permission_classes=[IsRecruiter])
    def status(self,request,pk=None):
        app=self.get_object(); new=request.data.get('status')
        if new not in Application.Status.values:return Response({'success':False,'message':'Invalid status.'},status=400)
        old=app.status; app.status=new; app.save(); ApplicationHistory.objects.create(application=app,old_status=old,new_status=new,changed_by=request.user,note=request.data.get('note','')); record_audit(request, action='APPLICATION_STATUS_CHANGED', obj=app, metadata={'old_status':old,'new_status':new}); return envelope(ApplicationSerializer(app).data,'Application status updated.')
class AdminCompanyViewSet(viewsets.ModelViewSet):
    serializer_class=CompanySerializer
    permission_classes=[IsAdmin]
    queryset=Company.objects.annotate(open_jobs=Count('jobs', filter=Q(jobs__status=Job.Status.OPEN)), job_count=Count('jobs')).order_by('-created_at')

@api_view(['GET'])
@permission_classes([IsAdmin])
def dashboard(request):
    return envelope({'users':User.objects.count(),'seekers':User.objects.filter(role=User.Roles.SEEKER).count(),'recruiters':User.objects.filter(role=User.Roles.RECRUITER).count(),'companies':Company.objects.count(),'open_jobs':Job.objects.filter(status=Job.Status.OPEN).count(),'closed_jobs':Job.objects.filter(status=Job.Status.CLOSED).count(),'applications':Application.objects.count(),'selected':Application.objects.filter(status=Application.Status.SELECTED).count(),'rejected':Application.objects.filter(status=Application.Status.REJECTED).count(),'by_status':list(Application.objects.values('status').annotate(count=Count('id'))),'top_jobs':list(Application.objects.values('job__title','job__company__name').annotate(count=Count('id')).order_by('-count')[:5]),'recent_applications':ApplicationSerializer(Application.objects.select_related('job','job__company','applicant').order_by('-applied_at')[:5],many=True).data})

@api_view(['GET'])
@permission_classes([IsRecruiter])
def recruiter_dashboard(request):
    jobs = Job.objects.filter(recruiter=request.user)
    applications = Application.objects.filter(job__recruiter=request.user)
    return envelope({
        'active_jobs': jobs.filter(status=Job.Status.OPEN).count(),
        'total_jobs': jobs.count(),
        'applications': applications.count(),
        'shortlisted': applications.filter(status=Application.Status.SHORTLISTED).count(),
        'interviews': applications.filter(status=Application.Status.INTERVIEW).count(),
        'selected': applications.filter(status=Application.Status.SELECTED).count(),
        'recent_applications': ApplicationSerializer(applications.select_related('job', 'applicant').order_by('-applied_at')[:5], many=True).data,
    })
