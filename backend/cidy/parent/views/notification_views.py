from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.core.paginator import Paginator
from ..models import ParentNotification,ParentUnreadNotification
from ..serializers import ParentNotificationSerializer

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_unread_notifications_count(request):
    parent = request.user.parent
    parent_unread_notifications = ParentUnreadNotification.objects.get(parent=parent)
    return Response({'unread_count': parent_unread_notifications.unread_notifications})

# this will be used to mark the notifications as read after leaving the notification screen
# starting from the last notification ID loaded in the screen and going backward 
@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def mark_notifications_as_read(request):
    last_notification_id = request.data.get('last_notification_id')

    if not last_notification_id or not isinstance(last_notification_id, int):
        return Response({'status': 'error', 'message': 'Invalid notification ID'}, status=400)

    parent = request.user.parent
    ParentNotification.objects.filter(
        parent=parent,
        id__lte=last_notification_id
    ).update(is_read=True)
    return Response({'status': 'success'})



@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_notifications(request):
    """Get paginated notifications for the parent"""
    parent = request.user.parent
    
    # Get query parameters
    start_from_notification_id = request.GET.get('start_from_notification_id')
    if not start_from_notification_id or not start_from_notification_id.isdigit():
        return Response({'status': 'error', 'message': 'Invalid start_from_notification_id'}, status=400)

    page = request.GET.get('page', 1)
    
    # Get notifications, excluding those with IDs >= start_from_notification_id (to avoid duplicates notifications in the screen while paginating)
    notifications = ParentNotification.objects.filter(parent=parent
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
    serializer = ParentNotificationSerializer(paginated_notifications, many=True)
    
    return Response({
        'notifications': serializer.data,
        'unread_count': parent.parentunreadnotifications.unread_notifications,
        'total_count': paginator.count,
        'total_pages': paginator.num_pages,
        'current_page': int(page)
    })



@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_new_notifications(request):
    """Get new notifications for the parent"""
    parent = request.user.parent
    
    # Get query parameters
    start_from_notification_id = request.GET.get('start_from_notification_id')
    if not start_from_notification_id or not start_from_notification_id.isdigit():
        return Response({'status': 'error', 'message': 'Invalid start_from_notification_id'}, status=400)


    # Get notifications with IDs >= start_from_notification_id (to avoid duplicates notifications in the screen)
    notifications = ParentNotification.objects.filter(parent=parent, id__gte=int(start_from_notification_id)).order_by('-id')


    # Serialize the data
    serializer = ParentNotificationSerializer(notifications, many=True)
    
    return Response({
        'new_notifications': serializer.data,
    })
