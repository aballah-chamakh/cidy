from django.contrib import admin
from .models import (Level,Section,Subject,Teacher,
                     TeacherSubject,TeacherEnrollment,Group,
                     GroupEnrollment,Class,TeacherUnreadNotification,
                     TeacherNotification)
# Register your models here.

admin.site.register(Level)
admin.site.register(Section)
admin.site.register(Subject)
admin.site.register(Teacher)
admin.site.register(TeacherSubject)
admin.site.register(TeacherEnrollment)
admin.site.register(Group)
admin.site.register(GroupEnrollment)
admin.site.register(Class)
admin.site.register(TeacherUnreadNotification)
admin.site.register(TeacherNotification)
