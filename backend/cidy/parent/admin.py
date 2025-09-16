from django.contrib import admin
from .models import Parent,Son,ParentUnreadNotification,ParentNotification

admin.site.register(Parent)
admin.site.register(Son)
admin.site.register(ParentUnreadNotification)
admin.site.register(ParentNotification)
