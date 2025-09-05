from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from ..serializers import (
    StudentAccountInfoSerializer,
    UpdateStudentAccountInfoSerializer,
    ChangeStudentPasswordSerializer,
    IncompatibleGroupsSerializer
)
from rest_framework.response import Response

from teacher.models import GroupEnrollment
from parent.models import ParentNotification
from common.tools import increment_parent_unread_notifications



@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_account_info(request):
    """Retrieve the account information of the logged-in student."""
    student = request.user.student
    serializer = StudentAccountInfoSerializer(student, context={'request': request})
    return Response({'student_account_data': serializer.data}, status=200)



@api_view(['POST'])
@permission_classes([IsAuthenticated])
def get_incompatible_groups_with_the_new_level_and_section(request):
    """Check if the student's level and section are compatible with their groups."""
    student = request.user.student
    new_level_id = request.data.get('level_id',None)
    new_section_id = request.data.get('section_id',None)

    if not new_level_id : 
        return Response({'error': 'Level ID is required.'}, status=400)

    # Check if the new level and section are compatible with the student's groups
    if new_section_id is None:
        incompatible_groups = student.groups.exclude(teacher_subject__level__id=new_level_id, teacher_subject__section__isnull=True)
    else:
        incompatible_groups = student.groups.exclude(teacher_subject__level__id=new_level_id, teacher_subject__section__id=new_section_id)
    
    serializer = IncompatibleGroupsSerializer(incompatible_groups, many=True)
    return Response({'levels_and_sections': serializer.data}, status=200)


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def update_account_info(request):
    """Update the account information of the logged-in student."""
    student = request.user.student
    serializer = UpdateStudentAccountInfoSerializer(
        student, data=request.data, context={'request': request}
    )
    if serializer.is_valid():
        student = serializer.save()

        # if the student had incompatible groups after the update, remove him from these group and inform his parent about that through notifications
        # note : i didn't send a notification to the student because he is aware by this action
        if student.section is None:
            incompatible_groups = student.groups.exclude(teacher_subject__level=student.level, teacher_subject__section__isnull=True)
        else:
            incompatible_groups = student.groups.exclude(teacher_subject__level=student.level, teacher_subject__section=student.section)
        if incompatible_groups.exists():
            subjects = [group.teacher_subject.subject.name for group in incompatible_groups]
            GroupEnrollment.objects.filter(student=student, group__in=incompatible_groups).delete()
            for son in student.sons.all():
                son_pronoun = "Votre fils" if son.gender == "male" else "Votre fille"
                ParentNotification.objects.create(
                    parent=son.parent,
                    image=son.image,
                    meta_data={'son_id': son.id},
                    message=f"{son_pronoun} a quitté le(s) groupe(s) de la/les matière(s) suivante(s) : {subjects}"
                )
                increment_parent_unread_notifications(son.parent)
        return Response({"message": "Account info updated successfully"}, status=200)
    return Response({"error": serializer.errors}, status=400)


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def change_password(request):
    """Change the password of the logged-in student."""
    student = request.user.student
    serializer = ChangeStudentPasswordSerializer(
        student, data=request.data, context={'request': request}
    )
    if serializer.is_valid():
        serializer.save()
        return Response({"message": "Password changed successfully"}, status=200)
    return Response({"error": serializer.errors}, status=400)
