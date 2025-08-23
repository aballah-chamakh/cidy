from django.http import JsonResponse
from rest_framework.permissions import IsAuthenticated
from rest_framework.decorators import api_view,permission_classes
from .models import  ParentNotification

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_unread_notifications_count(request):
    parent = request.user.parent
    count = ParentNotification.objects.filter(parent=parent, read=False).count()
    return JsonResponse({'unread_count': count})

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def reset_notification_count(request):
    # last notification to mark as read 
    last_notification_id = request.data.get('last_notification_id')
    parent = request.user.parent
    ParentNotification.objects.filter(
        parent=parent,
        id__lte=last_notification_id
    ).update(is_read=True)
    return JsonResponse({'status': 'success'})
