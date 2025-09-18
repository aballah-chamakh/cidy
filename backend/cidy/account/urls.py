from django.urls import path
from .views import register_user, get_levels_and_sections, MyAccessTokenView

urlpatterns = [

    path('register/', register_user, name='register_user'),
    path('token/', MyAccessTokenView.as_view(), name='access_token'),
    path('levels_and_sections/', get_levels_and_sections, name='levels_and_sections'),
]