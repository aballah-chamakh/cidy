from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from ..models import Class, Group, GroupEnrollment, TeacherSubject
from student.models import Student
from datetime import datetime, timedelta,date 


def get_date_range(range_preset):
    """Helper function to convert preset to actual date range (returns dates only)"""
    today = date.today()  # use date object directly

    if range_preset == 'this_week':
        # Start of current week (Monday)
        start_date = today - timedelta(days=today.weekday())
        end_date = today
    elif range_preset == 'this_year':
        start_date = date(today.year, 1, 1)
        end_date = today
    else:  # default to this_month
        start_date = date(today.year, today.month, 1)
        end_date = today

    return start_date, end_date

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_dashboard_data(request):
    teacher = request.user.teacher
    
    # Check if teacher has groups
    # Get all teacher subjects of the teacher
    teacher_subjects = TeacherSubject.objects.filter(teacher=teacher)  

    if not teacher_subjects.exists():
        return Response({
            'has_levels': False
        })
    
    # Parse date parameters from request
    start_date_param = request.GET.get('start_date')
    end_date_param = request.GET.get('end_date')
    date_range_preset = request.GET.get('date_range')
    print(f"start_date_param : {start_date_param}")
    print(f"end_date_param : {end_date_param}")
    # If explicit start and end dates are provided, use them
    if start_date_param and end_date_param:
        start_date = datetime.fromisoformat(start_date_param)
        end_date = datetime.fromisoformat(end_date_param)
        # Add time to end_date to include the full day
        #end_date = datetime.combine(end_date, datetime.max.time())
    elif date_range_preset: # this month, this week ...
        # Use preset if no explicit dates
        start_date, end_date = get_date_range(date_range_preset)
    else : 
        start_date = None 
        end_date = None
    
    print(type(start_date))
    print(type(end_date))
    print('Start Date:', start_date)
    print('End Date:', end_date)

    dashboard = {
        'total_paid_amount': 0,
        'total_unpaid_amount': 0,
        'total_active_students': 0,
        'levels' : {}
    }
    # kpis description : 
    # - total paid amount : total paid amount  of classes paid in the date range (the classes paid in the date range can be of students enrolled before the start date)
    # - total unpaid amount : total unpaid amount of classes attended in the date range and their paymen is due 
    # - total active students : total distinct students enrolled in the groups of the teacher in the date range

    # get the enrollments of the students in the groups of the teacher in the date range
    teacher_group_enrollments = GroupEnrollment.objects.filter(group__teacher=teacher)
    if start_date and end_date:
        teacher_group_enrollments = teacher_group_enrollments.filter(date__gte=start_date, date__lte=end_date)
    
    # add distinct to avoid counting same student multiple times if enrolled in multiple groups
    students_cnt = teacher_group_enrollments.distinct('student').count()
    dashboard['total_active_students'] = students_cnt

    # for each teacher subject of the teacher, calculate its kpis :
    # number of active students, paid amount, unpaid amount
    for teacher_subject in teacher_subjects:
        # Get all group enrollments of the groups of this teacher subject
        teacher_subject_group_enrollments = GroupEnrollment.objects.filter(
            group__teacher_subject=teacher_subject,
        )

        # if the date range is specified, filter the group enrollments only by the end date 
        # because the student can be enrolled before the start date but has paid and attended classes in the date range 
        # but for the students enrolled after the end date they can't have attended or paid for classes in the date range

        if end_date : 
            print("Filtering group enrollments by end date : ", end_date)
            teacher_subject_group_enrollments = teacher_subject_group_enrollments.filter(
                date__lte=end_date
            )
        
        
        # note: i distinct here to avoid counting same student multiple times if enrolled in multiple groups of same subject
        active_students_count = teacher_subject_group_enrollments.filter(**({"date__gte": start_date} if start_date else {} )).distinct('student').count()
        paid_amount = 0 
        unpaid_amount = 0
        class_price = teacher_subject.price_per_class

        # i didn't loop through the teacher_subject_group_enrollments distincted by student
        # because i need to calculate the paid and unpaid amounts of all of the enrollments of the students 
        for teacher_subject_group_enrollment in teacher_subject_group_enrollments:
            
            paid_classes_of_teacher_subject = Class.objects.filter(
                group_enrollment=teacher_subject_group_enrollment,
                status='attended_and_paid'
            )

            unpaid_classes_of_teacher_subject = Class.objects.filter(
                group_enrollment=teacher_subject_group_enrollment,
                status='attended_and_the_payment_due'
            )
            
            if start_date and end_date:
                paid_classes_of_teacher_subject = paid_classes_of_teacher_subject.filter(
                    paid_at__date__gte=start_date, paid_at__date__lte=end_date)
                
                unpaid_classes_of_teacher_subject = unpaid_classes_of_teacher_subject.filter(
                    attendance_date__gte=start_date, attendance_date__lte=end_date)


            paid_amount += paid_classes_of_teacher_subject.count() * class_price
            unpaid_amount += unpaid_classes_of_teacher_subject.count() * class_price

        teacher_subject_level = teacher_subject.level.name
        teacher_subject_section = teacher_subject.level.section if teacher_subject.level.section else None
        teacher_subject_subject = teacher_subject.subject.name 

        # add to the dashboard the the kpis of this teacher subject
        dashboard['total_paid_amount'] += paid_amount
        dashboard['total_unpaid_amount'] += unpaid_amount

        dashboard['levels'][teacher_subject_level] = dashboard['levels'].get(teacher_subject_level, {
            'total_paid_amount': 0,
            'total_unpaid_amount': 0,
            'total_active_students': GroupEnrollment.objects.filter(group__teacher=teacher, group__teacher_subject__level__name=teacher_subject.level.name,**({"date__gte": start_date,"date__lte": end_date} if start_date and end_date else {} )).distinct('student').count(),
        })
        dashboard['levels'][teacher_subject_level]['total_paid_amount'] += paid_amount
        dashboard['levels'][teacher_subject_level]['total_unpaid_amount'] += unpaid_amount
        #note : i can't add active_students_count to the level total_active_students this way because 
        #       active_students_count can be the same students for different subjects of the same level
        #dashboard['levels'][teacher_subject_level]['total_active_students'] += active_students_count
        
        if teacher_subject_section :
            dashboard['levels'][teacher_subject_level]['sections'] = dashboard['levels'][teacher_subject_level].get('sections', {})
            dashboard['levels'][teacher_subject_level]['sections'][teacher_subject_section] = dashboard['levels'][teacher_subject_level]['sections'].get(teacher_subject_section, {
                'total_paid_amount': 0,
                'total_unpaid_amount': 0,
                'total_active_students': GroupEnrollment.objects.filter(group__teacher=teacher, group__teacher_subject__level=teacher_subject.level,**({"date__gte": start_date,"date__lte": end_date} if start_date and end_date else {} )).distinct('student').count()
            })
            dashboard['levels'][teacher_subject_level]['sections'][teacher_subject_section]['total_paid_amount'] += paid_amount
            dashboard['levels'][teacher_subject_level]['sections'][teacher_subject_section]['total_unpaid_amount'] += unpaid_amount
            # note : i can't add active_students_count to the section total_active_students this way because
            #        active_students_count can be the same students for different subjects of the same section
            #dashboard['levels'][teacher_subject_level]['sections'][teacher_subject_section]['total_active_students'] += active_students_count

            dashboard['levels'][teacher_subject_level]['sections'][teacher_subject_section]['subjects'] = dashboard['levels'][teacher_subject_level]['sections'][teacher_subject_section].get('subjects', {})
            dashboard['levels'][teacher_subject_level]['sections'][teacher_subject_section]['subjects'][teacher_subject_subject] = dashboard['levels'][teacher_subject_level]['sections'][teacher_subject_section]['subjects'].get(teacher_subject_subject, {
                'total_paid_amount': 0,
                'total_unpaid_amount': 0,
                'total_active_students': 0
            })
            dashboard['levels'][teacher_subject_level]['sections'][teacher_subject_section]['subjects'][teacher_subject_subject]['total_paid_amount'] += paid_amount
            dashboard['levels'][teacher_subject_level]['sections'][teacher_subject_section]['subjects'][teacher_subject_subject]['total_unpaid_amount'] += unpaid_amount
            dashboard['levels'][teacher_subject_level]['sections'][teacher_subject_section]['subjects'][teacher_subject_subject]['total_active_students'] += active_students_count
        else : 
            dashboard['levels'][teacher_subject_level]['subjects'] = dashboard['levels'][teacher_subject_level].get('subjects', {})
            dashboard['levels'][teacher_subject_level]['subjects'][teacher_subject_subject] = dashboard['levels'][teacher_subject_level]['subjects'].get(teacher_subject_subject, {
                'total_paid_amount': 0,
                'total_unpaid_amount': 0,
                'total_active_students': 0
            })
            dashboard['levels'][teacher_subject_level]['subjects'][teacher_subject_subject]['total_paid_amount'] += paid_amount
            dashboard['levels'][teacher_subject_level]['subjects'][teacher_subject_subject]['total_unpaid_amount'] += unpaid_amount
            dashboard['levels'][teacher_subject_level]['subjects'][teacher_subject_subject]['total_active_students'] += active_students_count
    #print(dashboard)
    return Response({
        'has_levels': True,
        'dashboard': dashboard
    })
