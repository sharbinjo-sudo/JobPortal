from django.db import transaction
from django.db.models import Count
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status,viewsets
from rest_framework.decorators import action,api_view,permission_classes
from rest_framework.permissions import AllowAny,IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import *
from .filters import JobFilter
from .permissions import IsAdmin,IsRecruiter,IsSeeker
from .serializers import *

def envelope(data=None,message='OK',success=True,status_code=200,**kwargs): return Response({'success':success,'message':message,'data':data,**kwargs},status=status_code)
class RegisterView(APIView):
    permission_classes=[AllowAny]
    def post(self,request):
        s=RegisterSerializer(data=request.data); s.is_valid(raise_exception=True); u=s.save(); return envelope(UserSerializer(u).data,'Registration successful.',True,status_code=status.HTTP_201_CREATED)
class MeView(APIView):
    def get(self,request): return envelope(UserSerializer(request.user).data)
    def patch(self,request):
        s=UserSerializer(request.user,data=request.data,partial=True); s.is_valid(raise_exception=True); s.save(); return envelope(s.data,'Profile updated.')
class ProfileView(APIView):
    permission_classes=[IsSeeker]
    def get(self,request):
        profile,_=SeekerProfile.objects.get_or_create(user=request.user); return envelope(ProfileSerializer(profile).data)
    def patch(self,request):
        profile,_=SeekerProfile.objects.get_or_create(user=request.user); s=ProfileSerializer(profile,data=request.data,partial=True); s.is_valid(raise_exception=True); s.save(); return envelope(s.data,'Profile updated.')
    def post(self,request):
        profile,_=SeekerProfile.objects.get_or_create(user=request.user)
        url=request.data.get('resume_url')
        if not url: return Response({'success':False,'message':'resume_url is required for the local prototype.'},status=400)
        profile.resume_url=url; profile.save(update_fields=['resume_url','updated_at']); return envelope(ProfileSerializer(profile).data,'Resume updated.')
class CompanyViewSet(viewsets.ModelViewSet):
    serializer_class=CompanySerializer; permission_classes=[IsRecruiter]; queryset=Company.objects.all()
    def get_queryset(self): return Company.objects.all() if getattr(self.request.user,'role',None)==User.Roles.ADMIN else Company.objects.filter(owner=self.request.user)
    def perform_create(self,serializer): serializer.save(owner=self.request.user)
class JobViewSet(viewsets.ModelViewSet):
    serializer_class=JobSerializer; filterset_class=JobFilter; search_fields=['title','location','description']; ordering_fields=['created_at','salary_min','salary_max','title']; permission_classes=[AllowAny]
    def get_queryset(self):
        qs=Job.objects.select_related('company','recruiter')
        if self.request.user.is_authenticated and self.request.user.role==User.Roles.RECRUITER: return qs.filter(recruiter=self.request.user)
        if self.request.user.is_authenticated and self.request.user.role==User.Roles.ADMIN: return qs
        return qs.filter(status=Job.Status.OPEN)
    def get_permissions(self): return [IsRecruiter()] if self.action in ['create','update','partial_update','destroy','close'] else [AllowAny()]
    def perform_create(self,serializer):
        company=get_object_or_404(Company,pk=self.request.data.get('company'),owner=self.request.user); serializer.save(recruiter=self.request.user,company=company)
    def perform_update(self,serializer):
        if serializer.instance.recruiter!=self.request.user and self.request.user.role!=User.Roles.ADMIN: from rest_framework.exceptions import PermissionDenied; raise PermissionDenied()
        serializer.save()
    @action(detail=True,methods=['post'])
    def close(self,request,pk=None):
        job=self.get_object(); job.status=Job.Status.CLOSED; job.save(update_fields=['status','updated_at']); return envelope(JobSerializer(job).data,'Job closed.')
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
        if not profile.resume_url:return Response({'success':False,'message':'Upload a resume before applying.'},status=400)
        try:
            with transaction.atomic():
                app=Application.objects.create(job=job,applicant=request.user,resume_url=profile.resume_url,cover_letter=request.data.get('cover_letter',''))
                ApplicationHistory.objects.create(application=app,new_status=app.status,changed_by=request.user)
        except Exception as exc:
            if 'unique_job_applicant' in str(exc): return Response({'success':False,'message':'You already applied to this job.'},status=409)
            raise
        return envelope(ApplicationSerializer(app).data,'Application submitted.',True)
    @action(detail=True,methods=['patch'],permission_classes=[IsRecruiter])
    def status(self,request,pk=None):
        app=self.get_object(); new=request.data.get('status')
        if new not in Application.Status.values:return Response({'success':False,'message':'Invalid status.'},status=400)
        old=app.status; app.status=new; app.save(); ApplicationHistory.objects.create(application=app,old_status=old,new_status=new,changed_by=request.user,note=request.data.get('note','')); return envelope(ApplicationSerializer(app).data,'Application status updated.')
@api_view(['GET'])
@permission_classes([IsAdmin])
def dashboard(request):
    return envelope({'users':User.objects.count(),'seekers':User.objects.filter(role=User.Roles.SEEKER).count(),'recruiters':User.objects.filter(role=User.Roles.RECRUITER).count(),'companies':Company.objects.count(),'open_jobs':Job.objects.filter(status=Job.Status.OPEN).count(),'applications':Application.objects.count(),'selected':Application.objects.filter(status=Application.Status.SELECTED).count(),'rejected':Application.objects.filter(status=Application.Status.REJECTED).count(),'by_status':list(Application.objects.values('status').annotate(count=Count('id')))})

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
