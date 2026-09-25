from django.core.management.base import BaseCommand
from portal.models import *
class Command(BaseCommand):
    help='Create safe local demo data.'
    def handle(self,*args,**kwargs):
        admin,_=User.objects.get_or_create(email='admin@example.com',defaults={'first_name':'System','last_name':'Admin','role':'ADMIN','is_staff':True,'is_superuser':True}); admin.set_password('AdminDemo123!'); admin.save()
        rec,_=User.objects.get_or_create(email='recruiter@example.com',defaults={'first_name':'Riya','last_name':'Shah','role':'RECRUITER'}); rec.set_password('RecruiterDemo123!'); rec.save()
        seeker,_=User.objects.get_or_create(email='seeker@example.com',defaults={'first_name':'Aarav','last_name':'Mehta','role':'JOB_SEEKER'}); seeker.set_password('SeekerDemo123!'); seeker.save()
        company,_=Company.objects.get_or_create(owner=rec,name='Northstar Labs',defaults={'description':'Product engineering and data teams.','industry':'Technology','location':'Bengaluru'})
        Job.objects.get_or_create(recruiter=rec,company=company,title='Senior Python Engineer',defaults={'description':'Build reliable services with Django and PostgreSQL.','location':'Bengaluru / Remote','skills':['Python','Django','PostgreSQL'],'experience_min':4,'employment_type':'FULL_TIME','work_mode':'HYBRID'})
        self.stdout.write(self.style.SUCCESS('Demo data ready: admin@example.com / AdminDemo123!, recruiter@example.com / RecruiterDemo123!, seeker@example.com / SeekerDemo123!'))
