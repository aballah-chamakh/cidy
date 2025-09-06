from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from teacher.models import GroupEnrollment
from ..models import Son
from ..serializers import SonSubjectListSerializer,SonListSerializer,SonDetailSerializer,SonSubjectDetailSerializer,SonCreateEditSerializer


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_parent_sons(request):
    """Get all sons of the logged-in parent."""
    parent = request.user.parent
    sons = parent.son_set.all()
    serializer = SonListSerializer(sons, many=True)
    return Response({'sons': serializer.data})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_son_detail(request, son_id):
    """Get details of a specific son."""
    parent = request.user.parent
    try:
        son = parent.son_set.get(id=son_id)
    except Son.DoesNotExist:
        return Response({'error': 'Son not found'}, status=404)

    serializer = SonDetailSerializer(son)
    return Response({'son': serializer.data})

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_son_subject_detail(request, son_id, subject_id):
    """Get details of a specific son's subjects."""
    parent = request.user.parent
    try:
        son = parent.son_set.get(id=son_id)
    except Son.DoesNotExist:
        return Response({'error': 'Son not found'}, status=404)

    try:
        subject = son.student.groupsenrollment_set.get(id=subject_id)
    except GroupEnrollment.DoesNotExist:
        return Response({'error': 'Subject not found'}, status=404)

    serializer = SonSubjectDetailSerializer(subject)
    return Response({'subject': serializer.data})


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def edit_a_son(request, son_id):
    parent = request.user.parent
    try:
        son = parent.son_set.get(id=son_id)
    except Son.DoesNotExist:
        return Response({'error': 'Son not found'}, status=404)

    serializer = SonCreateEditSerializer(son, data=request.data, partial=True)
    if serializer.is_valid():
        son = serializer.save()
        return Response({'son': f'the son {son.fullname} has been updated successfully.'})
    return Response(serializer.errors, status=400)

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def create_a_son(request):
    parent = request.user.parent
    serializer = SonCreateEditSerializer(data=request.data)
    if serializer.is_valid():
        son = serializer.save(parent=parent)
        return Response({'son': f'the son {son.fullname} has been created successfully.'})
    return Response(serializer.errors, status=400)
