from django.shortcuts import render, get_object_or_404
from django.http import JsonResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from .models import StudentNotification


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_unread_notifications_count(request):
    student = request.user.student
    count = StudentNotification.objects.filter(student=student, is_read=False).count()
    return JsonResponse({'unread_count': count})

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def reset_notification_count(request):
    last_notification_id = request.data.get('last_notification_id')
    student = request.user.student
    StudentNotification.objects.filter(
        student=student,
        id__lte=last_notification_id
    ).update(is_read=True)
    return JsonResponse({'status': 'success'})
