from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from .views import register_user, get_levels_and_sections, MyTokenObtainPairView

urlpatterns = [

    path('register/', register_user, name='register_user'),
    path('token/', MyTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('levels_and_sections/', get_levels_and_sections, name='levels_and_sections'),
]