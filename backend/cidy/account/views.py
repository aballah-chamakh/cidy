from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from .serializers import UserRegistrationSerializer
from rest_framework_simplejwt.tokens import RefreshToken


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
        "confirm_password": "your_password"
    }
    """
    serializer = UserRegistrationSerializer(data=request.data)
    
    if serializer.is_valid():
        user = serializer.save()
        
        # Generate JWT tokens for the user
        refresh = RefreshToken.for_user(user)

        # Add tokens to the response
        tokens = {
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        }
        # Return success response with user data (excluding password)
        return Response({
            'message': 'User registered successfully',
            'tokens' : tokens
        }, status=status.HTTP_201_CREATED)
    
    # Return validation errors
    return Response({
        'message': 'Registration failed',
        'errors': serializer.errors
    }, status=status.HTTP_400_BAD_REQUEST)
