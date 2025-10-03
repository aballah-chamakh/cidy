from datetime import datetime

from django.core.paginator import Paginator
from django.db.models import Q

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from student.models import Student, StudentNotification, StudentUnreadNotification
from parent.models import ParentNotification,Son 
from common.tools import increment_student_unread_notifications, increment_parent_unread_notifications

from ..models import Group, TeacherSubject,GroupEnrollment,Class,TeacherEnrollment
from ..serializers import (GroupCreateStudentSerializer,GroupStudentListSerializer,
                           GroupListSerializer, TeacherLevelsSectionsSubjectsHierarchySerializer,
                           GroupCreateUpdateSerializer,GroupDetailsSerializer,)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def can_create_group(request):
    """Check if a teacher has the ability to create a new group"""
    teacher = request.user.teacher
    
    # Check if teacher has any level with subjects
    has_level_with_subjects = TeacherSubject.objects.filter(teacher=teacher).exists()
    
    if not has_level_with_subjects:
        return Response({
            'can_create': False,
            'message': 'You need to set up at least one level with subjects in the Prices screen before creating a group.'
        })
    
    return Response({
        'can_create': True
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_groups(request):
    """Get a filtered list of groups for the teacher"""
    teacher = request.user.teacher
    groups = Group.objects.filter(teacher=teacher)
    
    # Check if teacher has any groups
    if not groups.exists():
        return Response({
            'has_groups': False
        })
    
    # Apply search filter
    search_term = request.GET.get('name', '')
    if search_term:
        groups = groups.filter(name__icontains=search_term)
    
    # Apply level filter
    level_id = request.GET.get('level')
    if level_id and level_id.isdigit():
        groups = groups.filter(level__id=int(level_id))
    
    # Apply section filter
    section_id = request.GET.get('section')
    if section_id and section_id.isdigit():
        groups = groups.filter(section__id=int(section_id))
    
    # Apply subject filter
    subject_id = request.GET.get('subject')
    if subject_id and subject_id.isdigit():
        groups = groups.filter(subject__id=int(subject_id))
    
    # Apply week day filter
    week_day = request.GET.get('week_day')
    if week_day:
        groups = groups.filter(week_day=week_day)
    
    # Apply time range filter
    start_time = request.GET.get('start_time')

    if start_time :
        start_time = datetime.strptime(start_time, "%H:%M").time()
        groups = groups.filter(
            start_time__gte=start_time
        )

    end_time = request.GET.get('end_time')

    if end_time : 
        end_time = datetime.strptime(end_time, "%H:%M").time()
        groups = groups.filter(
            end_time__lte=end_time
        )


    # Apply sorting
    sort_by = request.GET.get('sort_by')
    if sort_by:
        if sort_by == 'paid_amount_desc':
            groups = groups.order_by('-total_paid')
        elif sort_by == 'paid_amount_asc':
            groups = groups.order_by('total_paid')
        elif sort_by == 'unpaid_amount_desc':
            groups = groups.order_by('-total_unpaid')
        elif sort_by == 'unpaid_amount_asc':
            groups = groups.order_by('total_unpaid')

    # Pagination
    page = request.GET.get('page', 1)
    page_size = request.GET.get('page_size', 30)
    paginator = Paginator(groups, page_size)
    try:
        paginated_groups = paginator.page(page)
    except Exception:
        # If page is out of range, deliver last page
        paginated_groups = paginator.page(paginator.num_pages)
        page = paginator.num_pages

    serializer = GroupListSerializer(paginated_groups, many=True)

    # get teacher levels sections subjects hierarchy to use them as options for the filters
    teacher_subjects = TeacherSubject.objects.filter(teacher=teacher).select_related('level','section','subject')
    teacher_levels_sections_subjects_hierarchy = TeacherLevelsSectionsSubjectsHierarchySerializer(teacher_subjects)
    response = {
        'has_groups': True,
        'groups_total_count': paginator.count,
        'current_page': page,
        'groups': serializer.data,
        'teacher_levels_sections_subjects_hierarchy': teacher_levels_sections_subjects_hierarchy.data
    }
    print(response)
    return Response(response)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_group(request):
    """Create a new group"""
    
    # Create a serializer with the request data
    serializer = GroupCreateUpdateSerializer(data=request.data, context={'request': request})
    
    # Validate the data
    if not serializer.is_valid():
        return Response({'error': serializer.errors}, status=400)
    
    # Create the group
    group = serializer.save()
    
    return Response({
        'success': True,
        'message': 'Group created successfully'
    })


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_groups(request):
    """Delete selected groups"""
    teacher = request.user.teacher
    group_ids = request.data.get('group_ids', [])
    
    if not group_ids:
        return Response({'error': 'No groups selected'}, status=400)
    
    # Get the groups to delete
    groups = Group.objects.filter(teacher=teacher, id__in=group_ids)
    
    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"
    for group in groups:
        students = group.students.all()
        for student in students:
            # send a notification to each student with an independant account
            if student.user :
                student_message = f"{student_teacher_pronoun} {teacher.fullname} a supprimé le groupe {group.teacher_subject.subject.name} dans lequel vous étiez inscrit."
                StudentNotification.objects.create(
                    student = student,
                    image = teacher.image,
                    message = student_message)
                increment_student_unread_notifications(student)
            # send a notification to the parent of the sons attached to each student belongs to the group
            for son in Son.objects.filter(student_teacher_enrollments__student=student).all() : 
                child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
                parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a supprimé le groupe du {group.teacher_subject.subject.name} dans lequel {child_pronoun} {son.fullname} était inscrit."

                ParentNotification.objects.create(
                    parent=son.parent,
                    image=son.image,
                    message=parent_message,
                    meta_data = {"son_id":son.id}
                )
                increment_parent_unread_notifications(son.parent)
        group.delete()    
    
    return Response({
        'success': True,
        'message': f'{len(groups)} groups deleted successfully'
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_group_details(request, group_id):
    """Get detailed information about a specific group"""
    teacher = request.user.teacher

    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)
    
    
    serializer = GroupDetailsSerializer(group,context={'request':request})

    
    return Response(serializer.data)


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def edit_group(request, group_id):
    """Edit an existing group"""
    teacher = request.user.teacher
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)
    
    # pass the data to update the serializer
    serializer = GroupCreateUpdateSerializer(group,data=request.data, context={'request': request}, partial=True)
    
    # Validate the data
    if not serializer.is_valid():
        return Response({'error': serializer.errors}, status=400)
    
    # update the group
    group = serializer.save()

    # Check if the schedule of the group has changed
    schedule_change_type = request.data.get('schedule_change_type')
    if schedule_change_type : 
        student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
        parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

        for student in group.students.all() :
            # Create notification for each student
            student_message = f"{student_teacher_pronoun} {teacher.fullname} a modifié l'horaire du cours de {group.teacher_subject.subject.name} à : {group.week_day} de {group.start_time.strftime('%H:%M')} à {group.end_time.strftime('%H:%M')} {'seulement cette semaine' if schedule_change_type == 'temporary' else 'de façon permanente'}."
            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message,
                meta_data = {'group_id': group.id}
            )
            increment_student_unread_notifications(student)

            # If student has parents, notify them too
            child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
            for son in Son.objects.filter(student_teacher_enrollments__student=student).all() :
                parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a modifié l'horaire du cours de {group.teacher_subject.subject.name} de {child_pronoun} {son.fullname} à : {group.week_day} de {group.start_time.strftime('%H:%M')} à {group.end_time.strftime('%H:%M')} {'seulement cette semaine' if schedule_change_type == 'temporary' else 'de façon permanente'}."
                ParentNotification.objects.create(
                    parent=son.parent,
                    image=son.image,
                    message=parent_message,
                    meta_data = {"son_id":son.id,'group_id':group.id}
                )
                increment_parent_unread_notifications(son.parent)
    
    return Response({
        'success': True,
        'message': 'Group updated successfully'
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_group_students(request,group_id):
    """
    Get all students of the teacher with filtering options
    """
    teacher = request.user.teacher
    
    try: 
        group = Group.objects.get(id=group_id,teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)

    # Get students associated with this group
    students = group.students.all()

    # Apply fullname filter
    fullname = request.GET.get('fullname', '')
    if fullname:
        students = students.filter(fullname__icontains=fullname)
    

    page = request.GET.get('page', 1)
    page_size = request.GET.get('page_size', 30)
    paginator = Paginator(students, page_size)
    
    try:
        paginated_students = paginator.page(page)
    except Exception:
        # If page is out of range, deliver last page
        paginated_students = paginator.page(paginator.num_pages)
    
    serializer = GroupStudentListSerializer(paginated_students,many=True)
    
    return Response({
        'students': serializer.data,
        'total_students': paginator.count,
    })


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def create_group_student(request, group_id):
    """Create a new student then add them to the specified group"""
    teacher = request.user.teacher

    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)

    # Create a serializer with the request data
    serializer = GroupCreateStudentSerializer(data=request.data)

    # Validate the data
    if not serializer.is_valid():
        return Response({'error': serializer.errors}, status=400)

    # Save the student
    student = serializer.save(level=group.teacher_subject.level,section=group.teacher_subject.section)

    # Add the student to the group
    group.students.add(student)

    
    return Response({
        'success': True,
        'message': 'Student created and added to the group successfully'
    })

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def add_students_to_group(request,group_id):

    student_ids = request.data.get('student_ids',[])
    teacher = request.user.teacher
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)
    
    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"
    # add the students to the group 
    students_qs = group.students.filter(id__in=student_ids, teacherenrollment_set__teacher=teacher)
    for student in students_qs :
        # enroll the student in the group 
        GroupEnrollment.objects.create(group=group, student=student)
        # Create notification for each student that has an independant account
        if student.user : 
            student_message = f"{student_teacher_pronoun} {teacher.fullname} a ajouté vous à un groupe de {group.teacher_subject.subject.name}."
            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message,
                meta_data = {'group_id': group.id}
            )
            increment_student_unread_notifications(student)
        # If student has parents, notify them too
        child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
        for son in Son.objects.filter(student_teacher_enrollments__student=student).all() :
            # Assuming `son` has an attribute `gender` that can be 'male' or 'female'
            parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a ajouté {child_pronoun} {son.fullname} à un groupe de {group.teacher_subject.subject.name}."
            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
                meta_data = {"son_id":son.id,'group_id':group.id}
            )
            increment_parent_unread_notifications(son.parent)

    return Response({
        'success': True,
        'message': 'Students added to the group successfully'
    })


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def remove_students_from_group(request, group_id):
    """Remove students from a specific group"""
    teacher = request.user.teacher

    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)

    student_ids = request.data.get('student_ids', [])
    if not student_ids:
        return Response({'error': 'No student IDs provided'}, status=400)

    students_to_remove = group.students.filter(id__in=student_ids)
    if not students_to_remove.exists():
        return Response({'error': 'No matching students found in the group'}, status=404)

    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

    for student in students_to_remove:
        # Notify the student if they have an independent account
        if student.user:
            student_message = f"{student_teacher_pronoun} {teacher.fullname} vous a retiré du groupe de {group.subject.name}."
            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message
            )
            increment_student_unread_notifications(student)

        # Notify the parents of the student
        child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
        for son in Son.objects.filter(student_teacher_enrollments__student=student).all():
            parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a retiré {child_pronoun} {son.fullname} du groupe de {group.subject.name}."
            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
                meta_data={"son_id": son.id}
            )
            increment_parent_unread_notifications(son.parent)

        # Remove the student from the group
        group.students.remove(student)

    return Response({
        'success': True,
        'message': f'{students_to_remove.count()} students removed from the group successfully'
    })

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def mark_attendance(request, group_id):
    """Mark attendance for selected students in a group"""

    # validate the request data
    student_ids = request.data.get('student_ids', [])
    if not student_ids:
        return Response({'error': 'No student IDs provided'}, status=400)

    attendance_date = request.data.get('attendance_date')
    attendance_start_time = request.data.get('attendance_start_time')
    attendance_end_time = request.data.get('attendance_end_time')
    
    if not attendance_date or not attendance_start_time or not attendance_end_time:
        return Response({'error': 'Date and time range are required for the "specify" option'}, status=400)

    attendance_date = datetime.strptime(attendance_date, "%d/%m/%Y").date()
    attendance_start_time = datetime.strptime(attendance_start_time, "%H:%M").time()
    attendance_end_time = datetime.strptime(attendance_end_time, "%H:%M").time()

    teacher = request.user.teacher

    # check if the group exists and belongs to the teacher
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)

    # check if these students are enrolled in the group of the teacher
    students = group.students.filter(id__in=student_ids, teacherenrollment_set__teacher=teacher)
    if not students.exists():
        return Response({'error': 'No students found in the group'}, status=404)

    teacher_subject = TeacherSubject.objects.filter(teacher=teacher, level=group.level, section=group.section, subject=group.subject).first()

    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

    for student in students:
        student_teacher_enrollment = TeacherEnrollment.objects.get(student=student, teacher=teacher)
        student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
        if student_group_enrollment.attended_non_paid_classes >= 3 : 
            # only when i have 3 non paid classes, mark them as attended_and_the_payment_due because since then we will mark the next class as attended_and_the_payment_due
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
            student_message = f"{student_teacher_pronoun} {teacher.fullname} vous a marqué comme présent(e) dans le cours de {group.subject.name} le {attendance_date.strftime('%d/%m/%Y')} de {attendance_start_time.strftime('%H:%M')} à {attendance_end_time.strftime('%H:%M')}."
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
            parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a marqué {child_pronoun} {son.fullname} comme présent(e) dans le cours de {group.subject.name} le {attendance_date.strftime('%d/%m/%Y')} de {attendance_start_time.strftime('%H:%M')} à {attendance_end_time.strftime('%H:%M')}."
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
def unmark_attendance(request, group_id):
    """Unmark attendance for selected students in a group"""
    teacher = request.user.teacher

    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)

    teacher_subject = TeacherSubject.objects.filter(teacher=teacher,level=group.level,section=group.section,subject=group.subject).first()

    student_ids = request.data.get('student_ids', [])
    if not student_ids:
        return Response({'error': 'No student IDs provided'}, status=400)

    num_classes_to_unmark = request.data.get('num_classes_to_unmark')
    if not num_classes_to_unmark or not isinstance(num_classes_to_unmark, int) or num_classes_to_unmark < 1:
        return Response({'error': 'Invalid number of classes to unmark'}, status=400)

    students = group.students.filter(id__in=student_ids)
    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

    for student in students:
        student_teacher_enrollment = TeacherEnrollment.objects.get(student=student, teacher=teacher)
        student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
        attended_classes_to_delete = Class.objects.filter(
            group_enrollment=student_group_enrollment,
            status__in=['attended_and_the_payment_not_due', 'attended_and_the_payment_due']
        ).order_by('-id')[:num_classes_to_unmark]
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
def mark_absence(request,group_id):
    """Mark absence for the specified students in the specified group"""

    # validate the request data
    student_ids = request.data.get('student_ids', [])
    if not student_ids:
        return Response({'error': 'No student IDs provided'}, status=400)

    absence_date = request.data.get('absence_date')
    absence_start_time = request.data.get('absence_start_time')
    absence_end_time = request.data.get('absence_end_time')

    if not absence_date or not absence_start_time or not absence_end_time:
        return Response({'error': 'Date and time range are required'}, status=400)

    absence_date = datetime.strptime(absence_date, "%d/%m/%Y").date()
    absence_start_time = datetime.strptime(absence_start_time, "%H:%M").time()
    absence_end_time = datetime.strptime(absence_end_time, "%H:%M").time()

    teacher = request.user.teacher

    # check if the group exists and belongs to the teacher
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)

    # check if these students have a relationship with the teacher
    students = Student.objects.filter(id__in=student_ids, teacherenrollment_set__teacher=teacher)
    if not students.exists():
        return Response({'error': 'No students found in the group'}, status=404)

    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"


    response = {'success': True, 
             'number_of_students_their_absence_was_marked_successfully': 0,
             'the_students_that_their_absence_was_not_marked_successfully': []}
    
    for student in students:
        student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
        # check that there is no class that has the same attendance date
        existing_classes = student_group_enrollment.class_set.filter(Q(attendance_date=absence_date) | Q(absence_date=absence_date))
        if  existing_classes.exists():
            existing_class = existing_classes.first()
            if existing_class.status == 'absent':
                response['the_students_that_their_absence_was_not_marked_successfully'].append({
                    'student_id': student.id,
                    'student_name': student.fullname,
                    'error': 'Absence for this date has already been marked'
                })
            else:
                response['the_students_that_their_absence_was_not_marked_successfully'].append({
                    'student_id': student.id,
                    'student_name': student.fullname,
                    'error': 'Attendance for this date has already been marked'
                })

        Class.objects.create(group_enrollment=student_group_enrollment,
                            absence_date=absence_date,
                            absence_start_time=absence_start_time,
                            absence_end_time=absence_end_time,
                            status='absent')
        response['number_of_students_their_absence_was_marked_successfully'] += 1
        

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
        for son in Son.objects.filter(student_teacher_enrollments__student=student).all():
            parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a marqué l'absence de {child_pronoun} {son.fullname} dans la séance de {group.subject.name} qui a eu lieu le {absence_date} de {absence_start_time} à {absence_end_time}."
            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
                meta_data={"son_id": son.id, "group_id": group.id}
            )
            increment_parent_unread_notifications(son.parent)

    return Response(response)

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def unmark_absence(request,group_id):
    """Unmark absence for the specified students in the specified group"""

    # validate the request data
    student_ids = request.data.get('student_ids', [])
    if not student_ids:
        return Response({'error': 'No student IDs provided'}, status=400)

    number_of_classes_to_unmark = request.data.get('number_of_classes_to_unmark')
    if not number_of_classes_to_unmark or not isinstance(number_of_classes_to_unmark, int) or number_of_classes_to_unmark < 1:
        return Response({'error': 'Invalid number of classes to unmark'}, status=400)

    teacher = request.user.teacher

    # check if the group exists and belongs to the teacher
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)

    # check if these students have a relationship with the teacher
    students = Student.objects.filter(id__in=student_ids, teacherenrollment_set__teacher=teacher)
    if not students.exists():
        return Response({'error': 'No students found in the group'}, status=404)

    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

    for student in students:

        # get the absent classes of this student 
        student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
        existing_classes = student_group_enrollment.class_set.filter(status='absent').order_by('-absence_date')[:number_of_classes_to_unmark]
        if not existing_classes.exists():
            return Response({'error': 'No absent classes found to unmark'}, status=404)
        
        classes_to_unmark_their_absence_count = existing_classes.count()
        # delete these absent classes
        existing_classes.delete()

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
        for son in Son.objects.filter(student_teacher_enrollments__student=student).all():
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
        'message': 'Absences were unmarked successfully.'
    })

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def mark_payment(request, group_id):
    """Mark payment for selected students in a group"""
    teacher = request.user.teacher

    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)

    teacher_subject = TeacherSubject.objects.filter(teacher=teacher,level=group.level,section=group.section,subject=group.subject).first()

    student_ids = request.data.get('student_ids', [])
    if not student_ids:
        return Response({'error': 'No student IDs provided'}, status=400)

    num_classes_to_mark = request.data.get('num_classes_to_mark')
    payment_datetime = request.data.get('payment_datetime')

    if not num_classes_to_mark or not isinstance(num_classes_to_mark, int) or num_classes_to_mark < 1:
        return Response({'error': 'Invalid number of classes to mark as paid'}, status=400)

    if not payment_datetime:
        return Response({'error': 'Payment datetime is required'}, status=400)

    payment_datetime = datetime.strptime(payment_datetime, "%H:%M:%S-%d/%m/%Y")

    students = group.students.filter(id__in=student_ids)
    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

    for student in students:
        student_teacher_enrollment = TeacherEnrollment.objects.get(student=student, teacher=teacher)
        student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
        classes_to_mark_as_paid = Class.objects.filter(
            group_enrollment=student_group_enrollment,
            status__in=['attended_and_the_payment_due','attended_and_the_payment_not_due']
        )[:num_classes_to_mark]
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
            if attended_class_non_marked_as_paid_cnt> 0 and attended_class_non_marked_as_paid_cnt < 4 : 
                Class.objects.filter(group_enrollment=student_group_enrollment, status='attended_and_the_payment_due').update(status='attended_and_the_payment_not_due')

        student_group_enrollment.paid_amount += classes_to_mark_as_paid_count * teacher_subject.price_per_class
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
        for son in Son.objects.filter(student_teacher_enrollments__student=student).all():
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
def unmark_payment(request, group_id):
    """Unmark payment for selected students in a group"""
    teacher = request.user.teacher

    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)

    teacher_subject = TeacherSubject.objects.filter(teacher=teacher,level=group.level,section=group.section,subject=group.subject).first()

    student_ids = request.data.get('student_ids', [])
    if not student_ids:
        return Response({'error': 'No student IDs provided'}, status=400)

    num_classes_to_unmark = request.data.get('num_classes_to_unmark')

    if not num_classes_to_unmark or not isinstance(num_classes_to_unmark, int) or num_classes_to_unmark < 1:
        return Response({'error': 'Invalid number of classes to unmark their payment'}, status=400)


    students = Student.objects.filter(id__in=student_ids)
    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

    for student in students:
        student_teacher_enrollment = TeacherEnrollment.objects.get(student=student, teacher=teacher)
        student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
        paid_classes = Class.objects.filter(
            group_enrollment=student_group_enrollment,
            status__in=['attended_and_paid']
        ).order_by('-id')[:num_classes_to_unmark]

        # Unmark the payment of the specified number of classes 
        for unpaid_class in paid_classes:
            # handle the finances
            student_group_enrollment.attended_non_paid_classes += 1

            if student_group_enrollment.attended_non_paid_classes >= 4 : 
                # once we reach 4 attended and non paid classes, mark the previous 3 as due
                if student_group_enrollment.attended_non_paid_classes == 4 : 
                    student_group_enrollment.unpaid_amount += teacher_subject.price_per_class * 3
                    student_teacher_enrollment.unpaid_amount += teacher_subject.price_per_class * 3
                    Class.objects.filter(group_enrollment=student_group_enrollment, status='attended_and_the_payment_not_due').update(status='attended_and_the_payment_due')
                # mark the new one as due too 
                unpaid_class.status = 'attended_and_the_payment_due'
                student_group_enrollment.unpaid_amount += teacher_subject.price_per_class
                student_teacher_enrollment.unpaid_amount += teacher_subject.price_per_class
            student_group_enrollment.paid_amount -= teacher_subject.price_per_class
            
            unpaid_class.paid_at = None
            unpaid_class.save()

        unpaid_classes_count = paid_classes.count()
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




"""


# Check if the student is already in a group with the same level, section, and subject
        student_groups = Group.objects.filter(
            students=student,
            teacher_subject=group.teacher_subject
        )
        if student_groups.exists():
            student_group = student_groups.first()
            student_group.students.remove(student)
            group.students.add(student)

            for student in group.students.all() :
                # Create notification for each student that has an independant account
                if student.user : 
                    student_message = f"{student_teacher_pronoun} {teacher.fullname} a changé votre groupe de {group.teacher_subject.subject.name}."
                    StudentNotification.objects.create(
                        student=student,
                        image=teacher.image,
                        message=student_message,
                        meta_data = {'group_id': group.id}
                    )
                    increment_student_unread_notifications(student)
                # If student has parents, notify them too
                child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
                for son in Son.objects.filter(student_teacher_enrollments__student=student).all() :
                    # Assuming `son` has an attribute `gender` that can be 'male' or 'female'
                    parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a changé le groupe de {group.teacher_subject.subject.name} de {child_pronoun} {son.fullname}."
                    ParentNotification.objects.create(
                        parent=son.parent,
                        image=son.image,
                        message=parent_message,
                        meta_data = {"son_id":son.id,'group_id':group.id}
                    )
                    increment_parent_unread_notifications(son.parent)
        else : 

"""