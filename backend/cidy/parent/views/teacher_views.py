from django.core.paginator import Paginator
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from teacher.models import Level
from ..serializers import TesLevelsSectionsSubjectsSerializer

# this one will be user in the filter of the teacher list
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_tes_levels_sections_subjects(request):
    """Get all of the subjects that the student can study for his level and section."""
   
    levels_qs  = Level.objects.all()
    serializer = TesLevelsSectionsSubjectsSerializer(levels_qs, many=True)

    return Response({'tes': serializer.data})



