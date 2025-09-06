from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from teacher.models import GroupEnrollment,TeacherNotification
from parent.models import ParentNotification
from common.tools import increment_parent_unread_notifications,increment_teacher_unread_notifications
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

    return Response({
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
        return Response({'error': 'Subject not found'}, status=404)

    serializer = StudentSubjectDetailSerializer(group_enrollment)

    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def leave_subject_group(request, group_enrollment_id):
    """
    API view to leave a specific subject group for the student .
    """
    student = request.user.student
    try:
        group_enrollment = GroupEnrollment.objects.get(id=group_enrollment_id, student=student)
    except GroupEnrollment.DoesNotExist:
        return Response({'error': 'Subject not found'}, status=404)

    if group_enrollment.unpaid_amount == 0:
        group_enrollment.delete()
        group = group_enrollment.group
        teacher_student_pronoun = "l'étudiante" if student.gender == 'F' else "l'étudiant"
        TeacherNotification.objects.create(
            teacher=group.teacher,
            image=student.image,
            message=f"{teacher_student_pronoun} {student.user.username} de {student.level}{' '+student.section if student.section else ''} a quitté le groupe {group.name} de matière {group.teacher_subject.subject.name}.",
            meta_data={'student_id': student.id})
        increment_teacher_unread_notifications(group.teacher)
        
        parent_student_pronoun = "Votre fils" if student.gender == 'M' else "Votre fille"
        for son in student.sons.all():
            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=f"{parent_student_pronoun} {son.fullname} a quitté le groupe de matière {group.teacher_subject.subject.name}.",
                meta_data={'son_id': son.id}
            )
            increment_parent_unread_notifications(son.parent)

        return Response({'message': 'Successfully left the subject group'}, status=200)
    else:
        return Response({'error': 'GROUP_FEES_NOT_SETTLED'}, status=400)

