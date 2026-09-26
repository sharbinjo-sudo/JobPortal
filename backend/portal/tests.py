from django.urls import reverse
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from unittest.mock import Mock, patch
from .audit import AuditLog
from .models import *
class PortalTests(APITestCase):
    def setUp(self):
        self.recruiter=User.objects.create_user(email='r@test.com',password='StrongPass123!',role='RECRUITER',first_name='R',last_name='R'); self.seeker=User.objects.create_user(email='s@test.com',password='StrongPass123!',role='JOB_SEEKER',first_name='S',last_name='S'); self.company=Company.objects.create(owner=self.recruiter,name='Test Co'); self.job=Job.objects.create(recruiter=self.recruiter,company=self.company,title='Engineer',description='Build things',location='Remote',skills=['Python'])
    def auth(self,user): self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {RefreshToken.for_user(user).access_token}')
    def test_register_rejects_admin(self): self.assertEqual(self.client.post('/api/auth/register/',{'email':'a@x.com','password':'StrongPass123!','first_name':'A','last_name':'A','role':'ADMIN'}).status_code,400)
    def test_duplicate_application_is_blocked(self): self.auth(self.seeker); self.seeker.seeker_profile.resume_url='https://example.com/r.pdf'; self.seeker.seeker_profile.save(); first=self.client.post(f'/api/applications/apply/{self.job.id}/',{}); second=self.client.post(f'/api/applications/apply/{self.job.id}/',{}); self.assertEqual(first.status_code,200); self.assertEqual(second.status_code,409)
    def test_recruiter_owns_jobs(self): self.auth(self.recruiter); self.assertEqual(self.client.get('/api/jobs/').status_code,200)
    def test_user_cannot_promote_their_own_role(self):
        self.auth(self.seeker)
        response=self.client.patch('/api/auth/me/',{'role':'ADMIN'},format='json')
        self.assertEqual(response.status_code,200)
        self.seeker.refresh_from_db()
        self.assertEqual(self.seeker.role,User.Roles.SEEKER)
    def test_job_list_uses_standard_pagination_shape(self):
        response=self.client.get('/api/jobs/')
        self.assertEqual(response.status_code,200)
        self.assertTrue(response.data['success'])
        self.assertIn('data',response.data)
        self.assertIn('meta',response.data)
    def test_recruiter_dashboard_is_role_protected(self):
        self.auth(self.seeker)
        self.assertEqual(self.client.get('/api/recruiter/dashboard/').status_code,403)
        self.auth(self.recruiter)
        response=self.client.get('/api/recruiter/dashboard/')
        self.assertEqual(response.status_code,200)
        self.assertIn('active_jobs',response.data['data'])
    def test_admin_users_are_protected(self):
        self.auth(self.seeker)
        self.assertEqual(self.client.get('/api/admin/users/').status_code,403)
        admin=User.objects.create_user(email='admin@test.com',password='StrongPass123!',role='ADMIN',first_name='A',last_name='D')
        self.auth(admin)
        self.assertEqual(self.client.get('/api/admin/users/').status_code,200)
    def test_resume_upload_accepts_pdf_and_enables_application(self):
        self.auth(self.seeker)
        resume=SimpleUploadedFile('resume.pdf',b'%PDF-1.4 local resume',content_type='application/pdf')
        upload=self.client.post('/api/profiles/me/resume/',{'resume':resume},format='multipart')
        self.assertEqual(upload.status_code,200)
        self.assertTrue(upload.data['data']['resume_file_url'])
        self.assertEqual(self.client.post(f'/api/applications/apply/{self.job.id}/',{}).status_code,200)
    def test_resume_upload_rejects_invalid_file_type(self):
        self.auth(self.seeker)
        resume=SimpleUploadedFile('resume.txt',b'not a resume',content_type='text/plain')
        self.assertEqual(self.client.post('/api/profiles/me/resume/',{'resume':resume},format='multipart').status_code,400)
    def test_recruiter_can_upload_company_logo(self):
        self.auth(self.recruiter)
        logo=SimpleUploadedFile('logo.png',b'png bytes',content_type='image/png')
        response=self.client.post(f'/api/companies/{self.company.id}/logo/',{'logo':logo},format='multipart')
        self.assertEqual(response.status_code,200)
        self.assertTrue(response.data['data']['logo_file_url'])
    def test_job_filters_narrow_results(self):
        Job.objects.create(recruiter=self.recruiter,company=self.company,title='Django Dev',description='Python work',location='Bengaluru',skills=['Django'],experience_min=3,employment_type=Job.Employment.CONTRACT)
        self.assertEqual(len(self.client.get('/api/jobs/',{'skill':'Django'}).data['data']),1)
        self.assertEqual(len(self.client.get('/api/jobs/',{'location':'bengaluru'}).data['data']),1)
        self.assertEqual(len(self.client.get('/api/jobs/',{'min_experience':2}).data['data']),1)
        self.assertEqual(len(self.client.get('/api/jobs/',{'employment_type':'CONTRACT'}).data['data']),1)

    @override_settings(EMAILJS_SERVICE_ID='service', EMAILJS_TEMPLATE_ID='template', EMAILJS_PUBLIC_KEY='public', EMAILJS_PRIVATE_KEY='private')
    @patch('portal.emailing.requests.post')
    def test_registration_requests_welcome_email(self, post):
        post.return_value=Mock(status_code=200,text='OK')
        response=self.client.post('/api/auth/register/',{'email':'new@test.com','password':'StrongPass123!','first_name':'New','last_name':'Member','role':'JOB_SEEKER'},format='json')
        self.assertEqual(response.status_code,201)
        payload=post.call_args.kwargs['json']
        self.assertEqual(payload['template_params']['to_email'],'new@test.com')
        self.assertEqual(payload['template_params']['user_name'],'New Member')
        self.assertTrue(AuditLog.objects.filter(action=AuditLog.Action.WELCOME_EMAIL_SENT).exists())


class AuditTrailTests(APITestCase):
    def setUp(self):
        self.recruiter=User.objects.create_user(email='r@test.com',password='StrongPass123!',role='RECRUITER',first_name='R',last_name='R'); self.seeker=User.objects.create_user(email='s@test.com',password='StrongPass123!',role='JOB_SEEKER',first_name='S',last_name='S'); self.company=Company.objects.create(owner=self.recruiter,name='Test Co'); self.job=Job.objects.create(recruiter=self.recruiter,company=self.company,title='Engineer',description='Build things',location='Remote',skills=['Python'])
    def auth(self,user): self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {RefreshToken.for_user(user).access_token}')
    def test_login_success_and_failure_are_audited(self):
        self.client.post('/api/auth/login/',{'email':'s@test.com','password':'WrongPass1!'},format='json')
        self.client.post('/api/auth/login/',{'email':'s@test.com','password':'StrongPass123!'},format='json')
        actions=list(AuditLog.objects.order_by('id').values_list('action',flat=True))
        self.assertIn(AuditLog.Action.LOGIN_FAILED,actions)
        self.assertIn(AuditLog.Action.LOGIN,actions)
    def test_login_failure_never_leaks_account_existence(self):
        response=self.client.post('/api/auth/login/',{'email':'nobody@test.com','password':'WrongPass1!'},format='json')
        self.assertEqual(response.status_code,401)
        self.assertFalse(AuditLog.objects.filter(action=AuditLog.Action.LOGIN).exists())
    def test_application_submission_is_audited(self):
        self.auth(self.seeker)
        self.seeker.seeker_profile.resume_url='https://example.com/r.pdf'; self.seeker.seeker_profile.save()
        self.client.post(f'/api/applications/apply/{self.job.id}/',{})
        entry=AuditLog.objects.get(action=AuditLog.Action.APPLICATION_SUBMITTED)
        self.assertEqual(entry.metadata['job_id'],self.job.id)
        self.assertEqual(entry.actor,self.seeker)
    def test_job_lifecycle_is_audited(self):
        self.auth(self.recruiter)
        create=self.client.post('/api/jobs/',{'company':self.company.id,'title':'Senior Dev','description':'Lead things','location':'Remote','skills':['Django']},format='json')
        self.assertEqual(create.status_code,201)
        job_id=create.data['id']
        self.client.post(f'/api/jobs/{job_id}/close/')
        actions=list(AuditLog.objects.order_by('id').values_list('action',flat=True))
        self.assertIn(AuditLog.Action.JOB_CREATED,actions)
        self.assertIn(AuditLog.Action.JOB_CLOSED,actions)
    def test_status_change_is_audited_with_old_and_new(self):
        self.seeker.seeker_profile.resume_url='https://example.com/r.pdf'; self.seeker.seeker_profile.save()
        self.auth(self.seeker); self.client.post(f'/api/applications/apply/{self.job.id}/',{})
        app=Application.objects.get(job=self.job,applicant=self.seeker)
        self.auth(self.recruiter)
        self.client.patch(f'/api/applications/{app.id}/status/',{'status':'SHORTLISTED'},format='json')
        entry=AuditLog.objects.get(action=AuditLog.Action.APPLICATION_STATUS_CHANGED)
        self.assertEqual(entry.metadata['old_status'],'APPLIED')
        self.assertEqual(entry.metadata['new_status'],'SHORTLISTED')
    def test_requests_carry_request_id_header(self):
        self.auth(self.seeker)
        response=self.client.get('/api/auth/me/')
        self.assertTrue(response['X-Request-ID'])
        entry=AuditLog.objects.filter(action=AuditLog.Action.LOGIN).first()
        self.assertIsNotNone(entry) if entry else None
        self.assertEqual(len(self.client.get('/api/jobs/',{'skill':'Django','min_experience':9}).data['data']),0)
    def test_recruiter_updates_application_status_and_history_is_kept(self):
        self.seeker.seeker_profile.resume_url='https://example.com/r.pdf'; self.seeker.seeker_profile.save()
        self.auth(self.seeker); self.client.post(f'/api/applications/apply/{self.job.id}/',{})
        app=Application.objects.get(job=self.job,applicant=self.seeker)
        self.auth(self.recruiter)
        for new_status in ['SHORTLISTED','INTERVIEW','SELECTED']:
            response=self.client.patch(f'/api/applications/{app.id}/status/',{'status':new_status,'note':'moving along'},format='json')
            self.assertEqual(response.status_code,200)
            self.assertEqual(response.data['data']['status'],new_status)
        app.refresh_from_db()
        self.assertEqual(app.history.count(),4)
    def test_status_change_rejects_unknown_status(self):
        self.seeker.seeker_profile.resume_url='https://example.com/r.pdf'; self.seeker.seeker_profile.save()
        self.auth(self.seeker); self.client.post(f'/api/applications/apply/{self.job.id}/',{})
        app=Application.objects.get(job=self.job,applicant=self.seeker)
        self.auth(self.recruiter)
        self.assertEqual(self.client.patch(f'/api/applications/{app.id}/status/',{'status':'NOPE'},format='json').status_code,400)
    def test_seeker_cannot_change_application_status(self):
        self.seeker.seeker_profile.resume_url='https://example.com/r.pdf'; self.seeker.seeker_profile.save()
        self.auth(self.seeker); self.client.post(f'/api/applications/apply/{self.job.id}/',{})
        app=Application.objects.get(job=self.job,applicant=self.seeker)
        self.assertEqual(self.client.patch(f'/api/applications/{app.id}/status/',{'status':'SELECTED'},format='json').status_code,403)
    def test_admin_can_deactivate_and_reactivate_user(self):
        admin=User.objects.create_user(email='admin@test.com',password='StrongPass123!',role='ADMIN',first_name='A',last_name='D')
        self.auth(admin)
        response=self.client.patch(f'/api/admin/users/{self.seeker.id}/',{'is_active':False},format='json')
        self.assertEqual(response.status_code,200)
        self.seeker.refresh_from_db(); self.assertFalse(self.seeker.is_active)
        self.client.patch(f'/api/admin/users/{self.seeker.id}/',{'is_active':True},format='json')
        self.seeker.refresh_from_db(); self.assertTrue(self.seeker.is_active)
    def test_admin_companies_management(self):
        admin=User.objects.create_user(email='admin@test.com',password='StrongPass123!',role='ADMIN',first_name='A',last_name='D')
        self.auth(self.seeker)
        self.assertEqual(self.client.get('/api/admin/companies/').status_code,403)
        self.auth(admin)
        response=self.client.get('/api/admin/companies/')
        self.assertEqual(response.status_code,200)
        self.assertEqual(response.data['data'][0]['name'],'Test Co')
        detail=self.client.patch(f'/api/admin/companies/{self.company.id}/',{'is_active':False},format='json')
        self.assertEqual(detail.status_code,200)
    def test_admin_dashboard_includes_reports(self):
        admin=User.objects.create_user(email='admin@test.com',password='StrongPass123!',role='ADMIN',first_name='A',last_name='D')
        self.auth(admin)
        response=self.client.get('/api/admin/dashboard/')
        data=response.data['data']
        self.assertIn('by_status',data); self.assertIn('top_jobs',data); self.assertIn('closed_jobs',data); self.assertIn('recent_applications',data)
    def test_recruiter_cannot_edit_another_recruiters_job(self):
        other=User.objects.create_user(email='r2@test.com',password='StrongPass123!',role='RECRUITER',first_name='R',last_name='2')
        self.auth(other)
        response=self.client.patch(f'/api/jobs/{self.job.id}/',{'title':'Hijack'},format='json')
        self.assertIn(response.status_code,[403,404])
    def test_application_carries_resume_link(self):
        self.seeker.seeker_profile.resume_url='https://example.com/r.pdf'; self.seeker.seeker_profile.save()
        self.auth(self.seeker); self.client.post(f'/api/applications/apply/{self.job.id}/',{})
        self.auth(self.recruiter)
        response=self.client.get('/api/applications/')
        self.assertEqual(response.data['data'][0]['resume_url'],'https://example.com/r.pdf')
    def test_job_salary_serializes_as_number_not_string(self):
        self.job.salary_min=5000000; self.job.salary_max=8000000; self.job.save()
        response=self.client.get('/api/jobs/')
        job=response.data['data'][0]
        self.assertIsInstance(job['salary_min'],(int,float),f'salary_min must be a JSON number, got {type(job["salary_min"])}')
        self.assertIsInstance(job['salary_max'],(int,float))
    def test_health_endpoint_reports_database(self):
        response=self.client.get('/api/health/')
        self.assertEqual(response.status_code,200)
        self.assertEqual(response.json()['status'],'ok')
        self.assertEqual(response.json()['database'],'connected')
