from datetime import datetime
import time
from rest_framework.permissions import IsAuthenticated
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from django.db.models import Q, Sum
from django.core.paginator import Paginator
from ..models import Group, GroupEnrollment, TeacherSubject,TeacherEnrollment,Class
from student.models import Student, StudentNotification, StudentUnreadNotification
from parent.models import ParentNotification, ParentUnreadNotification, Son
from ..serializers import (TeacherLevelsSectionsSubjectsHierarchySerializer,
                           TeacherStudentListSerializer,
                           TeacherStudentCreateSerializer,
                           TeacherStudentDetailSerializer,
                           TeacherStudentUpdateSerializer,)
from rest_framework import serializers
from django.http import HttpResponseServerError


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
def can_create_student(request):
    """Check if a teacher has the ability to create a new student"""
    teacher = request.user.teacher
    
    # Check if teacher has any level with subjects
    has_level_with_subjects = TeacherSubject.objects.filter(teacher=teacher).exists()
    
    if not has_level_with_subjects:
        return Response({
            'can_create': False,
            'message': 'You need to set up at least one level with subjects in the Prices screen before creating a student.'
        })
    
    return Response({
        'can_create': True
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_students(request):
    #time.sleep(5)
    """Get a filtered list of students for the teacher"""
    teacher = request.user.teacher
    students = Student.objects.filter(teacherenrollment__teacher=teacher)

    # Apply fullname filter
    fullname = request.GET.get('fullname', '')
    if fullname:
        students = students.filter(fullname__icontains=fullname)

    # Apply level filter
    level = request.GET.get('level')
    if level :
        students = students.filter(level__name=level)

    # Apply section filter
    section = request.GET.get('section')
    if section:
        students = students.filter(level__section=section)

    # add the paid and unpaid amounts fields 
    students = students.annotate(
                paid_amount=Sum('teacherenrollment__paid_amount'),
                unpaid_amount=Sum('teacherenrollment__unpaid_amount')
            )
    # Apply sorting
    sort_by = request.GET.get('sort_by', '')
    if sort_by:
        if sort_by == 'paid_amount_desc':
            students = students.order_by('-paid_amount')
        elif sort_by == 'paid_amount_asc':
            students = students.order_by('paid_amount')
        elif sort_by == 'unpaid_amount_desc':
            students = students.order_by('-unpaid_amount')
        elif sort_by == 'unpaid_amount_asc':
            students = students.order_by('unpaid_amount')
    else:
        students = students.order_by('id')
    # Pagination
    page = request.GET.get('page', 1)
    page_size = request.GET.get('page_size', 30)
    paginator = Paginator(students, page_size)
    try:
        paginated_students = paginator.page(page)
    except Exception:
        page = 1
        paginated_students = paginator.page(1)

    # Serialize the students
    serializer = TeacherStudentListSerializer(paginated_students, many=True, context={'request': request})

    # Get teacher levels, sections, and subjects hierarchy for filter options
    teacher_subjects = TeacherSubject.objects.filter(teacher=teacher).select_related('level', 'subject')
    teacher_levels_sections_subjects_hierarchy = TeacherLevelsSectionsSubjectsHierarchySerializer(teacher_subjects)
    print("============ paid amount type :", type(students[0].paid_amount))
    return Response({
        'total_students': paginator.count,
        'students': serializer.data,
        'page': int(page),
        'teacher_levels_sections_subjects_hierarchy': teacher_levels_sections_subjects_hierarchy.data
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_student(request):
    """Create a new student"""

    serializer = TeacherStudentCreateSerializer(data=request.data, context={'request': request})
    if serializer.is_valid() :
        teacher = request.user.teacher
        student = serializer.save()
        TeacherEnrollment.objects.create(
            student=student,
            teacher=teacher,
        )
        return Response({
            'success': True,
            'message': 'Student created successfully.',
        })
    print(serializer.errors)
    return Response(serializer.errors, status=400)

@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_students(request):
    #time.sleep(5)
    """Delete selected students"""
    teacher = request.user.teacher
    student_ids = request.data.get('student_ids', [])
    print(student_ids)

    if not student_ids:
        return Response({
            'success': False,
            'message': 'No students selected for deletion.'
        }, status=400)

    students = Student.objects.filter(id__in=student_ids, teacherenrollment__teacher=teacher)
    
    if not students.exists():
        return Response({
            'success': False,
            'message': 'Selected students do not exist.'
        }, status=404)

    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"
    
    print(students)
    for student in students:
        print(f"Processing student: {student.fullname}")
        # Check if the student has his independent account
        if student.user:
            print(f"student has a user : {student.fullname}")
            # send a notification to the student
            student_message = f"{student_teacher_pronoun} {teacher.fullname} a mis fin à votre relation."
            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message
            )
            increment_student_unread_notifications(student)

        # send a notification to the parent of the sons attached to each student to delete
       
        
        for son in Son.objects.filter(student_teacher_enrollments__student=student).all() : 

            child_pronoun = "votre fils" if son.gender == "M" else "votre fille"
            parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a mis fin à la relation avec {child_pronoun} {son.fullname}."
            
            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
                meta_data = {"son_id":son.id}
            )
            increment_parent_unread_notifications(son.parent)

        # notes i made the deletes here to get the sons attached to the student before deleting him or his enrollments
        if student.user:
            print(student.user)
            print(f"student has a user : {student.fullname}")
            # delete the enrollment with this teacher and the enrollments in the groups of this teacher without deleting the student because he has his independent account
            TeacherEnrollment.objects.filter(student=student, teacher=teacher).delete()
            GroupEnrollment.objects.filter(student=student, group__teacher=teacher).delete()
        else :
            print(f'Student {student.fullname} deleted.')
            # delete the student here, because he doesn't have an independent account, 
            # this will lead to deleting his teacher enrollment and his group enrollments
            student.delete()

    return Response({
        'success': True,
        'message': f'{len(student_ids)} students were deleted.'
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_student_details(request, student_id):
    #time.sleep(5)
    """Get details of a specific student"""
    teacher = request.user.teacher

    try:
        student = Student.objects.get(id=student_id, teacherenrollment__teacher=teacher)
    except Student.DoesNotExist:
        return Response({'error': 'Student not found'}, status=404)

    serializer = TeacherStudentDetailSerializer(student, context={'request': request})

    student_details = serializer.data
    teacher_subjects = TeacherSubject.objects.filter(teacher=teacher).select_related('level', 'subject')
    teacher_levels_sections_subjects_hierarchy = TeacherLevelsSectionsSubjectsHierarchySerializer(teacher_subjects)
    print(student_details)
    return Response({
        'student_detail': student_details,
        'teacher_levels_sections_subjects_hierarchy': teacher_levels_sections_subjects_hierarchy.data
    })


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def edit_student(request, student_id):
    #time.sleep(5)
    """Update a student's core information"""
    teacher = request.user.teacher
    print(request.data)

    try:
        student = Student.objects.get(id=student_id, teacherenrollment__teacher=teacher)
    except Student.DoesNotExist:
        return Response({
            'success': False,
            'message': 'Student not found.'
        }, status=404)

    serializer = TeacherStudentUpdateSerializer(
        student,
        data=request.data,
        partial=True,
        context={'request': request}
    )

    if serializer.is_valid():
        serializer.save()
        return Response({
            'success': True,
            'message': 'Student updated successfully.'
        })
    
    print(serializer.errors)

    return Response(serializer.errors, status=400)


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def mark_attendance_of_a_student(request,student_id,group_id):
    """Mark attendance for a students in a group"""

    attendance_date = request.data.get('attendance_date')
    attendance_start_time = request.data.get('attendance_start_time')
    attendance_end_time = request.data.get('attendance_end_time')

    if not attendance_date or not attendance_start_time or not attendance_end_time:
        return Response({'error': 'Date and time range are required for the "specify" option'}, status=400)

    attendance_date = datetime.strptime(attendance_date, "%d/%m/%Y").date()
    attendance_start_time = datetime.strptime(attendance_start_time, "%H:%M").time()
    attendance_end_time = datetime.strptime(attendance_end_time, "%H:%M").time()

    teacher = request.user.teacher

    try:
        # to ensure the group belongs to the teacher
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)
    try : 
        # to ensure that the student exists
        student = Student.objects.get(id=student_id)
    except Student.DoesNotExist:
        return Response({'error': 'Student not enrolled in this group'}, status=404)
    
    try:
        # to ensure that the student is enrolled in the group
        student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
    except GroupEnrollment.DoesNotExist:
        return Response({'error': 'Student is not enrolled in this group'}, status=404)

    # check that there is not class that has the same attendance date
    existing_classes_with_the_same_attendance_date = student_group_enrollment.class_set.filter(attendance_date=attendance_date)
    if existing_classes_with_the_same_attendance_date.exists():
        existing_class = existing_classes_with_the_same_attendance_date.first()
        if existing_class.status == 'absent':
            existing_class.delete()
        else : 
            return Response({'error': 'Attendance for this date has already been marked'}, status=400)

    teacher_subject = TeacherSubject.objects.filter(teacher=teacher,level=group.level,section=group.section,subject=group.subject).first()
    student_teacher_enrollment = TeacherEnrollment.objects.filter(teacher=teacher, student=student).first()

    if student_group_enrollment.attended_non_paid_classes >= 3 : 
        # only when i have 3 non paid classes, mark them as attended_and_the_payment_due  because since then we will mark the next class as attended_and_the_payment_due
        if student_group_enrollment.attended_non_paid_classes == 3 :
            Class.objects.filter(group_enrollment=student_group_enrollment, status='attended_and_the_payment_not_due').update(status='attended_and_the_payment_due')
            student_group_enrollment.unpaid_amount += teacher_subject.price_per_class * 3
            student_teacher_enrollment.unpaid_amount += teacher_subject.price_per_class * 3
        # create the next class as attended_and_the_payment_due
        Class.objects.create(enrollement=student_group_enrollment,
                            attendance_date=attendance_date,
                            attendance_start_time=attendance_start_time,
                            attendance_end_time=attendance_end_time,
                            status = 'attended_and_the_payment_due')
        student_group_enrollment.unpaid_amount += teacher_subject.price_per_class
        student_teacher_enrollment.unpaid_amount += teacher_subject.price_per_class
    else : 
        Class.objects.create(enrollement=student_group_enrollment,
                            attendance_date=attendance_date,
                            attendance_start_time=attendance_start_time,
                            attendance_end_time=attendance_end_time,
                            status = 'attended_and_the_payment_not_due')
    student_group_enrollment.attended_non_paid_classes += 1
    student_group_enrollment.save()
    # Notify the student
    if student.user:
        student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
        student_message = f"{student_teacher_pronoun} {teacher.fullname} vous a marqué comme présent(e) dans la séance de {group.subject.name} qui a eu lieu le {attendance_date.strftime('%d/%m/%Y')} de {attendance_start_time.strftime('%H:%M')} à {attendance_end_time.strftime('%H:%M')}."
        StudentNotification.objects.create(
            student=student,
            image=teacher.image,
            message=student_message,
            meta_data={"group_id": group.id}
        )
        increment_student_unread_notifications(student)

    # Notify the parents
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"
    child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
    for son in Son.objects.filter(student_teacher_enrollments__student=student).all():
        parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a marqué {child_pronoun} {son.fullname} comme présent(e) dans la séance de {group.subject.name} qui a eu lieu le {attendance_date.strftime('%d/%m/%Y')} de {attendance_start_time.strftime('%H:%M')} à {attendance_end_time.strftime('%H:%M')}."
        ParentNotification.objects.create(
            parent=son.parent,
            image=son.image,
            message=parent_message,
            meta_data={"son_id": son.id,"group_id": group.id}
        )
        increment_parent_unread_notifications(son.parent)

    return Response({
        'success': True,
        'message': 'Attendance marked successfully'
    })



@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def unmark_attendance_of_a_student(request, group_id, student_id):

    """Unmark attendance for a students in a group"""

    num_classes_to_unmark = request.data.get('num_classes_to_unmark')

    if not num_classes_to_unmark or not isinstance(num_classes_to_unmark, int) or num_classes_to_unmark <= 0:
        return Response({'error': 'Invalid number of classes to unmark'}, status=400)

    teacher = request.user.teacher

    try:
        # to ensure the group belongs to the teacher
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)
    try : 
        # to ensure that the student exists
        student = Student.objects.get(id=student_id)
    except Student.DoesNotExist:
        return Response({'error': 'Student not enrolled in this group'}, status=404)
    
    try:
        # to ensure that the student is enrolled in the group
        student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
    except GroupEnrollment.DoesNotExist:
        return Response({'error': 'Student is not enrolled in this group'}, status=404)

    teacher_subject = TeacherSubject.objects.filter(teacher=teacher,level=group.level,section=group.section,subject=group.subject).first()
    student_teacher_enrollment = TeacherEnrollment.objects.filter(teacher=teacher, student=student).first()


    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

    attended_classes_to_delete = Class.objects.filter(
        group_enrollment=student_group_enrollment,
        status__in=['attended_and_the_payment_not_due', 'attended_and_the_payment_due']
    ).order_by('-attendance_date')[:num_classes_to_unmark]

    if not attended_classes_to_delete.exists():
        return Response({'error': 'No attended classes found to unmark'}, status=404)

    attended_classes_to_delete_count = attended_classes_to_delete.count()

    for attended_class in attended_classes_to_delete :
        attended_class.delete()

    # check if all of the attended classes of the student are due 
    if student_group_enrollment.attended_non_paid_classes >= 4 :
        # since all of the the attended non paid classes of the student are due, remove the decrease the unpaid amount 
        # by the the number of classes to delete * price per class 
        student_group_enrollment.unpaid_amount -= teacher_subject.price_per_class * attended_classes_to_delete_count
        student_teacher_enrollment.unpaid_amount -= teacher_subject.price_per_class * attended_classes_to_delete_count
        # if we still have less than 4 classes attended and their payment are due after deleting the classes
        # convert their status to attended and their payment not due 
        classes_to_not_delete_count = student_group_enrollment.attended_non_paid_classes - attended_classes_to_delete_count 
        if classes_to_not_delete_count > 0 and classes_to_not_delete_count < 4 : 
            Class.objects.filter(group_enrollment=student_group_enrollment, status='attended_and_the_payment_due').update(status='attended_and_the_payment_not_due')
    # remove the number of deleted classes from the attended non paid classes ones 
    student_group_enrollment.attended_non_paid_classes -= attended_classes_to_delete_count 
    student_group_enrollment.save()

    # Notify the student
    if student.user:
        student_message = f"{student_teacher_pronoun} {teacher.fullname} a annulé votre présence pour {attended_classes_to_delete_count} séances de {group.subject.name}."
        StudentNotification.objects.create(
            student=student,
            image=teacher.image,
            message=student_message,
            meta_data={"group_id": group.id}
        )
        increment_student_unread_notifications(student)

    # Notify the parents
    child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
    for son in Son.objects.filter(student_teacher_enrollments__student=student).all():
        parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a annulé la présence de {child_pronoun} {son.fullname} pour {attended_classes_to_delete_count} séances de {group.subject.name}."
        ParentNotification.objects.create(
            parent=son.parent,
            image=son.image,
            message=parent_message,
            meta_data={"son_id": son.id, "group_id": group.id}
        )
        increment_parent_unread_notifications(son.parent)

    return Response({
        'success': True,
        'message': 'Attendance unmarked successfully'
    })


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def mark_absence_of_a_student(request,student_id,group_id):
    """Mark absence for a student in a group"""

    absence_date = request.data.get('absence_date')
    absence_start_time = request.data.get('absence_start_time')
    absence_end_time = request.data.get('absence_end_time')

    if not absence_date or not absence_start_time or not absence_end_time:
        return Response({'error': 'Date and time range are required for the "specify" option'}, status=400)

    absence_date = datetime.strptime(absence_date, "%d/%m/%Y").date()
    absence_start_time = datetime.strptime(absence_start_time, "%H:%M").time()
    absence_end_time = datetime.strptime(absence_end_time, "%H:%M").time()

    teacher = request.user.teacher

    try:
        # to ensure the group belongs to the teacher
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)
    try : 
        # to ensure that the student exists
        student = Student.objects.get(id=student_id)
    except Student.DoesNotExist:
        return Response({'error': 'Student not enrolled in this group'}, status=404)
    
    try:
        # to ensure that the student is enrolled in the group
        student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
    except GroupEnrollment.DoesNotExist:
        return Response({'error': 'Student is not enrolled in this group'}, status=404)

    # check that there is not class that has the same attendance date
    existing_classes = student_group_enrollment.class_set.filter(Q(attendance_date=absence_date) | Q(absence_date=absence_date))
    if  existing_classes.exists():
        existing_class = existing_classes.first()
        if existing_class.status == 'absent':
            return Response({'error': 'Absence for this date has already been marked'}, status=400)
        else : 
            return Response({'error': 'Attendance for this date has already been marked'}, status=400)

    Class.objects.create(group_enrollment=student_group_enrollment,
                         absence_date=absence_date,
                         absence_start_time=absence_start_time,
                         absence_end_time=absence_end_time,
                         status='absent')
    
    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

    # Notify the student
    if student.user:
        student_message = f"{student_teacher_pronoun} {teacher.fullname} a marqué votre absence dans la séance de {group.subject.name} qui a eu lieu le {absence_date} de {absence_start_time} à {absence_end_time}."
        StudentNotification.objects.create(
            student=student,
            image=teacher.image,
            message=student_message,
            meta_data={"group_id": group.id}
        )
        increment_student_unread_notifications(student)

    # Notify the parents
    child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
    for son in Son.objects.filter(student_teacher_enrollments__student=student).all().all():
        parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a marqué l'absence de {child_pronoun} {son.fullname} dans la séance de {group.subject.name} qui a eu lieu le {absence_date} de {absence_start_time} à {absence_end_time}."
        ParentNotification.objects.create(
            parent=son.parent,
            image=son.image,
            message=parent_message,
            meta_data={"son_id": son.id, "group_id": group.id}
        )
        increment_parent_unread_notifications(son.parent)

    return Response({
        'success': True,
        'message': 'Absence marked successfully'
    })


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def unmark_absence_of_a_student(request,student_id,group_id):
    """Mark absence for a student in a group"""

    absence_date = request.data.get('absence_date')
    absence_start_time = request.data.get('absence_start_time')
    absence_end_time = request.data.get('absence_end_time')

    if not absence_date or not absence_start_time or not absence_end_time:
        return Response({'error': 'Date and time range are required for the "specify" option'}, status=400)

    number_of_classes_to_unmark = request.data.get('number_of_classes_to_unmark')

    if not number_of_classes_to_unmark or not isinstance(number_of_classes_to_unmark, int) or number_of_classes_to_unmark <= 0:
        return Response({'error': 'Invalid number of classes to unmark'}, status=400)

    absence_date = datetime.strptime(absence_date, "%d/%m/%Y").date()
    absence_start_time = datetime.strptime(absence_start_time, "%H:%M").time()
    absence_end_time = datetime.strptime(absence_end_time, "%H:%M").time()

    teacher = request.user.teacher

    try:
        # to ensure the group belongs to the teacher
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)
    try : 
        # to ensure that the student exists
        student = Student.objects.get(id=student_id)
    except Student.DoesNotExist:
        return Response({'error': 'Student not enrolled in this group'}, status=404)
    
    try:
        # to ensure that the student is enrolled in the group
        student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
    except GroupEnrollment.DoesNotExist:
        return Response({'error': 'Student is not enrolled in this group'}, status=404)

    # get the absent classes
    existing_classes = student_group_enrollment.class_set.filter(status='absent').order_by('-absence_date')[:number_of_classes_to_unmark]
    if not existing_classes.exists():
        return Response({'error': 'No absent classes found to unmark'}, status=404)
    
    classes_to_unmark_their_absence_count = existing_classes.count()
    existing_classes.delete()

    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

    # Notify the student
    if student.user:
        student_message = f"{student_teacher_pronoun} {teacher.fullname} a annulé pour vous l'absence de {classes_to_unmark_their_absence_count} séance(s) de {group.subject.name}."
        StudentNotification.objects.create(
            student=student,
            image=teacher.image,
            message=student_message,
            meta_data={"group_id": group.id}
        )
        increment_student_unread_notifications(student)

    # Notify the parents
    child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
    for son in Son.objects.filter(student_teacher_enrollments__student=student).all().all():
        parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a annulé pour {child_pronoun} {son.fullname} l'absence de {classes_to_unmark_their_absence_count} séance(s) de {group.subject.name}."
        ParentNotification.objects.create(
            parent=son.parent,
            image=son.image,
            message=parent_message,
            meta_data={"son_id": son.id, "group_id": group.id}
        )
        increment_parent_unread_notifications(son.parent)

    return Response({
        'success': True,
        'message': 'unmarked Absence successfully'
    })


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def mark_payment_of_a_student(request, group_id, student_id):

    """Mark payment for a students in a group"""

    num_classes_to_mark = request.data.get('num_classes_to_mark')
    if not num_classes_to_mark or not isinstance(num_classes_to_mark, int) or num_classes_to_mark <= 0:
        return Response({'error': 'Invalid number of classes to mark'}, status=400)

    payment_datetime = request.data.get('payment_datetime')
    if not payment_datetime:
        return Response({'error': 'Invalid payment datetime'}, status=400)

    payment_datetime = datetime.strptime(payment_datetime, "%H:%M:%S-%d/%m/%Y")

    teacher = request.user.teacher

    try:
        # to ensure the group belongs to the teacher
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)
    try : 
        # to ensure that the student exists
        student = Student.objects.get(id=student_id)
    except Student.DoesNotExist:
        return Response({'error': 'Student not enrolled in this group'}, status=404)
    
    try:
        # to ensure that the student is enrolled in the group
        student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
    except GroupEnrollment.DoesNotExist:
        return Response({'error': 'Student is not enrolled in this group'}, status=404)

    teacher_subject = TeacherSubject.objects.filter(teacher=teacher,level=group.level,section=group.section,subject=group.subject).first()
    student_teacher_enrollment = TeacherEnrollment.objects.filter(teacher=teacher, student=student).first()

    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

    student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
    classes_to_mark_as_paid = Class.objects.filter(
        group_enrollment=student_group_enrollment,
        status__in=['attended_and_the_payment_due','attended_and_the_payment_not_due']
    ).order_by('attendance_date')[:num_classes_to_mark]

    if not classes_to_mark_as_paid.exists():
        return Response({'error': 'No attended classes found to mark as paid'}, status=404)

    classes_to_mark_as_paid_count = classes_to_mark_as_paid.count()

    # Mark the payment for the class to mark as paid 
    for unpaid_class in classes_to_mark_as_paid:
        unpaid_class.status = 'attended_and_paid'
        unpaid_class.paid_at = payment_datetime
        unpaid_class.save()

    ## handle the finances 
    # if we have only attended and due payment classes 
    if student_group_enrollment.attended_non_paid_classes >= 4 : 
        # remove the unpaid amount of theses classes 
        student_group_enrollment.unpaid_amount -= teacher_subject.price_per_class * classes_to_mark_as_paid_count
        student_teacher_enrollment.unpaid_amount -= teacher_subject.price_per_class * classes_to_mark_as_paid_count
        # if we still have due payment classes after marking the payment, convert them to not due payment classes
        attended_class_non_marked_as_paid_cnt = student_group_enrollment.attended_non_paid_classes - classes_to_mark_as_paid_count
        if attended_class_non_marked_as_paid_cnt > 0 and attended_class_non_marked_as_paid_cnt < 4 : 
            Class.objects.filter(group_enrollment=student_group_enrollment, status='attended_and_the_payment_due').update(status='attended_and_the_payment_not_due')

    student_group_enrollment.paid_amount += classes_to_mark_as_paid_count * teacher_subject.price_per_class
    student_teacher_enrollment.paid_amount += classes_to_mark_as_paid_count * teacher_subject.price_per_class
    student_group_enrollment.attended_non_paid_classes -= classes_to_mark_as_paid_count
    # Notify the student
    if student.user:
        student_message = f"{student_teacher_pronoun} {teacher.fullname} a marqué {classes_to_mark_as_paid_count} séance(s) de {group.subject.name} comme payée(s)."
        StudentNotification.objects.create(
            student=student,
            image=teacher.image,
            message=student_message,
            meta_data={"group_id": group.id}
        )
        increment_student_unread_notifications(student)

    # Notify the parents
    child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
    for son in Son.objects.filter(student_teacher_enrollments__student=student).all().all():
        parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a marqué {classes_to_mark_as_paid_count} séance(s) de {group.subject.name} de {child_pronoun} {son.fullname} comme payée(s)."
        ParentNotification.objects.create(
            parent=son.parent,
            image=son.image,
            message=parent_message,
            meta_data={"son_id": son.id, "group_id": group.id}
        )
        increment_parent_unread_notifications(son.parent)

    return Response({
        'success': True,
        'message': 'Payment marked successfully'
    })


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def unmark_payment_of_a_student(request, group_id, student_id):

    """Unmark payment for a students in a group"""

    num_classes_to_unmark = request.data.get('num_classes_to_unmark')
    if not num_classes_to_unmark or not isinstance(num_classes_to_unmark, int) or num_classes_to_unmark <= 0:
        return Response({'error': 'Invalid number of classes to unmark'}, status=400)

    teacher = request.user.teacher

    try:
        # to ensure the group belongs to the teacher
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)
    try : 
        # to ensure that the student exists
        student = Student.objects.get(id=student_id)
    except Student.DoesNotExist:
        return Response({'error': 'Student not enrolled in this group'}, status=404)
    
    try:
        # to ensure that the student is enrolled in the group
        student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
    except GroupEnrollment.DoesNotExist:
        return Response({'error': 'Student is not enrolled in this group'}, status=404)

    teacher_subject = TeacherSubject.objects.filter(teacher=teacher,level=group.level,section=group.section,subject=group.subject).first()
    student_teacher_enrollment = TeacherEnrollment.objects.filter(teacher=teacher, student=student).first()

    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

    student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
    paid_classes = Class.objects.filter(
        group_enrollment=student_group_enrollment,
        status__in=['attended_and_paid']
    ).order_by('-attendance_date')[:num_classes_to_unmark]

    if not paid_classes.exists():
        return Response({'error': 'No paid classes found to unmark'}, status=404)

    unpaid_classes_count = paid_classes.count()

    # Unmark the payment of the specified number of classes 
    for unpaid_class in paid_classes:
        # handle the finances
        student_group_enrollment.attended_non_paid_classes += 1

        if student_group_enrollment.attended_non_paid_classes >= 4 : 
            # once we reach 4 attended and non paid classes, mark the previous 4 as due
            if student_group_enrollment.attended_non_paid_classes == 4 : 
                student_group_enrollment.unpaid_amount += teacher_subject.price_per_class * 3
                student_teacher_enrollment.unpaid_amount += teacher_subject.price_per_class * 3
                Class.objects.filter(group_enrollment=student_group_enrollment, status='attended_and_the_payment_not_due').update(status='attended_and_the_payment_due')
            # mark the new one as due too 
            unpaid_class.status = 'attended_and_the_payment_due'
            student_group_enrollment.unpaid_amount += teacher_subject.price_per_class
            student_teacher_enrollment.unpaid_amount += teacher_subject.price_per_class

        student_group_enrollment.paid_amount -= teacher_subject.price_per_class
        student_teacher_enrollment.paid_amount -= teacher_subject.price_per_class

        unpaid_class.paid_at = None
        unpaid_class.save()

    
    # Notify the student
    if student.user:
        student_message = f"{student_teacher_pronoun} {teacher.fullname} a marqué {unpaid_classes_count} séance(s) de {group.subject.name} comme payée(s)."
        StudentNotification.objects.create(
            student=student,
            image=teacher.image,
            message=student_message,
            meta_data={"group_id": group.id}
        )
        increment_student_unread_notifications(student)

    # Notify the parents
    child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
    for son in Son.objects.filter(student_teacher_enrollments__student=student).all():
        parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a marqué {unpaid_classes_count} séance(s) de {group.subject.name} de {child_pronoun} {son.fullname} comme payée(s)."
        ParentNotification.objects.create(
            parent=son.parent,
            image=son.image,
            message=parent_message,
            meta_data={"son_id": son.id, "group_id": group.id}
        )
        increment_parent_unread_notifications(son.parent)

    return Response({
        'success': True,
        'message': 'Payment marked successfully'
    })

