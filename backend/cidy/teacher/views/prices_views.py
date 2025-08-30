from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from ..models import TeacherSubject, Level, Section, Subject, Group, GroupEnrollment
from ..serializers import TeacherLevelsSectionsSubjectsHierarchySerializer,TeacherSubjectSerializer
from student.models import StudentNotification
from parent.models import ParentNotification


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def prices_list(request):
    """Retrieve the list of levels, sections, and subjects for the teacher."""
    teacher = request.user.teacher
    queryset = TeacherSubject.objects.filter(teacher=teacher).select_related('level', 'section', 'subject')
    serializer = TeacherLevelsSectionsSubjectsHierarchySerializer(queryset, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def add_teacher_subject(request):
    """Add a new subject for the teacher."""

    serializer = TeacherSubjectSerializer(data=request.data, context={'request': request})
    if serializer.is_valid():
        teacher = request.user.teacher
        serializer.save(teacher=teacher)
        return Response({"message": "Subject added successfully."}, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def edit_subject_price(request, teacher_subject_id):
    """Edit the price of a subject."""
    teacher = request.user.teacher
    try:
        teacher_subject = TeacherSubject.objects.get(teacher=teacher, id=teacher_subject_id)
    except TeacherSubject.DoesNotExist:
        return Response({"error": "Subject not found."}, status=status.HTTP_404_NOT_FOUND)
    
    serializer = TeacherSubjectSerializer(teacher_subject, data=request.data, partial=True, context={'request': request})
    if serializer.is_valid():
        serializer.save()
        return Response({"message": "Subject price updated successfully."}, status=status.HTTP_200_OK)
    
    # Get the old price before saving
    old_price = teacher_subject.price_per_class
    updated_subject = serializer.save()
    new_price = updated_subject.price_per_class

    # Only send notifications if the price actually changed
    if old_price != new_price:
        
        # Find all groups associated with this teacher subject
        groups = Group.objects.filter(
            teacher
        )

        # Set up pronouns based on teacher gender
        student_teacher_pronoun = "Votre professeur" if teacher.gender == "male" else "Votre professeure"
        parent_teacher_pronoun = "Le professeur" if teacher.gender == "male" else "La professeure"

        # For each group, notify enrolled students and their parents
        for group in groups:
            enrollments = GroupEnrollment.objects.filter(group=group)
            for enrollment in enrollments:
                student = enrollment.student
                
                # Notify student if they have a user account
                if student.user:
                    student_message = f"{student_teacher_pronoun} {teacher.fullname} a changé le prix de la séance de {group.subject.name} de {old_price} à {new_price}."
                    StudentNotification.objects.create(
                        student=student,
                        image=teacher.image,
                        message=student_message,
                        meta_data={"group_id": group.id}
                    )
                
                # Notify parents of the student's sons
                for son in student.sons.all():
                    child_pronoun = "votre fils" if son.gender == "male" else "votre fille"
                    parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a changé le prix de la séance de {group.subject.name} de {child_pronoun} {son.fullname} de {old_price} à {new_price}."
                    ParentNotification.objects.create(
                        parent=son.parent,
                        image=son.image,
                        message=parent_message,
                        meta_data={"son_id": son.id, "group_id": group.id}
                    )
    
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_level_section_subject(request, item_type, item_id):
    """Delete a level, section, or subject."""
    teacher = request.user.teacher

    if item_type == "level":
        try:
            level = Level.objects.get(id=item_id)
            teacher_subjects = TeacherSubject.objects.filter(teacher=teacher, level=level)
            groups = Group.objects.filter(teacher=teacher, level=level)
        except Level.DoesNotExist:
            return Response({"error": "Level not found."}, status=status.HTTP_404_NOT_FOUND)

    elif item_type == "section":
        try:
            section = Section.objects.get(id=item_id)
            teacher_subjects = TeacherSubject.objects.filter(teacher=teacher, section=section)
            groups = Group.objects.filter(teacher=teacher, section=section)
        except Section.DoesNotExist:
            return Response({"error": "Section not found."}, status=status.HTTP_404_NOT_FOUND)

    elif item_type == "subject":
        try:
            subject = Subject.objects.get(id=item_id)
            teacher_subjects = TeacherSubject.objects.filter(teacher=teacher, subject=subject)
            groups = Group.objects.filter(teacher=teacher, subject=subject)
        except Subject.DoesNotExist:
            return Response({"error": "Subject not found."}, status=status.HTTP_404_NOT_FOUND)

    else:
        return Response({"error": "Invalid item type."}, status=status.HTTP_400_BAD_REQUEST)

    # Delete related groups and notify students/parents
    for group in groups:
        group_enrollments = GroupEnrollment.objects.filter(group=group)
        for enrollment in group_enrollments:
            student = enrollment.student
            student.groups.remove(group)
            # Add notification logic here if needed

        group.delete()

    teacher_subjects.delete()
    return Response({"message": f"{item_type.capitalize()} deleted successfully."}, status=status.HTTP_200_OK)
