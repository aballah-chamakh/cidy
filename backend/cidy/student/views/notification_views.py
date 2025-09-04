from django.http import JsonResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from django.core.paginator import Paginator
from ..models import StudentNotification,StudentUnreadNotification
from ..serializers import StudentNotificationSerializer

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_unread_notifications_count(request):
    student = request.user.student
    student_unread_notifications = StudentUnreadNotification.objects.get(student=student)
    return JsonResponse({'unread_count': student_unread_notifications.unread_notifications})

# this will be used to mark the notifications as read after leaving the notification screen
# starting from the last notification ID loaded in the screen and going backward 
@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def mark_notifications_as_read(request):
    last_notification_id = request.data.get('last_notification_id')

    if not last_notification_id or not isinstance(last_notification_id, int):
        return JsonResponse({'status': 'error', 'message': 'Invalid notification ID'}, status=400)

    student = request.user.student
    StudentNotification.objects.filter(
        student=student,
        id__lte=last_notification_id
    ).update(is_read=True)
    return JsonResponse({'status': 'success'})



@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_notifications(request):
    """Get paginated notifications for the student"""
    student = request.user.student
    
    # Get query parameters
    start_from_notification_id = request.GET.get('start_from_notification_id')
    if not start_from_notification_id or not start_from_notification_id.isdigit():
        return JsonResponse({'status': 'error', 'message': 'Invalid start_from_notification_id'}, status=400)

    page = request.GET.get('page', 1)
    
    # Get notifications, excluding those with IDs >= start_from_notification_id (to avoid duplicates notifications in the screen while paginating)
    notifications = StudentNotification.objects.filter(student=student
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
    serializer = StudentNotificationSerializer(paginated_notifications, many=True)
    
    return JsonResponse({
        'notifications': serializer.data,
        'unread_count': student.student_unread_notifications.unread_notifications,
        'total_count': paginator.count,
        'total_pages': paginator.num_pages,
        'current_page': int(page)
    })



@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_new_notifications(request):
    """Get new notifications for the student"""
    student = request.user.student
    
    # Get query parameters
    start_from_notification_id = request.GET.get('start_from_notification_id')
    if not start_from_notification_id or not start_from_notification_id.isdigit():
        return JsonResponse({'status': 'error', 'message': 'Invalid start_from_notification_id'}, status=400)


    # Get notifications with IDs >= start_from_notification_id (to avoid duplicates notifications in the screen)
    notifications = StudentNotification.objects.filter(student=student, id__gte=int(start_from_notification_id)).order_by('-id')


    # Serialize the data
    serializer = StudentNotificationSerializer(notifications, many=True)
    
    return JsonResponse({
        'new_notifications': serializer.data,
    })
