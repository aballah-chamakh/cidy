from django.urls import path
from . import views

urlpatterns = [
    path('notifications/get_unread_notifications_count/', views.get_unread_notifications_count, name='student_get_unread_notifications_count'),
    path('notifications/reset_notification_count/', views.reset_notification_count, name='student_reset_notification_count'),
]
