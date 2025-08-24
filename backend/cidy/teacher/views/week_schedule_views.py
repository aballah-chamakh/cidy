from django.http import JsonResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from ..models import Group
from student.models import StudentNotification
from parent.models import ParentNotification
from datetime import datetime, timedelta
from django.db.models import Q


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_week_schedule(request):
    """
    Get all groups of the teacher with their schedule details for the week schedule screen
    """
    teacher = request.user.teacher
    groups = Group.objects.filter(teacher=teacher)
    
    schedule_data = []
    for group in groups:
        section_name = group.section.name if group.section else None
        
        schedule_data.append({
            'id': group.id,
            'name': group.name,
            'subject': {
                'id': group.subject.id,
                'name': group.subject.name
            },
            'level': {
                'id': group.level.id,
                'name': group.level.name
            },
            'section': {
                'id': group.section.id,
                'name': section_name
            } if section_name else None,
            'week_day': group.week_day,
            'start_time_range': group.start_time_range,
            'end_time_range': group.end_time_range,
            'students_count': group.students.count()
        })
    
    return JsonResponse({'groups': schedule_data})

# review it
@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def update_group_schedule(request, group_id):
    """
    Update a group's schedule - handles both permanent and temporary changes
    """

    # check if the teacher has groups
    teacher = request.user.teacher
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return JsonResponse({'error': 'Group not found'}, status=404)
    
    new_day = request.data.get('week_day')
    new_start_time_range = float(request.data.get('start_time_range'))
    new_end_time_range = float(request.data.get('end_time_range'))
    change_type = request.data.get('change_type')  # 'permanent' or 'temporary'

    if not new_day or not new_start_time_range or not new_end_time_range or not change_type:
        return JsonResponse({'error': 'Missing required fields'}, status=400)
    
    if change_type not in ['permanent', 'temporary']:
        return JsonResponse({'error': 'Invalid change type'}, status=400)
    
    # Check for schedule conflicts with other groups
    # Exclude current group from check
    conflicting_groups = Group.objects.filter(
        teacher=teacher,
        week_day=new_day
    ).exclude(id=group.id).filter(
        (Q(start_time_range__lte=new_start_time_range) & Q(end_time_range__gte=new_start_time_range)) |
        (Q(start_time_range__lte=new_end_time_range) & Q(end_time_range__gte=new_end_time_range)) |
        (Q(start_time_range__gte=new_start_time_range) & Q(end_time_range__lte=new_end_time_range))
    )
    
    if conflicting_groups.exists():
        return JsonResponse({
            'error': 'Schedule conflict detected',
        }, status=400)

    # Update the group schedule
    if change_type == 'permanent':
        group.week_day = new_day
        group.start_time_range = new_start_time_range
        group.end_time_range = new_end_time_range
        group.save()
    else:
        group.temporary_week_day = new_day
        group.temporary_start_time_range = new_start_time_range
        group.temporary_end_time_range = new_end_time_range
        # Set the clear_temporary_schedule_at to the end of the current week
        today = datetime.now()
        end_of_week = today + timedelta(days=(6 - today.weekday()))
        end_of_week = datetime(end_of_week.year, end_of_week.month, end_of_week.day, 23, 59, 59)
        group.clear_temporary_schedule_at = end_of_week
        group.save()
    
    # Send notifications to students and their parents
    students = group.students.all()
    
    for student in students:
        # Create notification for each student
        student_message = f"Le professeur {teacher.fullname} a modifié l'horaire du cours de {group.subject.name} à : {group.week_day} de {group.start_time_range} à {group.end_time_range} {'seulement cette semaine' if change_type == 'temporary' else 'de façon permanente'}."
        StudentNotification.objects.create(
            student=student,
            image=teacher.image,
            message=student_message
        )


        # If student has parents, notify them too
        for son in student.sons.all() :
            # Assuming `son` has an attribute `gender` that can be 'male' or 'female'
            child_pronoun = "votre fils" if son.gender == "male" else "votre fille"
            parent_message = f"Le professeur {teacher.fullname} a modifié l'horaire du cours de {group.subject.name} de {child_pronoun} {son.fullname} à : {group.week_day} de {group.start_time_range} à {group.end_time_range} {'seulement cette semaine' if change_type == 'temporary' else 'de façon permanente'}."
            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
            )

    return JsonResponse({
        'status': 'success',
        'message': 'Group schedule updated successfully',
    })
