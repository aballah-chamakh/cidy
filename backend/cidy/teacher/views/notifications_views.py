from datetime import datetime
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from django.http import JsonResponse
from ..models import TeacherNotification,TeacherUnreadNotification
from ..serializers import TeacherNotificationSerializer
from django.core.paginator import Paginator



@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_unread_notifications_count(request):
    teacher = request.user.teacher
    teacher_unread_notifications = TeacherUnreadNotification.objects.get(teacher=teacher)
    return JsonResponse({'unread_count': teacher_unread_notifications.unread_notifications})

# this will be used to mark the notifications as read after leaving the notification screen
# starting from the last notification ID loaded in the screen and going backward 
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_notifications_as_read(request):
    last_notification_id = request.data.get('last_notification_id')

    if not last_notification_id or not isinstance(last_notification_id, int):
        return JsonResponse({'status': 'error', 'message': 'Invalid notification ID'}, status=400)

    teacher = request.user.teacher
    TeacherNotification.objects.filter(
        teacher=teacher,
        id__lte=last_notification_id
    ).update(is_read=True)
    return JsonResponse({'status': 'success'})



@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_notifications(request):
    """Get paginated notifications for the teacher"""
    teacher = request.user.teacher
    
    # Get query parameters
    start_from_notification_id = request.GET.get('start_from_notification_id')
    if not start_from_notification_id or not start_from_notification_id.isdigit():
        return JsonResponse({'status': 'error', 'message': 'Invalid start_from_notification_id'}, status=400)

    page = request.GET.get('page', 1)
    
    # Get notifications, excluding those with IDs >= start_from_notification_id (to avoid duplicates notifications in the screen)
    notifications = TeacherNotification.objects.filter(teacher=teacher
                                                      ).exclude(id__gte=int(start_from_notification_id)
                                                      ).order_by('-id')
        
    # Paginate results
    paginator = Paginator(notifications, 30)
    try:
        paginated_notifications = paginator.page(page)
    except Exception:
        # If page is out of range, deliver last page
        paginated_notifications = paginator.page(paginator.num_pages)
        page = paginator.num_pages

    # Serialize the data
    serializer = TeacherNotificationSerializer(paginated_notifications, many=True)
    
    return JsonResponse({
        'notifications': serializer.data,
        'unread_count': teacher.teacher_unread_notifications.unread_notifications,
        'total_count': paginator.count,
        'total_pages': paginator.num_pages,
        'current_page': int(page)
    })



@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_new_notifications(request):
    """Get new notifications for the teacher"""
    teacher = request.user.teacher
    
    # Get query parameters
    start_from_notification_id = request.GET.get('start_from_notification_id')
    if not start_from_notification_id or not start_from_notification_id.isdigit():
        return JsonResponse({'status': 'error', 'message': 'Invalid start_from_notification_id'}, status=400)


    # Get notifications with IDs >= start_from_notification_id (to avoid duplicates notifications in the screen)
    notifications = TeacherNotification.objects.filter(teacher=teacher, id__gte=int(start_from_notification_id)).order_by('-id')


    # Serialize the data
    serializer = TeacherNotificationSerializer(notifications, many=True)
    
    return JsonResponse({
        'new_notifications': serializer.data,
    })


# this will be used in the case of the user clicked on an action button
# of a notification then he canceled the action 
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_a_notification_as_read(request, notification_id):
    """Mark a single notification as read"""

    teacher = request.user.teacher
    try:
        notification = TeacherNotification.objects.get(id=notification_id, teacher=teacher)
        notification.is_read = True
        notification.save()
        return JsonResponse({'status': 'success'})
    except TeacherNotification.DoesNotExist:
        return JsonResponse({'status': 'error', 'message': 'Notification not found'}, status=404)