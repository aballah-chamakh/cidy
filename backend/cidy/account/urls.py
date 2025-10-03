from django.urls import path
from .views import register_user, get_levels, MyAccessTokenView

urlpatterns = [

    path('register/', register_user, name='register_user'),
    path('token/', MyAccessTokenView.as_view(), name='access_token'),
    path('levels/', get_levels, name='levels_and_sections'),
]