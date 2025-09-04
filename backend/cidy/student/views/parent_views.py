


from django.http import JsonResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from parent.models import Parent
from ..serializers import ParentListSerializer

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_student_parents(request):
    student = request.user.student
    parents = Parent.objects.filter(son__student=student).distinct()
    serializer = ParentListSerializer(parents, many=True)
    return JsonResponse({'parents': serializer.data}, status=200)


