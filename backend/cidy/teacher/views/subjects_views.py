from rest_framework.decorators import api_view, permission_classes
from django.http import HttpResponseServerError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from ..models import TeacherSubject, Level, Subject, Group, GroupEnrollment
from ..serializers import TeacherLevelsSectionsSubjectsHierarchySerializer,TeacherSubjectSerializer,TesLevelsSectionsSubjectsHierarchySerializer,EditTeacherSubjectPriceSerializer
from student.models import StudentNotification, StudentUnreadNotification
from parent.models import ParentNotification, ParentUnreadNotification,Son 
import time


def increment_student_unread_notifications(student):
    """Helper function to increment student unread notifications count"""
    unread_obj, created = StudentUnreadNotification.objects.get_or_create(student=student)
    unread_obj.unread_notifications += 1
    unread_obj.save()

def increment_parent_unread_notifications(parent):
    """Helper function to increment parent unread notifications count"""
    unread_obj, created = ParentUnreadNotification.objects.get_or_create(parent=parent)
    unread_obj.unread_notifications += 1
    unread_obj.save()

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_levels_sections_subjects(request): 
    #time.sleep(5)

    """Retrieve the list of levels, sections, and subjects for the teacher."""
    
    has_tes = request.query_params.get('has_tes', 'false').lower() == 'true'
    
    teacher = request.user.teacher
    queryset = TeacherSubject.objects.filter(teacher=teacher).select_related('level', 'subject').order_by('level__order')
    teacher_levels_sections_subjects_hierarchy_serializer = TeacherLevelsSectionsSubjectsHierarchySerializer(queryset,with_prices=True)
    response = {
        'teacher_levels_sections_subjects_hierarchy': teacher_levels_sections_subjects_hierarchy_serializer.data
    }

    if not has_tes:
        tes_levels_sections_subjects_hierarchy_serializer = TesLevelsSectionsSubjectsHierarchySerializer(Level.objects.all().order_by('order'))
        response['tes_levels_sections_subjects_hierarchy'] = tes_levels_sections_subjects_hierarchy_serializer.data
    
    print(response)
    return Response(response, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def add_teacher_subject(request):
    
    #time.sleep(5)
    """Add a new subject for the teacher."""

    serializer = TeacherSubjectSerializer(data=request.data, context={'request': request})
    if serializer.is_valid():
        teacher = request.user.teacher
        serializer.save(teacher=teacher)
        return Response({"message": "Subject added successfully."}, status=status.HTTP_200_OK)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def edit_teacher_subject_price(request, teacher_subject_id):
    #return HttpResponseServerError("500 server error")
    #time.sleep(5)
    """Edit the price of a subject."""
    teacher = request.user.teacher
    try:
        teacher_subject = TeacherSubject.objects.get(teacher=teacher, id=teacher_subject_id)
        old_price = teacher_subject.price_per_class
    except TeacherSubject.DoesNotExist:
        return Response({"error": "Subject not found."}, status=status.HTTP_404_NOT_FOUND)
    
    serializer = EditTeacherSubjectPriceSerializer(teacher_subject, data=request.data, partial=True, context={'request': request})
    if serializer.is_valid():
        teacher_subject = serializer.save()
        """
        # Get the old price before saving

        new_price = teacher_subject.price_per_class

        # Only send notifications if the price actually changed
        if old_price != new_price:
            
            # Find all groups associated with this teacher subject
            groups = Group.objects.filter(
                teacher_subject=teacher_subject
            )

            # Set up pronouns based on teacher gender
            student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
            parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

            # For each group, notify enrolled students and their parents
            for group in groups:
                students = group.students.all()
                for student in students:
                    # Notify student if they have an independant account
                    if student.user:
                        student_message = f"{student_teacher_pronoun} {teacher.fullname} a changé le prix de la séance de {group.teacher_subject.subject.name} de {old_price} à {new_price}."
                        StudentNotification.objects.create(
                            student=student,
                            image=teacher.image,
                            message=student_message,
                            meta_data={"group_id": group.id}
                        )
                        increment_student_unread_notifications(student)
                    
                    # Notify parents of the student's sons
                    for son in Son.objects.filter(student_teacher_enrollments__student=student).all():
                        child_pronoun = "votre fils" if son.gender == "M" else "votre fille"
                        parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a changé le prix de la séance de {group.subject.name} de {child_pronoun} {son.fullname} de {old_price} à {new_price}."
                        ParentNotification.objects.create(
                            parent=son.parent,
                            image=son.image,
                            message=parent_message,
                            meta_data={"son_id": son.id, "group_id": group.id}
                        )
                        increment_parent_unread_notifications(son.parent)
            """
        
        return Response({"message": "Subject price updated successfully."}, status=status.HTTP_200_OK)

    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_level_section_subject(request, teacher_subject_id):

    #time.sleep(5)
    #return HttpResponseServerError("500 server error")
    """Delete a level, section, or subject."""
    teacher = request.user.teacher

    try:
        teacher_subject = TeacherSubject.objects.get(id=teacher_subject_id, teacher=teacher)
    except TeacherSubject.DoesNotExist:
        return Response({"error": "Teacher subject not found."}, status=status.HTTP_404_NOT_FOUND)
    
    teacher_subject.delete()
    return Response({"message": "Teacher subject deleted successfully."}, status=status.HTTP_200_OK)

    """
    # Get related groups
    groups = Group.objects.filter(teacher_subject=teacher_subject)

    # Set up pronouns based on teacher gender
    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

    # Delete related groups and notify students/parents
    for group in groups:
        students = group.students.all()

        for student in students:
            if student.user:
                GroupEnrollment.objects.filter(group=group, student=student).delete()
                student_message = f"{student_teacher_pronoun} {teacher.fullname} a supprimé le groupe {group.teacher_subject.subject.name} dans lequel vous étiez inscrit."
                StudentNotification.objects.create(
                            student=student,
                            image=teacher.image,
                            message=student_message,
                            meta_data={"group_id": group.id}
                        )
                increment_student_unread_notifications(student)
            
            # Notify parents of the student's sons
            for son in Son.objects.filter(student_teacher_enrollments__student=student).all():
                child_pronoun = "votre fils" if son.gender == "M" else "votre fille"
                parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a supprimé le groupe du {group.teacher_subject.subject.name} dans lequel {child_pronoun} {son.fullname} était inscrit."
                ParentNotification.objects.create(
                    parent=son.parent,
                    image=son.image,
                    message=parent_message,
                    meta_data={"son_id": son.id}
                )
                increment_parent_unread_notifications(son.parent)

            # I deleted the student if he doesn't have an independant account here to get the sons attached to it before
            if not student.user:
                student.delete()

    
    return Response({"message": "Teacher subject deleted successfully."}, status=status.HTTP_200_OK)

    """