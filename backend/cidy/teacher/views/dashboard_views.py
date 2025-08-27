from django.http import JsonResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from ..models import Class, Group, GroupEnrollment, TeacherSubject
from datetime import datetime, timedelta


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
    
    # Get all active group_enrollments within date range   
    group_enrollments = GroupEnrollment.objects.filter(
        group__teacher=teacher
    )
    if end_date :
        group_enrollments = group_enrollments.filter(date__lte=end_date)

    dashboard = {
        'total_paid_amount': 0,
        'total_unpaid_amount': 0,
        'total_active_students': group_enrollments.count(),
        'levels' : {}
    }
    for group_enrollment in group_enrollments:
        group = group_enrollment.group
        paid_classes_of_this_group_enrollment = Class.objects.filter(
            group_enrollment=group_enrollment,
            status='attended_and_paid'
        )
        if start_date:
            paid_classes_of_this_group_enrollment = paid_classes_of_this_group_enrollment.filter(
            last_status_update__gte=start_date
            )
        if end_date:
            paid_classes_of_this_group_enrollment = paid_classes_of_this_group_enrollment.filter(
            last_status_update__lte=end_date
            )
        teacher_subject = TeacherSubject.objects.get(teacher=teacher, 
                                                        level=group.level,
                                                        section=group.section,
                                                        subject=group.subject)
        class_price = teacher_subject.price
        dashboard['total_paid_amount'] += paid_classes_of_this_group_enrollment.count() * class_price
        dashboard['total_unpaid_amount'] += group_enrollment.unpaid_amount

        dashboard['levels'][group.level.name] = dashboard['levels'].get(group.level.name, {
            'total_paid_amount': 0,
            'total_unpaid_amount': 0,
            'total_active_students': 0
        })
        dashboard['levels'][group.level.name]['total_paid_amount'] += paid_classes_of_this_group_enrollment.count() * class_price
        dashboard['levels'][group.level.name]['total_unpaid_amount'] += group_enrollment.unpaid_amount
        dashboard['levels'][group.level.name]['total_active_students'] += 1
        if group.section :
            dashboard['levels'][group.level.name]['sections'] = dashboard['levels'][group.level.name].get('sections', {})
            dashboard['levels'][group.level.name]['sections'][group.section.name] = dashboard['levels'][group.level.name]['sections'].get(group.section.name, {
                'total_paid_amount': 0,
                'total_unpaid_amount': 0,
                'total_active_students': 0
            })
            dashboard['levels'][group.level.name]['sections'][group.section.name]['total_paid_amount'] += paid_classes_of_this_group_enrollment.count() * class_price
            dashboard['levels'][group.level.name]['sections'][group.section.name]['total_unpaid_amount'] += group_enrollment.unpaid_amount
            dashboard['levels'][group.level.name]['sections'][group.section.name]['total_active_students'] += 1

            dashboard['levels'][group.level.name]['sections'][group.section.name]['subjects'] = dashboard['levels'][group.level.name]['sections'][group.section.name].get('subjects', {})
            dashboard['levels'][group.level.name]['sections'][group.section.name]['subjects'][group.subject.name] = dashboard['levels'][group.level.name]['sections'][group.section.name]['subjects'].get(group.subject.name, {
                'total_paid_amount': 0,
                'total_unpaid_amount': 0,
                'total_active_students': 0
            })
            dashboard['levels'][group.level.name]['sections'][group.section.name]['subjects'][group.subject.name]['total_paid_amount'] += paid_classes_of_this_group_enrollment.count() * class_price
            dashboard['levels'][group.level.name]['sections'][group.section.name]['subjects'][group.subject.name]['total_unpaid_amount'] += group_enrollment.unpaid_amount
            dashboard['levels'][group.level.name]['sections'][group.section.name]['subjects'][group.subject.name]['total_active_students'] += 1

    return JsonResponse({
        'has_groups': True,
        'dashboard': dashboard
    })
