from django.http import JsonResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from django.db.models import Sum, Q, F
from ..models import Group, TeacherSubject, Enrollment, Finance, ClassBatch, Class
from student.models import Student, StudentNotification
from parent.models import ParentNotification
from common.models import Level, Section, Subject
from datetime import datetime, timedelta
from django.core.paginator import Paginator
from ..serializers import GroupListSerializer, TeacherLevelsSectionsSubjectsHierarchySerializer,GroupCreateUpdateSerializer,GroupDetailsSerializer

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
    start_time_range = request.GET.get('start_time_range')
    end_time_range = request.GET.get('end_time_range')
    if start_time_range and end_time_range and week_day:
        start_time_float = float(start_time_range)
        end_time_float = float(end_time_range)
        groups = groups.filter(
            start_time_range__lte=start_time_float,
            end_time_range__gte=end_time_float
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
    paginated_groups = paginator.get_page(page)
    groups_total_count = paginator.count
    serializer = GroupListSerializer(paginated_groups, many=True)

    # get teacher levels sections subjects hierarchy to use them as options for the filters
    teacher_subjects = TeacherSubject.objects.filter(teacher=teacher).select_related('level','section','subject')
    teacher_levels_sections_subjects_hierarchy = TeacherLevelsSectionsSubjectsHierarchySerializer(teacher_subjects,many=True)

    return JsonResponse({
        'has_groups': True,
        'groups_total_count': groups_total_count,
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
    
    for group in groups:
        students = group.students.all()
        for student in students:
            # send a notification to the students of the groups
            teacher_pronoun = "Votre professeur" if teacher.gender == "male" else "Votre professeure"
            student_message = f"{teacher_pronoun} {teacher.fullname} a supprimé le groupe {group.subject.name} dans lequel vous étiez inscrit."
            StudentNotification.objects.create(
                student = student,
                image = teacher.image,
                message = student_message)
            # send a notification to the parent of the sons attached to each student belongs to the group
            for son in student.sons : 
                child_pronoun = "votre fils" if son.gender == "male" else "votre fille"
                teacher_pronoun = "Le professeur" if teacher.gender == "male" else "La professeure"
                parent_message = f"{teacher_pronoun} {teacher.fullname} a supprimé le groupe du {group.subject.name} dans lequel {child_pronoun} était inscrit."
                ParentNotification.objects.create(
                    parent=son.parent,
                    image=son.image,
                    message=parent_message
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
    serializer.save()
    
    return JsonResponse({
        'success': True,
        'message': 'Group updated successfully'
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def add_students_to_group(request, group_id):
    """Add students to a group"""
    teacher = request.user.teacher
    
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return JsonResponse({'error': 'Group not found'}, status=404)
    
    add_type = request.data.get('add_type')
    if add_type not in ['existing', 'new']:
        return JsonResponse({'error': 'Invalid add type'}, status=400)
    
    if add_type == 'existing':
        student_ids = request.data.get('student_ids', [])
        if not student_ids:
            return JsonResponse({'error': 'No students selected'}, status=400)
        
        results = {
            'added': 0,
            'transferred': 0,
            'errors': 0
        }
        
        for student_id in student_ids:
            try:
                student = Student.objects.get(id=student_id)
                
                # Check if student already in this group
                if group.students.filter(id=student.id).exists():
                    results['errors'] += 1
                    continue
                
                # Check if student is in another group with same subject
                existing_groups = Group.objects.filter(
                    students=student,
                    subject=group.subject,
                    level=group.level
                )
                
                if group.section:
                    existing_groups = existing_groups.filter(section=group.section)
                else:
                    existing_groups = existing_groups.filter(section__isnull=True)
                
                # Remove from existing groups with same subject
                if existing_groups.exists():
                    for existing_group in existing_groups:
                        enrollment = Enrollment.objects.get(student=student, group=existing_group)
                        enrollment.delete()
                    
                    # Add to new group
                    enrollment = Enrollment.objects.create(student=student, group=group)
                    Finance.objects.create(enrollment=enrollment)
                    
                    # Create notification
                    StudentNotification.objects.create(
                        student=student,
                        message=f"The teacher {teacher.fullname} has transferred you to a different {group.subject.name} group: {group.name}.",
                        is_read=False
                    )
                    
                    for son in student.sons.all():
                        child_pronoun = "your son" if son.gender == "M" else "your daughter"
                        ParentNotification.objects.create(
                            parent=son.parent,
                            message=f"The teacher {teacher.fullname} has transferred {child_pronoun} {son.fullname} to a different {group.subject.name} group: {group.name}.",
                            is_read=False
                        )
                    
                    results['transferred'] += 1
                else:
                    # Add to group
                    enrollment = Enrollment.objects.create(student=student, group=group)
                    Finance.objects.create(enrollment=enrollment)
                    
                    # Create notification
                    StudentNotification.objects.create(
                        student=student,
                        message=f"The teacher {teacher.fullname} has added you to the {group.subject.name} group: {group.name}.",
                        is_read=False
                    )
                    
                    for son in student.sons.all():
                        child_pronoun = "your son" if son.gender == "M" else "your daughter"
                        ParentNotification.objects.create(
                            parent=son.parent,
                            message=f"The teacher {teacher.fullname} has added {child_pronoun} {son.fullname} to the {group.subject.name} group: {group.name}.",
                            is_read=False
                        )
                    
                    results['added'] += 1
            except Student.DoesNotExist:
                results['errors'] += 1
        
        return JsonResponse({
            'success': True,
            'results': results
        })
    
    else:  # add_type == 'new'
        # Create a new student
        fullname = request.data.get('fullname')
        phone_number = request.data.get('phone_number')
        gender = request.data.get('gender')
        image = request.FILES.get('image')
        
        if not fullname or not phone_number or not gender:
            return JsonResponse({'error': 'Missing required fields'}, status=400)
        
        # Create student with level and section from group
        student = Student.objects.create(
            fullname=fullname,
            phone_number=phone_number,
            gender=gender,
            level=group.level,
            section=group.section
        )
        
        if image:
            student.image = image
            student.save()
        
        # Add to group
        enrollment = Enrollment.objects.create(student=student, group=group)
        Finance.objects.create(enrollment=enrollment)
        
        return JsonResponse({
            'success': True,
            'student_id': student.id,
            'message': 'Student created and added to group'
        })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def remove_students_from_group(request, group_id):
    """Remove students from a group"""
    teacher = request.user.teacher
    
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return JsonResponse({'error': 'Group not found'}, status=404)
    
    student_ids = request.data.get('student_ids', [])
    if not student_ids:
        return JsonResponse({'error': 'No students selected'}, status=400)
    
    students = Student.objects.filter(id__in=student_ids, groups=group)
    
    for student in students:
        # Remove student from group
        enrollment = Enrollment.objects.get(student=student, group=group)
        enrollment.delete()
        
        # Create notification
        StudentNotification.objects.create(
            student=student,
            message=f"The teacher {teacher.fullname} has removed you from the {group.subject.name} group: {group.name}.",
            is_read=False
        )
        
        for son in student.sons.all():
            child_pronoun = "your son" if son.gender == "M" else "your daughter"
            ParentNotification.objects.create(
                parent=son.parent,
                message=f"The teacher {teacher.fullname} has removed {child_pronoun} {son.fullname} from the {group.subject.name} group: {group.name}.",
                is_read=False
            )
    
    return JsonResponse({
        'success': True,
        'message': f'{students.count()} students removed from group'
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_attendance(request, group_id):
    """Mark attendance for students in a group"""
    teacher = request.user.teacher
    
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return JsonResponse({'error': 'Group not found'}, status=404)
    
    student_ids = request.data.get('student_ids', [])
    attendance_type = request.data.get('attendance_type')  # 'automatic' or 'custom'
    
    if not student_ids or not attendance_type:
        return JsonResponse({'error': 'Missing required fields'}, status=400)
    
    students = Student.objects.filter(id__in=student_ids, groups=group)
    
    if attendance_type == 'custom':
        date_str = request.data.get('date')
        start_time = request.data.get('start_time')
        end_time = request.data.get('end_time')
        
        if not date_str or not start_time or not end_time:
            return JsonResponse({'error': 'Missing date or time range'}, status=400)
        
        try:
            attendance_date = datetime.strptime(date_str, '%Y-%m-%d')
            attendance_time = f"from {start_time} to {end_time}"
        except ValueError:
            return JsonResponse({'error': 'Invalid date format'}, status=400)
    else:  # automatic
        # Use group's schedule
        attendance_date = datetime.now()
        if group.temporary_week_day and datetime.now() <= group.clear_temporary_schedule_at:
            attendance_time = f"from {group.temporary_start_time_range} to {group.temporary_end_time_range}"
        else:
            attendance_time = f"from {group.start_time_range} to {group.end_time_range}"
    
    for student in students:
        enrollment = Enrollment.objects.get(student=student, group=group)
        
        # Get or create class batch
        class_batch = ClassBatch.objects.filter(enrollment=enrollment).order_by('-id').first()
        
        # If no class batch or last class of current batch is already attended/paid, create new batch
        if not class_batch or not Class.objects.filter(batch=class_batch, status='future').exists():
            class_batch = ClassBatch.objects.create(enrollment=enrollment, status='not_due')
            for i in range(4):  # Create 4 classes per batch
                Class.objects.create(batch=class_batch, status='future')
        
        # Find first future class and mark it as attended
        future_class = Class.objects.filter(batch=class_batch, status='future').first()
        future_class.status = 'attended_and_the_payment_not_due'
        future_class.last_status_update = attendance_date
        future_class.save()
        
        # Create notification
        StudentNotification.objects.create(
            student=student,
            message=f"The teacher {teacher.fullname} has marked you as attended in a {group.subject.name} class on {attendance_date.strftime('%Y-%m-%d')} {attendance_time}.",
            is_read=False
        )
        
        for son in student.sons.all():
            child_pronoun = "your son" if son.gender == "M" else "your daughter"
            ParentNotification.objects.create(
                parent=son.parent,
                message=f"The teacher {teacher.fullname} has marked {child_pronoun} {son.fullname} as attended in a {group.subject.name} class on {attendance_date.strftime('%Y-%m-%d')} {attendance_time}.",
                is_read=False
            )
    
    return JsonResponse({
        'success': True,
        'message': f'Attendance marked for {students.count()} students'
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def unmark_attendance(request, group_id):
    """Unmark attendance for students in a group"""
    teacher = request.user.teacher
    
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return JsonResponse({'error': 'Group not found'}, status=404)
    
    student_ids = request.data.get('student_ids', [])
    class_count = request.data.get('class_count', 1)
    
    try:
        class_count = int(class_count)
        if class_count < 1:
            raise ValueError
    except ValueError:
        return JsonResponse({'error': 'Invalid class count'}, status=400)
    
    if not student_ids:
        return JsonResponse({'error': 'No students selected'}, status=400)
    
    students = Student.objects.filter(id__in=student_ids, groups=group)
    
    for student in students:
        enrollment = Enrollment.objects.get(student=student, group=group)
        
        # Get attended classes
        attended_classes = Class.objects.filter(
            batch__enrollment=enrollment,
            status__in=['attended_and_the_payment_not_due', 'attended_and_the_payment_due']
        ).order_by('-last_status_update')[:class_count]
        
        # Count how many were actually unmarked
        unmarked_count = 0
        
        for attended_class in attended_classes:
            attended_class.status = 'future'
            attended_class.save()
            unmarked_count += 1
        
        # Delete empty batches (batches with only future classes)
        empty_batches = ClassBatch.objects.annotate(
            future_count=Sum(
                Case(When(class__status='future', then=1), default=0, output_field=IntegerField())
            ),
            total_count=Count('class')
        ).filter(
            enrollment=enrollment,
            future_count=F('total_count')  # All classes are future
        )
        
        empty_batches.delete()
        
        # Create notification
        if unmarked_count > 0:
            StudentNotification.objects.create(
                student=student,
                message=f"The teacher {teacher.fullname} has unmarked your attendance for {unmarked_count} {group.subject.name} class(es).",
                is_read=False
            )
            
            for son in student.sons.all():
                child_pronoun = "your son" if son.gender == "M" else "your daughter"
                ParentNotification.objects.create(
                    parent=son.parent,
                    message=f"The teacher {teacher.fullname} has unmarked {child_pronoun} {son.fullname}'s attendance for {unmarked_count} {group.subject.name} class(es).",
                    is_read=False
                )
    
    return JsonResponse({
        'success': True,
        'message': f'Attendance unmarked for selected students'
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_payment(request, group_id):
    """Mark payment for students in a group"""
    teacher = request.user.teacher
    
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return JsonResponse({'error': 'Group not found'}, status=404)
    
    student_ids = request.data.get('student_ids', [])
    class_count = request.data.get('class_count', 1)
    payment_datetime_str = request.data.get('payment_datetime')
    
    try:
        class_count = int(class_count)
        if class_count < 1:
            raise ValueError
        
        if payment_datetime_str:
            payment_datetime = datetime.strptime(payment_datetime_str, '%Y-%m-%dT%H:%M:%S')
        else:
            payment_datetime = datetime.now()
    except ValueError:
        return JsonResponse({'error': 'Invalid parameters'}, status=400)
    
    if not student_ids:
        return JsonResponse({'error': 'No students selected'}, status=400)
    
    students = Student.objects.filter(id__in=student_ids, groups=group)
    
    # Get teacher's price for this subject
    try:
        teacher_subject = TeacherSubject.objects.get(
            teacher=teacher,
            level=group.level,
            subject=group.subject,
            section=group.section
        )
        class_price = teacher_subject.price
    except TeacherSubject.DoesNotExist:
        return JsonResponse({'error': 'Price not set for this subject'}, status=400)
    
    for student in students:
        enrollment = Enrollment.objects.get(student=student, group=group)
        finance = Finance.objects.get(enrollment=enrollment)
        
        # Find classes to mark as paid
        classes_to_pay = Class.objects.filter(
            batch__enrollment=enrollment,
            status__in=['future', 'attended_and_the_payment_not_due', 'attended_and_the_payment_due']
        ).order_by('id')[:class_count]
        
        # Count how many classes we actually mark
        marked_count = classes_to_pay.count()
        
        # If we don't have enough classes, create new ones
        if marked_count < class_count:
            classes_needed = class_count - marked_count
            
            # Create a new batch for the remaining classes
            batch = ClassBatch.objects.create(enrollment=enrollment, status='paid')
            
            # Create enough classes to fulfill the request
            for i in range(classes_needed):
                classes_to_pay = list(classes_to_pay) + [Class.objects.create(batch=batch, status='future')]
        
        # Mark all classes as paid
        for cls in classes_to_pay:
            cls.status = 'attended_and_paid'
            cls.last_status_update = payment_datetime
            cls.save()
        
        # Update financial records
        payment_amount = class_price * class_count
        finance.paid_amount += payment_amount
        if finance.unpaid_amount >= payment_amount:
            finance.unpaid_amount -= payment_amount
        else:
            finance.unpaid_amount = 0
        finance.save()
        
        # Create notification
        StudentNotification.objects.create(
            student=student,
            message=f"The teacher {teacher.fullname} has marked {class_count} {group.subject.name} class(es) as paid.",
            is_read=False
        )
        
        for son in student.sons.all():
            child_pronoun = "your son" if son.gender == "M" else "your daughter"
            ParentNotification.objects.create(
                parent=son.parent,
                message=f"The teacher {teacher.fullname} has marked {class_count} of {child_pronoun} {son.fullname}'s {group.subject.name} class(es) as paid.",
                is_read=False
            )
    
    return JsonResponse({
        'success': True,
        'message': f'Payment marked for selected students'
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def unmark_payment(request, group_id):
    """Unmark payment for students in a group"""
    teacher = request.user.teacher
    
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return JsonResponse({'error': 'Group not found'}, status=404)
    
    student_ids = request.data.get('student_ids', [])
    class_count = request.data.get('class_count', 1)
    
    try:
        class_count = int(class_count)
        if class_count < 1:
            raise ValueError
    except ValueError:
        return JsonResponse({'error': 'Invalid class count'}, status=400)
    
    if not student_ids:
        return JsonResponse({'error': 'No students selected'}, status=400)
    
    students = Student.objects.filter(id__in=student_ids, groups=group)
    
    # Get teacher's price for this subject
    try:
        teacher_subject = TeacherSubject.objects.get(
            teacher=teacher,
            level=group.level,
            subject=group.subject,
            section=group.section
        )
        class_price = teacher_subject.price
    except TeacherSubject.DoesNotExist:
        return JsonResponse({'error': 'Price not set for this subject'}, status=400)
    
    for student in students:
        enrollment = Enrollment.objects.get(student=student, group=group)
        finance = Finance.objects.get(enrollment=enrollment)
        
        # Find paid classes to unmark
        paid_classes = Class.objects.filter(
            batch__enrollment=enrollment,
            status='attended_and_paid'
        ).order_by('-last_status_update')[:class_count]
        
        # Count how many were actually unmarked
        unmarked_count = paid_classes.count()
        
        # Update class statuses
        for paid_class in paid_classes:
            # Change back to attended but not paid
            paid_class.status = 'attended_and_the_payment_not_due'
            paid_class.save()
        
        # Delete empty batches (batches with only future classes)
        empty_batches = ClassBatch.objects.annotate(
            future_count=Sum(
                Case(When(class__status='future', then=1), default=0, output_field=IntegerField())
            ),
            total_count=Count('class')
        ).filter(
            enrollment=enrollment,
            future_count=F('total_count')  # All classes are future
        )
        
        empty_batches.delete()
        
        # Update financial records
        refund_amount = class_price * unmarked_count
        finance.paid_amount -= min(refund_amount, finance.paid_amount)
        finance.unpaid_amount += refund_amount
        finance.save()
        
        # Create notification
        if unmarked_count > 0:
            StudentNotification.objects.create(
                student=student,
                message=f"The teacher {teacher.fullname} has unmarked the payment for {unmarked_count} {group.subject.name} class(es).",
                is_read=False
            )
            
            for son in student.sons.all():
                child_pronoun = "your son" if son.gender == "M" else "your daughter"
                ParentNotification.objects.create(
                    parent=son.parent,
                    message=f"The teacher {teacher.fullname} has unmarked the payment for {unmarked_count} of {child_pronoun} {son.fullname}'s {group.subject.name} class(es).",
                    is_read=False
                )
    
    return JsonResponse({
        'success': True,
        'message': f'Payment unmarked for selected students'
    })
    
    students = Student.objects.filter(id__in=student_ids, groups=group)
    
    # Get teacher's price for this subject
    try:
        teacher_subject = TeacherSubject.objects.get(
            teacher=teacher,
            level=group.level,
            subject=group.subject,
            section=group.section
        )
        class_price = teacher_subject.price
    except TeacherSubject.DoesNotExist:
        return JsonResponse({'error': 'Price not set for this subject'}, status=400)
    
    for student in students:
        enrollment = Enrollment.objects.get(student=student, group=group)
        finance = Finance.objects.get(enrollment=enrollment)
        
        # Find paid classes to unmark
        paid_classes = Class.objects.filter(
            batch__enrollment=enrollment,
            status='attended_and_paid'
        ).order_by('-last_status_update')[:class_count]
        
        # Count how many were actually unmarked
        unmarked_count = paid_classes.count()
        
        # Update class statuses
        for paid_class in paid_classes:
            # Change back to attended but not paid
            paid_class.status = 'attended_and_the_payment_not_due'
            paid_class.save()
        
        # Delete empty batches (batches with only future classes)
        empty_batches = ClassBatch.objects.annotate(
            future_count=Sum(
                Case(When(class__status='future', then=1), default=0, output_field=IntegerField())
            ),
            total_count=Count('class')
        ).filter(
            enrollment=enrollment,
            future_count=F('total_count')  # All classes are future
        )
        
        empty_batches.delete()
        
        # Update financial records
        refund_amount = class_price * unmarked_count
        finance.paid_amount -= min(refund_amount, finance.paid_amount)
        finance.unpaid_amount += refund_amount
        finance.save()
        
        # Create notification
        if unmarked_count > 0:
            StudentNotification.objects.create(
                student=student,
                message=f"The teacher {teacher.fullname} has unmarked the payment for {unmarked_count} {group.subject.name} class(es).",
                is_read=False
            )
            
            for son in student.sons.all():
                child_pronoun = "your son" if son.gender == "M" else "your daughter"
                ParentNotification.objects.create(
                    parent=son.parent,
                    message=f"The teacher {teacher.fullname} has unmarked the payment for {unmarked_count} of {child_pronoun} {son.fullname}'s {group.subject.name} class(es).",
                    is_read=False
                )
    
    return JsonResponse({
        'success': True,
        'message': f'Payment unmarked for selected students'
    })
