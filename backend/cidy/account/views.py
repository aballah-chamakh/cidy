from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from rest_framework_simplejwt.views import TokenObtainPairView
from .serializers import UserRegistrationSerializer
from rest_framework_simplejwt.tokens import AccessToken
from teacher.models import Level
from .serializers import LevelsSerializer, MyAccessTokenSerializer


@api_view(['POST'])
def register_user(request):
    """
    Register a new user.
    
    Expected payload:
    {
        "profile_type": "teacher",  # or "student", "parent"
        "fullname": "John Doe",
        "email": "user@example.com",
        "phone_number": "12345678",
        "gender": "M",
        "password": "your_password",
    }
    """

    print(request.data)
    serializer = UserRegistrationSerializer(data=request.data)
    
    if serializer.is_valid():
        user = serializer.save()
        
        # Generate JWT tokens for the user
        token = AccessToken.for_user(user)

        if hasattr(user, 'student'):
            profile_type = 'student'
        elif hasattr(user, 'teacher'):
            profile_type = 'teacher'
        else:
            profile_type = 'parent'

        profile = getattr(user, profile_type)

        # Return success response with user data (excluding password)
        return Response({
            'message': 'User registered successfully',
            'token' : str(token),
            'user': {
                'email' : user.email,
                'fullname': profile.fullname,
                'image_url': profile.image.url,
                'profile_type': profile_type
            }
        }, status=status.HTTP_200_OK)
    
    # Return validation errors
    print(serializer.errors)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
def get_levels(request):
    levels = Level.objects.all()
    serializer = LevelsSerializer(levels, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)



class MyAccessTokenView(TokenObtainPairView):
    serializer_class = MyAccessTokenSerializer