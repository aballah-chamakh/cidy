from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from ..models import Class, Group, GroupEnrollment, TeacherSubject
from student.models import Student
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
        return Response({
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
    elif date_range_preset: # this month, this week ...
        # Use preset if no explicit dates
        start_date, end_date = get_date_range(date_range_preset)
    else : 
        start_date = None 
        end_date = None
    
    # Get the students enrolled in at least one of groups of the teacher
    students = Student.objects.filter(
        groups__teacher=teacher
    ).distinct()

    # get the active students in the selected daterange
    # notes : 
    #   we did filter only by the end_date because we want the cumulative number of active students until 
    #   the selected end_date and we don't want only the students joined in selected date range, so to get 
    #   the active students in the selected daterange we need to get all of the student joined maximun 
    #   at the select end_date.
    if end_date :
        students = students.filter(groupenrollment__date__lte=end_date).distinct()

    dashboard = {
        'total_paid_amount': 0,
        'total_unpaid_amount': 0,
        'total_active_students': students.count(),
        'levels' : {}
    }

    for student in students :

        student_group_enrollments = student.groupenrollment_set.all()

        # since the student can have group enrollment that surpass the end_date we have to filter 
        # student group enrollements by the end_date if the client specify it 
        if end_date : 
            student_group_enrollments.filter(date__lte=end_date)

        for student_group_enrollment in student_group_enrollments : 
            
            # get paid classes
            paid_classes_of_student_group_enrollment = student_group_enrollment.class_set.filter(status='attended_and_paid')

            # get unpaid classes 
            unpaid_classes_of_student_group_enrollment = student_group_enrollment.class_set.filter(status='attended_and_the_payment_due')

            # filter the paid and the unpaid classes by the start_date
            if start_date:
                paid_classes_of_student_group_enrollment = paid_classes_of_student_group_enrollment.filter(
                    last_status_date__gte=start_date
                )
                unpaid_classes_of_student_group_enrollment = unpaid_classes_of_student_group_enrollment.filter(
                    last_status_date__gte=start_date
                )

            # filter the paid and the unpaid classes by the end_date
            if end_date:
                paid_classes_of_student_group_enrollment = paid_classes_of_student_group_enrollment.filter(
                    last_status_date__lte=end_date
                )
                unpaid_classes_of_student_group_enrollment = unpaid_classes_of_student_group_enrollment.filter(
                    last_status_date__lte=end_date
                )

            teacher_subject = student_group_enrollment.group.teacher_subject 
            class_price = teacher_subject.price_per_class
            student_group_enrollment_level = teacher_subject.level.name
            student_group_enrollment_section = teacher_subject.section.name if teacher_subject.section else None    
            student_group_enrollment_subject = teacher_subject.subject.name 

            dashboard['total_paid_amount'] += paid_classes_of_student_group_enrollment.count() * class_price
            dashboard['total_unpaid_amount'] += unpaid_classes_of_student_group_enrollment.count() * class_price

            dashboard['levels'][student_group_enrollment_level] = dashboard['levels'].get(student_group_enrollment_level, {
                'total_paid_amount': 0,
                'total_unpaid_amount': 0,
                'total_active_students': 0
            })
            dashboard['levels'][student_group_enrollment_level]['total_paid_amount'] += dashboard['total_paid_amount']
            dashboard['levels'][student_group_enrollment_level]['total_unpaid_amount'] += dashboard['total_unpaid_amount']
            dashboard['levels'][student_group_enrollment_level]['total_active_students'] += 1
            
            if student_group_enrollment_section :
                dashboard['levels'][student_group_enrollment_level]['sections'] = dashboard['levels'][student_group_enrollment_level].get('sections', {})
                dashboard['levels'][student_group_enrollment_level]['sections'][student_group_enrollment_section] = dashboard['levels'][student_group_enrollment_level]['sections'].get(student_group_enrollment_section, {
                    'total_paid_amount': 0,
                    'total_unpaid_amount': 0,
                    'total_active_students': 0
                })
                dashboard['levels'][student_group_enrollment_level]['sections'][student_group_enrollment_section]['total_paid_amount'] += dashboard['total_paid_amount']
                dashboard['levels'][student_group_enrollment_level]['sections'][student_group_enrollment_section]['total_unpaid_amount'] += dashboard['total_unpaid_amount']
                dashboard['levels'][student_group_enrollment_level]['sections'][student_group_enrollment_section]['total_active_students'] += 1

                dashboard['levels'][student_group_enrollment_level]['sections'][student_group_enrollment_section]['subjects'] = dashboard['levels'][student_group_enrollment_level]['sections'][student_group_enrollment_section].get('subjects', {})
                dashboard['levels'][student_group_enrollment_level]['sections'][student_group_enrollment_section]['subjects'][student_group_enrollment_subject] = dashboard['levels'][student_group_enrollment_level]['sections'][student_group_enrollment_section]['subjects'].get(student_group_enrollment_subject, {
                    'total_paid_amount': 0,
                    'total_unpaid_amount': 0,
                    'total_active_students': 0
                })
                dashboard['levels'][student_group_enrollment_level]['sections'][student_group_enrollment_section]['subjects'][student_group_enrollment_subject]['total_paid_amount'] += dashboard['total_paid_amount']
                dashboard['levels'][student_group_enrollment_level]['sections'][student_group_enrollment_section]['subjects'][student_group_enrollment_subject]['total_unpaid_amount'] += dashboard['total_unpaid_amount']
                dashboard['levels'][student_group_enrollment_level]['sections'][student_group_enrollment_section]['subjects'][student_group_enrollment_subject]['total_active_students'] += 1
    print(dashboard)
    return Response({
        'has_groups': True,
        'dashboard': dashboard
    })
