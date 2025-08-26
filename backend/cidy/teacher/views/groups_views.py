from datetime import datetime
from django.http import JsonResponse
from django.db import models
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from ..models import Group, TeacherSubject,Enrollment,ClassBatch,Class
from student.models import Student, StudentNotification
from parent.models import ParentNotification
from django.core.paginator import Paginator
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
        return JsonResponse({
            'can_create': False,
            'message': 'You need to set up at least one level with subjects in the Prices screen before creating a group.'
        })
    
    return JsonResponse({
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
        return JsonResponse({
            'has_groups': False
        })
    
    # Apply search filter
    search_term = request.GET.get('search', '')
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

    serializer = GroupListSerializer(paginated_groups, many=True)

    # get teacher levels sections subjects hierarchy to use them as options for the filters
    teacher_subjects = TeacherSubject.objects.filter(teacher=teacher).select_related('level','section','subject')
    teacher_levels_sections_subjects_hierarchy = TeacherLevelsSectionsSubjectsHierarchySerializer(teacher_subjects,many=True)

    return JsonResponse({
        'has_groups': True,
        'groups_total_count': paginator.count,
        'groups': serializer.data,
        'teacher_levels_sections_subjects_hierarchy': teacher_levels_sections_subjects_hierarchy.data
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_group(request):
    """Create a new group"""
    
    # Create a serializer with the request data
    serializer = GroupCreateUpdateSerializer(data=request.data, context={'request': request})
    
    # Validate the data
    if not serializer.is_valid():
        return JsonResponse({'error': serializer.errors}, status=400)
    
    # Create the group
    group = serializer.save()
    
    return JsonResponse({
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
        return JsonResponse({'error': 'No groups selected'}, status=400)
    
    # Get the groups to delete
    groups = Group.objects.filter(teacher=teacher, id__in=group_ids)
    
    student_teacher_pronoun = "Votre professeur" if teacher.gender == "male" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "male" else "La professeure"
    for group in groups:
        students = group.students.all()
        for student in students:
            # send a notification to each student with an independant account
            if student.user :
                student_message = f"{student_teacher_pronoun} {teacher.fullname} a supprimé le groupe {group.subject.name} dans lequel vous étiez inscrit."
                StudentNotification.objects.create(
                    student = student,
                    image = teacher.image,
                    message = student_message)
            # send a notification to the parent of the sons attached to each student belongs to the group
            child_pronoun = "votre fils" if son.gender == "male" else "votre fille"
            parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a supprimé le groupe du {group.subject.name} dans lequel {child_pronoun} était inscrit."
            for son in student.sons : 
                ParentNotification.objects.create(
                    parent=son.parent,
                    image=son.image,
                    message=parent_message,
                    meta_data = {"son_id":son.id}
                )
        group.delete()    
    
    return JsonResponse({
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
        return JsonResponse({'error': 'Group not found'}, status=404)
    
    
    serializer = GroupDetailsSerializer(group,context={'request':request})

    
    return JsonResponse(serializer.data)


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def edit_group(request, group_id):
    """Edit an existing group"""
    teacher = request.user.teacher
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return JsonResponse({'error': 'Group not found'}, status=404)
    
    # pass the data to update the serializer
    serializer = GroupCreateUpdateSerializer(group,data=request.data, context={'request': request}, partial=True)
    
    # Validate the data
    if not serializer.is_valid():
        return JsonResponse({'error': serializer.errors}, status=400)
    
    # update the group
    group = serializer.save()

    # Check if the schedule of the group has changed
    schedule_change_type = request.data.get('schedule_change_type')
    if schedule_change_type : 
        student_teacher_pronoun = "Votre professeur" if teacher.gender == "male" else "Votre professeure"
        parent_teacher_pronoun = "Le professeur" if teacher.gender == "male" else "La professeure"

        for student in group.students.all() :
            # Create notification for each student
            student_message = f"{student_teacher_pronoun} {teacher.fullname} a modifié l'horaire du cours de {group.subject.name} à : {group.week_day} de {group.start_time.strftime('%H:%M')} à {group.end_time.strftime('%H:%M')} {'seulement cette semaine' if schedule_change_type == 'temporary' else 'de façon permanente'}."
            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message,
                meta_data = {'group_id': group.id}
            )

            # If student has parents, notify them too
            child_pronoun = "votre fils" if student.gender == "male" else "votre fille"
            for son in student.sons.all() :
                # Assuming `son` has an attribute `gender` that can be 'male' or 'female'
                parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a modifié l'horaire du cours de {group.subject.name} de {child_pronoun} {son.fullname} à : {group.week_day} de {group.start_time.strftime('%H:%M')} à {group.end_time.strftime('%H:%M')} {'seulement cette semaine' if schedule_change_type == 'temporary' else 'de façon permanente'}."
                ParentNotification.objects.create(
                    parent=son.parent,
                    image=son.image,
                    message=parent_message,
                    meta_data = {"son_id":son.id,'group_id':group.id}
                )
    
    return JsonResponse({
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
        return JsonResponse({'error': 'Group not found'}, status=404)

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
    
    return JsonResponse({
        'students': serializer.data,
        'total_students': paginator.count,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_group_student(request, group_id):
    """Create a new student then add them to the specified group"""
    teacher = request.user.teacher

    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return JsonResponse({'error': 'Group not found'}, status=404)

    # Create a serializer with the request data
    serializer = GroupCreateStudentSerializer(data=request.data)

    # Validate the data
    if not serializer.is_valid():
        return JsonResponse({'error': serializer.errors}, status=400)

    # Save the student
    student = serializer.save(level=group.level,section=group.section)

    # Add the student to the group
    group.students.add(student)

    
    return JsonResponse({
        'success': True,
        'message': 'Student created and added to the group successfully'
    })

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def add_students_to_group(request,group_id):

    student_ids = request.data.get('student_ids',[])
    teacher = request.user.teacher
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return JsonResponse({'error': 'Group not found'}, status=404)
    
    student_teacher_pronoun = "Votre professeur" if teacher.gender == "male" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "male" else "La professeure"
    # add the students to the group 
    students_qs = Student.objects.filter(id__in=student_ids)
    for student in students_qs :
        # Check if the student is already in a group with the same level, section, and subject
        student_groups = Group.objects.filter(
            students=student,
            level=group.level,
            section=group.section,
            subject=group.subject
        )
        if student_groups.exists():
            student_group = student_groups.first()
            student_group.students.remove(student)
            group.students.add(student)

            for student in group.students.all() :
                # Create notification for each student that has an independant account
                if student.user : 
                    student_message = f"{student_teacher_pronoun} {teacher.fullname} a changé votre groupe de {group.subject.name}."
                    StudentNotification.objects.create(
                        student=student,
                        image=teacher.image,
                        message=student_message,
                        meta_data = {'group_id': group.id}
                    )
                # If student has parents, notify them too
                child_pronoun = "votre fils" if student.gender == "male" else "votre fille"
                for son in student.sons.all() :
                    # Assuming `son` has an attribute `gender` that can be 'male' or 'female'
                    parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a changé le groupe de {group.subject.name} de {child_pronoun} {son.fullname}."
                    ParentNotification.objects.create(
                        parent=son.parent,
                        image=son.image,
                        message=parent_message,
                        meta_data = {"son_id":son.id,'group_id':group.id}
                    )
        else : 
            group.students.add(student)
            for student in group.students.all() :
                # Create notification for each student that has an independant account
                if student.user : 
                    student_message = f"{student_teacher_pronoun} {teacher.fullname} a ajouté vous à un groupe de {group.subject.name}."
                    StudentNotification.objects.create(
                        student=student,
                        image=teacher.image,
                        message=student_message,
                        meta_data = {'group_id': group.id}
                    )
                # If student has parents, notify them too
                child_pronoun = "votre fils" if student.gender == "male" else "votre fille"
                for son in student.sons.all() :
                    # Assuming `son` has an attribute `gender` that can be 'male' or 'female'
                    parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a ajouté {child_pronoun} {son.fullname} à un groupe de {group.subject.name}."
                    ParentNotification.objects.create(
                        parent=son.parent,
                        image=son.image,
                        message=parent_message,
                        meta_data = {"son_id":son.id,'group_id':group.id}
                    )

    return JsonResponse({
        'success': True,
        'message': 'Students added to the group successfully'
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def remove_students_from_group(request, group_id):
    """Remove students from a specific group"""
    teacher = request.user.teacher

    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return JsonResponse({'error': 'Group not found'}, status=404)

    student_ids = request.data.get('student_ids', [])
    if not student_ids:
        return JsonResponse({'error': 'No student IDs provided'}, status=400)

    students_to_remove = group.students.filter(id__in=student_ids)
    if not students_to_remove.exists():
        return JsonResponse({'error': 'No matching students found in the group'}, status=404)

    student_teacher_pronoun = "Votre professeur" if teacher.gender == "male" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "male" else "La professeure"

    for student in students_to_remove:
        # Notify the student if they have an independent account
        if student.user:
            student_message = f"{student_teacher_pronoun} {teacher.fullname} vous a retiré du groupe de {group.subject.name}."
            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message
            )

        # Notify the parents of the student
        child_pronoun = "votre fils" if student.gender == "male" else "votre fille"
        for son in student.sons.all():
            parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a retiré {child_pronoun} {son.fullname} du groupe de {group.subject.name}."
            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
                meta_data={"son_id": son.id}
            )

        # Remove the student from the group
        group.students.remove(student)

    return JsonResponse({
        'success': True,
        'message': f'{students_to_remove.count()} students removed from the group successfully'
    })

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_attendance(request, group_id):
    """Mark attendance for selected students in a group"""
    teacher = request.user.teacher

    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return JsonResponse({'error': 'Group not found'}, status=404)

    student_ids = request.data.get('student_ids', [])
    if not student_ids:
        return JsonResponse({'error': 'No student IDs provided'}, status=400)

    attendance_date = request.data.get('attendance_date')
    attendance_start_time = request.data.get('attendance_start_time')
    attendance_end_time = request.data.get('attendance_end_time')

    if not attendance_date or not attendance_start_time or not attendance_end_time:
        return JsonResponse({'error': 'Date and time range are required for the "specify" option'}, status=400)

    attendance_date = datetime.strptime(attendance_date, "%d/%m/%Y").date()
    attendance_start_time = datetime.strptime(attendance_start_time, "%H:%M").time()
    attendance_end_time = datetime.strptime(attendance_end_time, "%H:%M").time()

    students = Student.objects.filter(id__in=student_ids)
    student_teacher_pronoun = "Votre professeur" if teacher.gender == "male" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "male" else "La professeure"

    for student in students:
        student_enrollment = Enrollment.objects.get(student=student, group=group)
        if student_enrollment.attended_non_paid_classes >= 3 : 
            # only when i have 3 non paid classes, mark them as attended_and_the_payment_due  because since then we will mark the next class as attended_and_the_payment_due
            if student_enrollment.attended_non_paid_classes == 3 :
                Class.objects.filter(enrollment=student_enrollment, status='attended_and_the_payment_not_due').update(status='attended_and_the_payment_due')
            # create the next class as attended_and_the_payment_due
            Class.objects.create(enrollement=student_enrollment,
                                attendance_date=attendance_date,
                                attendance_start_time=attendance_start_time,
                                attendance_end_time=attendance_end_time,
                                status = 'attended_and_the_payment_due')
        else : 
            Class.objects.create(enrollement=student_enrollment,
                                attendance_date=attendance_date,
                                attendance_start_time=attendance_start_time,
                                attendance_end_time=attendance_end_time,
                                status = 'attended_and_the_payment_not_due')
        student_enrollment.attended_non_paid_classes += 1
        student_enrollment.save()
        # Notify the student
        if student.user:
            student_message = f"{student_teacher_pronoun} {teacher.fullname} vous a marqué comme présent(e) dans le cours de {group.subject.name} le {attendance_date.strftime('%d/%m/%Y')} de {attendance_start_time.strftime('%H:%M')} à {attendance_end_time.strftime('%H:%M')}."
            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message,
                meta_data={"group_id": group.id}
            )

        # Notify the parents
        child_pronoun = "votre fils" if student.gender == "male" else "votre fille"
        for son in student.sons.all():
            parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a marqué {child_pronoun} {son.fullname} comme présent(e) dans le cours de {group.subject.name} le {attendance_date.strftime('%d/%m/%Y')} de {attendance_start_time.strftime('%H:%M')} à {attendance_end_time.strftime('%H:%M')}."
            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
                meta_data={"son_id": son.id,"group_id": group.id}
            )

    return JsonResponse({
        'success': True,
        'message': 'Attendance marked successfully'
    })

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def unmark_attendance(request, group_id):
    """Unmark attendance for selected students in a group"""
    teacher = request.user.teacher

    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return JsonResponse({'error': 'Group not found'}, status=404)

    student_ids = request.data.get('student_ids', [])
    if not student_ids:
        return JsonResponse({'error': 'No student IDs provided'}, status=400)

    num_classes_to_unmark = request.data.get('num_classes_to_unmark')
    if not num_classes_to_unmark or not isinstance(num_classes_to_unmark, int) or num_classes_to_unmark < 1:
        return JsonResponse({'error': 'Invalid number of classes to unmark'}, status=400)

    students = Student.objects.filter(id__in=student_ids)
    student_teacher_pronoun = "Votre professeur" if teacher.gender == "male" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "male" else "La professeure"

    for student in students:
        student_enrollment = Enrollment.objects.get(student=student, group=group)
        attended_classes = Class.objects.filter(
            enrollment=student_enrollment,
            status__in=['attended_and_the_payment_not_due', 'attended_and_the_payment_due']
        ).order_by('-id')[:num_classes_to_unmark]

        for attended_class in attended_classes:
            attended_class.delete()

        attended_classes_count = len(attended_classes)
        # Notify the student
        if student.user:
            student_message = f"{student_teacher_pronoun} {teacher.fullname} a annulé votre présence pour {attended_classes_count} séances de {group.subject.name}."
            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message,
                meta_data={"group_id": group.id}
            )

        # Notify the parents
        child_pronoun = "votre fils" if student.gender == "male" else "votre fille"
        for son in student.sons.all():
            parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a annulé la présence de {child_pronoun} {son.fullname} pour {attended_classes_count} séances de {group.subject.name}."
            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
                meta_data={"son_id": son.id, "group_id": group.id}
            )

    return JsonResponse({
        'success': True,
        'message': 'Attendance unmarked successfully'
    })
        

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_payment(request, group_id):
    """Mark payment for selected students in a group"""
    teacher = request.user.teacher

    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return JsonResponse({'error': 'Group not found'}, status=404)

    student_ids = request.data.get('student_ids', [])
    if not student_ids:
        return JsonResponse({'error': 'No student IDs provided'}, status=400)

    num_classes_to_mark = request.data.get('num_classes_to_mark')
    payment_datetime = request.data.get('payment_datetime')

    if not num_classes_to_mark or not isinstance(num_classes_to_mark, int) or num_classes_to_mark < 1:
        return JsonResponse({'error': 'Invalid number of classes to mark as paid'}, status=400)

    if not payment_datetime:
        return JsonResponse({'error': 'Payment datetime is required'}, status=400)

    payment_datetime = datetime.strptime(payment_datetime, "%H:%M:%S-%d/%m/%Y")

    students = Student.objects.filter(id__in=student_ids)
    student_teacher_pronoun = "Votre professeur" if teacher.gender == "male" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "male" else "La professeure"

    for student in students:
        student_enrollment = Enrollment.objects.get(student=student, group=group)
        unpaid_classes = Class.objects.filter(
            enrollment=student_enrollment,
            status__in=['attended_and_the_payment_due','attended_and_the_payment_not_due']
        ).order_by('id')[:num_classes_to_mark]

        # Mark the specified number of classes as paid
        for unpaid_class in unpaid_classes:
            unpaid_class.status = 'attended_and_paid'
            unpaid_class.paid_at = payment_datetime
            unpaid_class.save()

        unpaid_classes_count = len(unpaid_classes)
        # Notify the student
        if student.user:
            student_message = f"{student_teacher_pronoun} {teacher.fullname} a marqué {unpaid_classes_count} séance(s) de {group.subject.name} comme payée(s)."
            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message,
                meta_data={"group_id": group.id}
            )

        # Notify the parents
        child_pronoun = "votre fils" if student.gender == "male" else "votre fille"
        for son in student.sons.all():
            parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a marqué {unpaid_classes_count} séance(s) de {group.subject.name} de {child_pronoun} {son.fullname} comme payée(s)."
            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
                meta_data={"son_id": son.id, "group_id": group.id}
            )

    return JsonResponse({
        'success': True,
        'message': 'Payment marked successfully'
    })
