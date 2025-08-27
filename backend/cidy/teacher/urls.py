from django.urls import path
from . import views


urlpatterns = [
    # Notifications endpoints
    path('notifications/get_unread_notifications_count/', views.get_unread_notifications_count, name='teacher_get_unread_notifications_count'),
    path('notifications/reset_notification_count/', views.reset_notification_count, name='teacher_reset_notification_count'),
    
    # Dasboard enpoints
    path('get_dashboard_data/', views.get_dashboard_data, name='teacher_get_dashboard_data'),
    
    # Week schedule endpoints
    path('week_schedule/', views.get_week_schedule, name='teacher_week_schedule'),
    path('update_group_schedule/<int:group_id>/', views.update_group_schedule, name='update_group_schedule'),
    
    # Group endpoints
    path('can_create_group/', views.can_create_group, name='can_create_group'),
    path('groups/', views.get_groups, name='get_groups'),
    path('groups/create/', views.create_group, name='create_group'),
    path('groups/delete/', views.delete_groups, name='delete_groups'),
    path('groups/<int:group_id>/', views.get_group_details, name='get_group_details'),
    path('groups/<int:group_id>/edit/', views.edit_group, name='edit_group'),
    path('groups/<int:group_id>/students/', views.get_group_students, name='group_students'),
    path('groups/<int:group_id>/students/create/', views.create_group_student, name='create_group_student'),
    path('groups/<int:group_id>/students/add/', views.add_students_to_group, name='add_students_to_group'),
    path('groups/<int:group_id>/students/mark_attendance/', views.mark_attendance, name='mark_attendance'),
    path('groups/<int:group_id>/students/unmark_attendance/', views.unmark_attendance, name='unmark_attendance'),
    path('groups/<int:group_id>/students/mark_payment/', views.mark_payment, name='mark_payment'),
    path('groups/<int:group_id>/students/unmark_payment/', views.unmark_payment, name='unmark_payment'),

    # Student endpoints
    path('students/can_create/', views.can_create_student, name='can_create_student'),
    

]

