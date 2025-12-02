from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from teacher.serializers import (
    TeacherAccountInfoSerializer,
    UpdateTeacherAccountInfoSerializer,
    ChangeTeacherPasswordSerializer,
)
from django.http import HttpResponseServerError

import time

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_account_info(request):
    #time.sleep(5)  # Simulate network delay
    """Retrieve the account information of the logged-in teacher."""
    teacher = request.user.teacher
    serializer = TeacherAccountInfoSerializer(teacher, context={'request': request})
    print(serializer.data)
    return Response({'teacher_account_data': serializer.data}, status=200)


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def update_account_info(request):
    #time.sleep(5)  # Simulate network delay

    """Update the account information of the logged-in teacher."""
    teacher = request.user.teacher
    serializer = UpdateTeacherAccountInfoSerializer(
        teacher, data=request.data, context={'request': request}
    )
    if serializer.is_valid():
        serializer.save()

        return Response({"message": "Account info updated successfully"}, status=200)
    print(serializer.errors)
    return Response(serializer.errors, status=400)


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def change_password(request):
    #time.sleep(5)
    """Change the password of the logged-in teacher."""
    teacher = request.user.teacher
    serializer = ChangeTeacherPasswordSerializer(
        teacher, data=request.data, context={'request': request}
    )
    if serializer.is_valid():
        serializer.save()
        return Response({"message": "Password changed successfully"}, status=200)
    print(serializer.errors)
    return Response(serializer.errors, status=400)
