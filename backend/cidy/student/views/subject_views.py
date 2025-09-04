from django.http import JsonResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from teacher.models import GroupEnrollment
from django.db.models import Sum
from ..serializers import StudentSubjectListSerializer,StudentSubjectDetailSerializer

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_student_subject_list(request):
    """
    API view to retrieve the subjects data for the student subjects screen.
    """
    student = request.user.student
    groups_enrolled_in_qs = GroupEnrollment.objects.filter(student=student)
    
    # Calculate total paid and unpaid amounts across all subjects
    total_paid_amount = groups_enrolled_in_qs.aggregate(
        total_paid=Sum('paid_amount')
    )['total_paid'] or 0

    total_unpaid_amount = groups_enrolled_in_qs.aggregate(
        total_unpaid=Sum('unpaid_amount')
    )['total_unpaid'] or 0

    # Get the list of subjects the student is studying
    group_enrollments = groups_enrolled_in_qs.select_related(
        'group', 'group__subject', 'group__teacher'
    )

    serializer = StudentSubjectListSerializer(group_enrollments, many=True)

    return JsonResponse({
        'total_paid_amount': total_paid_amount,
        'total_unpaid_amount': total_unpaid_amount,
        'subjects': serializer.data
    })

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_subject_detail(request, group_enrollment_id):
    """
    API view to retrieve the details of a specific subject for the student subjects screen.
    """
    student = request.user.student
    try:
        group_enrollment = GroupEnrollment.objects.get(id=group_enrollment_id, student=student)
    except GroupEnrollment.DoesNotExist:
        return JsonResponse({'error': 'Subject not found'}, status=404)

    serializer = StudentSubjectDetailSerializer(group_enrollment)

    return JsonResponse(serializer.data)