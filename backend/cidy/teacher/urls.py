from django.urls import path
from . import views

urlpatterns = [
    path('notifications/get_unread_notifications_count/', views.get_unread_notifications_count, name='teacher_get_unread_notifications_count'),
    path('notifications/reset_notification_count/', views.reset_notification_count, name='teacher_reset_notification_count'),
    path('get_dashboard_data/', views.get_dashboard_data, name='teacher_get_dashboard_data'),
    
    # Week schedule endpoints
    path('week_schedule/', views.get_week_schedule, name='teacher_week_schedule'),
    path('update_group_schedule/<int:group_id>/', views.update_group_schedule, name='update_group_schedule'),
]

