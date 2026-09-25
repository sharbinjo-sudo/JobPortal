from django.contrib import admin
from .models import User,SeekerProfile,Company,Job,Application,ApplicationHistory
for model in [User,SeekerProfile,Company,Job,Application,ApplicationHistory]: admin.site.register(model)
