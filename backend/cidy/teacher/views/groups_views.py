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
            # send a notification to the students of the groups
            student_message = f"{student_teacher_pronoun} {teacher.fullname} a supprimé le groupe {group.subject.name} dans lequel vous étiez inscrit."
            StudentNotification.objects.create(
                student = student,
                image = teacher.image,
                message = student_message)
            # send a notification to the parent of the sons attached to each student belongs to the group
            for son in student.sons : 
                child_pronoun = "votre fils" if son.gender == "male" else "votre fille"
                parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a supprimé le groupe du {group.subject.name} dans lequel {child_pronoun} était inscrit."
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
            student_message = f"{student_teacher_pronoun} {teacher.fullname} a modifié l'horaire du cours de {group.subject.name} à : {group.week_day} de {group.start_time_range} à {group.end_time_range} {'seulement cette semaine' if schedule_change_type == 'temporary' else 'de façon permanente'}."
            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message
            )


            # If student has parents, notify them too
            child_pronoun = "votre fils" if student.gender == "male" else "votre fille"
            for son in student.sons.all() :
                # Assuming `son` has an attribute `gender` that can be 'male' or 'female'
                parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a modifié l'horaire du cours de {group.subject.name} de {child_pronoun} {son.fullname} à : {group.week_day} de {group.start_time_range} à {group.end_time_range} {'seulement cette semaine' if schedule_change_type == 'temporary' else 'de façon permanente'}."
                ParentNotification.objects.create(
                    parent=son.parent,
                    image=son.image,
                    message=parent_message,
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
    enrollment_obj = Enrollment.objects.get(student=student,group=group)
    # create the fiance 
    Finance.objects.create(enrollment = enrollment_obj)
    # create a class batch 
    class_batch_obj = ClassBatch.objects.create(enrollment = enrollment_obj)
    # create 4 classes for this batch 
    for i in range(4) : 
        Class.objects.create(batch=class_batch_obj, status='future')
    
    return JsonResponse({
        'success': True,
        'message': 'Student created and added to the group successfully'
    })
