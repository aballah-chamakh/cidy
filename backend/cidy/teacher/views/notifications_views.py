from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from django.http import JsonResponse
from ..models import TeacherNotification



@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_unread_notifications_count(request):
    teacher = request.user.teacher
    count = TeacherNotification.objects.filter(teacher=teacher, read=False).count()
    return JsonResponse({'unread_count': count})

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def reset_notification_count(request):
    last_notification_id = request.data.get('last_notification_id')
    teacher = request.user.teacher
    TeacherNotification.objects.filter(
        teacher=teacher,
        id__lte=last_notification_id
    ).update(is_read=True)
    return JsonResponse({'status': 'success'})