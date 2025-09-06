from django.urls import path
from . import views

urlpatterns = [
    # teacher endpoints
    path('teachers/get_tes_levels_sections_subjects', views.get_tes_levels_sections_subjects, name='parent_get_tes_levels_sections_subjects'),
    path('teachers/get_teachers', views.get_teachers, name='parent_get_teachers'),
    path('teachers/parenting_request_form_data/<int:teacher_id>', views.parenting_request_form_data, name='parent_parenting_request_form_data'),
    path('teachers/send_parenting_request/<int:teacher_id>', views.send_parenting_request, name='parent_send_parenting_request'),
]
