from django.urls import path
from . import views

urlpatterns = [

    # Teacher endpoints
    path('teachers/', views.get_teachers, name='student_get_teachers'),
    path('teachers/send_request/', views.send_a_student_request, name='student_send_teacher_request'),
    
    # Notification endpoints
    path('notifications/get_unread_notifications_count/', views.get_unread_notifications_count, name='student_get_unread_notifications_count'),
    path('notifications/mark_as_read/', views.mark_notifications_as_read, name='student_mark_notifications_as_read'),
    path('notifications/', views.get_notifications, name='student_get_notifications'),
    path('notifications/new/', views.get_new_notifications, name='student_get_new_notifications'),

    # Subject endpoints
    path('subjects/', views.get_student_subject_list, name='student_get_subject_list'),
    path('subjects/<int:group_enrollment_id>/', views.get_subject_detail, name='student_get_subject_detail'),

    # Account endpoints
    path('account/get_info/', views.get_account_info, name='student_get_account_info'),
    path('account/update_info/', views.update_account_info, name='student_update_account_info'),
    path('account/change_password/', views.change_password, name='student_change_password'),

    # Parent endpoints
    path('parents/', views.get_student_parents, name='student_get_parents'),
]
