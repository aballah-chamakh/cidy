from django.http import JsonResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from .models import Class, TeacherNotification, Group, Enrollment, TeacherSubject
from student.models import StudentNotification
from parent.models import ParentNotification
from datetime import datetime, timedelta

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_unread_notifications_count(request):
    teacher = request.user.teacher
    count = TeacherNotification.objects.filter(teacher=teacher, read=False).count()
    return JsonResponse({'unread_count': count})

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def reset_notification_count(request):
    last_notification_id = request.data.get('last_notification_id')
    teacher = request.user.teacher
    TeacherNotification.objects.filter(
        teacher=teacher,
        id__lte=last_notification_id
    ).update(is_read=True)
    return JsonResponse({'status': 'success'})


def get_date_range(range_preset):
    """Helper function to convert preset to actual date range"""
    today = datetime.now()
    
    if range_preset == 'this_week':
        # Start of current week (Monday)
        start_date = today - timedelta(days=today.weekday())
        start_date = datetime(start_date.year, start_date.month, start_date.day)
        end_date = today
    elif range_preset == 'this_year':
        start_date = datetime(today.year, 1, 1)
        end_date = today
    else:  # default to this_month
        start_date = datetime(today.year, today.month, 1)
        end_date = today
    
    return start_date, end_date

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_dashboard_data(request):
    teacher = request.user.teacher
    
    # Check if teacher has groups
    has_groups = Group.objects.filter(teacher=teacher).exists()
    
    if not has_groups:
        return JsonResponse({
            'has_groups': False
        })
    
    # Parse date parameters from request
    start_date_param = request.GET.get('start_date')
    end_date_param = request.GET.get('end_date')
    date_range_preset = request.GET.get('date_range', 'this_month')
    
    # If explicit start and end dates are provided, use them
    if start_date_param and end_date_param:
            start_date = datetime.strptime(start_date_param, '%Y-%m-%d')
            end_date = datetime.strptime(end_date_param, '%Y-%m-%d')
            # Add time to end_date to include the full day
            end_date = datetime.combine(end_date.date(), datetime.max.time())
    elif date_range_preset:
        # Use preset if no explicit dates
        start_date, end_date = get_date_range(date_range_preset)
    else : 
        start_date = None 
        end_date = None
    
    # Get all active enrollments within date range   
    enrollments = Enrollment.objects.filter(
        group__teacher=teacher
    )
    if end_date :
        enrollments = enrollments.filter(date__lte=end_date)

    dashboard = {
        'total_paid_amount': 0,
        'total_unpaid_amount': 0,
        'total_active_students': enrollments.count(),
        'levels' : {}
    }
    for enrollment in enrollments:
        group = enrollment.group
        paid_classes_of_this_enrollment = Class.objects.filter(
            batch__enrollment=enrollment,
            status='attended_and_paid'
        )
        if start_date:
            paid_classes_of_this_enrollment = paid_classes_of_this_enrollment.filter(
            last_status_update__gte=start_date
            )
        if end_date:
            paid_classes_of_this_enrollment = paid_classes_of_this_enrollment.filter(
            last_status_update__lte=end_date
            )
        teacher_subject = TeacherSubject.objects.get(teacher=teacher, 
                                                        level=group.level,
                                                        section=group.section,
                                                        subject=group.subject)
        class_price = teacher_subject.price
        dashboard['total_paid_amount'] += paid_classes_of_this_enrollment.count() * class_price
        dashboard['total_unpaid_amount'] += enrollment.finance.unpaid_amount

        dashboard['levels'][group.level.name] = dashboard['levels'].get(group.level.name, {
            'total_paid_amount': 0,
            'total_unpaid_amount': 0,
            'total_active_students': 0
        })
        dashboard['levels'][group.level.name]['total_paid_amount'] += paid_classes_of_this_enrollment.count() * class_price
        dashboard['levels'][group.level.name]['total_unpaid_amount'] += enrollment.finance.unpaid_amount
        dashboard['levels'][group.level.name]['total_active_students'] += 1
        if group.section :
            dashboard['levels'][group.level.name]['sections'] = dashboard['levels'][group.level.name].get('sections', {})
            dashboard['levels'][group.level.name]['sections'][group.section.name] = dashboard['levels'][group.level.name]['sections'].get(group.section.name, {
                'total_paid_amount': 0,
                'total_unpaid_amount': 0,
                'total_active_students': 0
            })
            dashboard['levels'][group.level.name]['sections'][group.section.name]['total_paid_amount'] += paid_classes_of_this_enrollment.count() * class_price
            dashboard['levels'][group.level.name]['sections'][group.section.name]['total_unpaid_amount'] += enrollment.finance.unpaid_amount
            dashboard['levels'][group.level.name]['sections'][group.section.name]['total_active_students'] += 1

            dashboard['levels'][group.level.name]['sections'][group.section.name]['subjects'] = dashboard['levels'][group.level.name]['sections'][group.section.name].get('subjects', {})
            dashboard['levels'][group.level.name]['sections'][group.section.name]['subjects'][group.subject.name] = dashboard['levels'][group.level.name]['sections'][group.section.name]['subjects'].get(group.subject.name, {
                'total_paid_amount': 0,
                'total_unpaid_amount': 0,
                'total_active_students': 0
            })
            dashboard['levels'][group.level.name]['sections'][group.section.name]['subjects'][group.subject.name]['total_paid_amount'] += paid_classes_of_this_enrollment.count() * class_price
            dashboard['levels'][group.level.name]['sections'][group.section.name]['subjects'][group.subject.name]['total_unpaid_amount'] += enrollment.finance.unpaid_amount
            dashboard['levels'][group.level.name]['sections'][group.section.name]['subjects'][group.subject.name]['total_active_students'] += 1

    return JsonResponse({
        'has_groups': True,
        'dashboard': dashboard
    })

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
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_group_schedule(request, group_id):
    """
    Update a group's schedule - handles both permanent and temporary changes
    """
    teacher = request.user.teacher
    
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return JsonResponse({'error': 'Group not found'}, status=404)
    
    # Get data from request
    new_day = request.data.get('week_day')
    new_start_time_range = request.data.get('start_time_range')
    new_end_time_range = request.data.get('end_time_range')
    change_type = request.data.get('change_type')  # 'permanent' or 'temporary'

    if not new_day or not new_start_time_range or not new_end_time_range or not change_type:
        return JsonResponse({'error': 'Missing required fields'}, status=400)
    
    if change_type not in ['permanent', 'temporary']:
        return JsonResponse({'error': 'Invalid change type'}, status=400)
    
    # Check for schedule conflicts with other groups
    # Exclude current group from check
    conflicting_groups = Group.objects.filter(
        teacher=teacher,
        week_day=new_day,
        start_time_range__lte=new_start_time_range,
        end_time_range__gte=new_end_time_range
    ).exclude(id=group.id)
    
    if conflicting_groups.exists():
        return JsonResponse({
            'error': 'Schedule conflict detected',
            'conflicting_groups': [g.name for g in conflicting_groups]
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
        'change_type': change_type
    })





