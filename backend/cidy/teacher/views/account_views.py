from django.http import JsonResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from teacher.serializers import (
    TeacherAccountInfoSerializer,
    UpdateTeacherAccountInfoSerializer,
    ChangeTeacherPasswordSerializer,
)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_account_info(request):
    """Retrieve the account information of the logged-in teacher."""
    teacher = request.user.teacher
    serializer = TeacherAccountInfoSerializer(teacher, context={'request': request})
    return JsonResponse({'teacher_account_data': serializer.data}, status=200)


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def update_account_info(request):
    """Update the account information of the logged-in teacher."""
    teacher = request.user.teacher
    serializer = UpdateTeacherAccountInfoSerializer(
        teacher, data=request.data, context={'request': request}
    )
    if serializer.is_valid():
        serializer.save()

        return JsonResponse({"message": "Account info updated successfully"}, status=200)
    return JsonResponse({"error": serializer.errors}, status=400)


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def change_password(request):
    """Change the password of the logged-in teacher."""
    teacher = request.user.teacher
    serializer = ChangeTeacherPasswordSerializer(
        teacher, data=request.data, context={'request': request}
    )
    if serializer.is_valid():
        serializer.save()
        return JsonResponse({"message": "Password changed successfully"}, status=200)
    return JsonResponse({"error": serializer.errors}, status=400)
