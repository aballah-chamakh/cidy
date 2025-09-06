from django.urls import path
from . import views

urlpatterns = [
    # teacher endpoints
    path('teachers/get_tes_levels_sections_subjects', views.get_tes_levels_sections_subjects, name='parent_get_tes_levels_sections_subjects'),
    path('teachers/get_teachers', views.get_teachers, name='parent_get_teachers'),
    path('teachers/parenting_request_form_data/<int:teacher_id>', views.parenting_request_form_data, name='parent_parenting_request_form_data'),
    path('teachers/send_parenting_request/<int:teacher_id>', views.send_parenting_request, name='parent_send_parenting_request'),
    
    # son endpoints
    path('sons/', views.get_parent_sons, name='parent_get_parent_sons'),
    path('sons/<int:son_id>/', views.get_son_detail, name='parent_get_son_detail'),
    path('sons/<int:son_id>/subjects/<int:subject_id>/', views.get_son_subject_detail, name='parent_get_son_subject_detail'),
    path('sons/<int:son_id>/edit/', views.edit_a_son, name='parent_edit_a_son'),
    path('sons/create/', views.create_a_son, name='parent_create_a_son'),

    # notification endpoints
    path('notifications/unread_count/', views.get_unread_notifications_count, name='parent_get_unread_notifications_count'),
    path('notifications/mark_as_read/', views.mark_notifications_as_read, name='parent_mark_notifications_as_read'),
    path('notifications/', views.get_notifications, name='parent_get_notifications'),
    path('notifications/new/', views.get_new_notifications, name='parent_get_new_notifications'),

    # account endpoints
    path('account/info/', views.get_account_info, name='parent_get_account_info'),
    path('account/update/', views.update_account_info, name='parent_update_account_info'),
    path('account/change_password/', views.change_password, name='parent_change_password'),
]

