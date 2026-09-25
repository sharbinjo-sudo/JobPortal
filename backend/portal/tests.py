from django.urls import reverse
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken
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
