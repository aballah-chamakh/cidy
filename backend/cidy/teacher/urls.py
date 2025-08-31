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
    path('groups/<int:group_id>/students/mark_absence/', views.mark_absence, name='mark_absence'),
    path('groups/<int:group_id>/students/unmark_absence/', views.unmark_absence, name='unmark_absence'),
    path('groups/<int:group_id>/students/mark_payment/', views.mark_payment, name='mark_payment'),
    path('groups/<int:group_id>/students/unmark_payment/', views.unmark_payment, name='unmark_payment'),

    # Student endpoints
    path('students/can_create/', views.can_create_student, name='can_create_student'),
    path('students/', views.get_students, name='get_students'),
    path('students/create/', views.create_student, name='create_student'),
    path('students/delete/', views.delete_students, name='delete_students'),
    path('students/<int:student_id>/', views.get_student_details, name='get_student_details'),
    path('students/<int:student_id>/groups/<int:group_id>/mark_attendance/', views.mark_attendance_of_a_student, name='mark_attendance_of_a_student'),
    path('students/<int:student_id>/groups/<int:group_id>/unmark_attendance/', views.unmark_attendance_of_a_student, name='unmark_attendance_of_a_student'),
    path('students/<int:student_id>/groups/<int:group_id>/mark_absence/', views.mark_absence_of_a_student, name='mark_absence_of_a_student'),
    path('students/<int:student_id>/groups/<int:group_id>/unmark_absence/', views.unmark_absence_of_a_student, name='unmark_absence_of_a_student'),
    path('students/<int:student_id>/groups/<int:group_id>/mark_payment/', views.mark_payment_of_a_student, name='mark_payment_of_a_student'),
    path('students/<int:student_id>/groups/<int:group_id>/unmark_payment/', views.unmark_payment_of_a_student, name='unmark_payment_of_a_student'),

    # Prices endpoints
    path('prices/', views.prices_list, name='prices_list'),
    path('prices/add/', views.add_teacher_subject, name='add_teacher_subject'),
    path('prices/edit/<int:teacher_subject_id>/', views.edit_teacher_subject_price, name='edit_teacher_subject_price'),
    path('prices/delete/<int:teacher_subject_id>/', views.delete_level_section_subject, name='delete_level_section_subject'),
]

