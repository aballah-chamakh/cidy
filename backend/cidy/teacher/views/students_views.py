from datetime import datetime

from django.http import JsonResponse
from rest_framework.permissions import IsAuthenticated
from rest_framework.decorators import api_view, permission_classes
from django.db.models import Q, Sum
from django.core.paginator import Paginator
from ..models import Group, GroupEnrollment, TeacherSubject,TeacherEnrollment,Class
from student.models import Student, StudentNotification
from parent.models import ParentNotification
from ..serializers import TeacherLevelsSectionsSubjectsHierarchySerializer,TeacherStudentListSerializer,TeacherStudentCreateSerializer
from rest_framework import serializers

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def can_create_student(request):
    """Check if a teacher has the ability to create a new student"""
    teacher = request.user.teacher
    
    # Check if teacher has any level with subjects
    has_level_with_subjects = TeacherSubject.objects.filter(teacher=teacher).exists()
    
    if not has_level_with_subjects:
        return JsonResponse({
            'can_create': False,
            'message': 'You need to set up at least one level with subjects in the Prices screen before creating a student.'
        })
    
    return JsonResponse({
        'can_create': True
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_students(request):
    """Get a filtered list of students for the teacher"""
    teacher = request.user.teacher
    students = Student.objects.filter(teacherenrollment_set__teacher=teacher)

    # Apply fullname filter
    fullname = request.GET.get('fullname', '')
    if fullname:
        students = students.filter(fullname__icontains=fullname)

    # Apply level filter
    level_id = request.GET.get('level')
    if level_id and level_id.isdigit():
        students = students.filter(level__id=int(level_id))

    # Apply section filter
    section_id = request.GET.get('section')
    if section_id and section_id.isdigit():
        students = students.filter(section__id=int(section_id))

    # Apply subject filter
    subject_id = request.GET.get('subject')
    if subject_id and subject_id.isdigit():
        students = students.filter(groupenrollement_set__group__subject__id=int(subject_id)).distinct()

    # add the paid and unpaid amounts fields 
    students = students.annotate(
                paid_amount=Sum('teacherenrollment_set__paid_amount', filter=Q(teacherenrollment_set__teacher=teacher)),
                unpaid_amount=Sum('teacherenrollment_set__unpaid_amount', filter=Q(teacherenrollment_set__teacher=teacher))
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
    # Pagination
    page = request.GET.get('page', 1)
    page_size = request.GET.get('page_size', 30)
    paginator = Paginator(students, page_size)
    try:
        paginated_students = paginator.page(page)
    except Exception:
        # If page is out of range, deliver last page
        paginated_students = paginator.page(paginator.num_pages)

    # Serialize the students
    serializer = TeacherStudentListSerializer(paginated_students, many=True, context={'request': request})

    # Get teacher levels, sections, and subjects hierarchy for filter options
    teacher_subjects = TeacherSubject.objects.filter(teacher=teacher).select_related('level', 'section', 'subject')
    teacher_levels_sections_subjects_hierarchy = TeacherLevelsSectionsSubjectsHierarchySerializer(teacher_subjects, many=True)

    return JsonResponse({
        'students_total_count': paginator.count,
        'students': serializer.data,
        'teacher_levels_sections_subjects_hierarchy': teacher_levels_sections_subjects_hierarchy.data
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_student(request):
    """Create a new student"""

    serializer = TeacherStudentCreateSerializer(data=request.data)
    if serializer.is_valid():
        student = serializer.save()
        teacher = request.user.teacher
        TeacherEnrollment.objects.create(
            student=student,
            teacher=teacher,
        )
        return JsonResponse({
            'success': True,
            'message': 'Student created successfully.',
        })
    
    return JsonResponse({
        'success': False,
        'message': 'Failed to create student.',
        'errors': serializer.errors
    }, status=400)

@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_students(request):
    """Delete selected students"""
    teacher = request.user.teacher
    student_ids = request.data.get('student_ids', [])

    if not student_ids:
        return JsonResponse({
            'success': False,
            'message': 'No students selected for deletion.'
        }, status=400)

    students = Student.objects.filter(id__in=student_ids)
    if not students.exists():
        return JsonResponse({
            'success': False,
            'message': 'Selected students do not exist.'
        }, status=404)

    student_teacher_pronoun = "Votre professeur" if teacher.gender == "male" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "male" else "La professeure"
    
    for student in students:
        # Check if the student has his independent account
        if student.user:
            # delete the enrollment with this teacher and the enrollments in the groups of this teacher
            TeacherEnrollment.objects.filter(student=student, teacher=teacher).delete()
            GroupEnrollment.objects.filter(student=student, group__teacher=teacher).delete()

            # send a notification to the student
            student_message = f"{student_teacher_pronoun} {teacher.fullname} a mis fin à votre relation."
            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message,
            )

        # send a notification to the parent of the sons attached to each student to delete
        child_pronoun = "votre fils" if son.gender == "male" else "votre fille"
        parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a mis fin à la relation avec {child_pronoun} {son.fullname}."
        for son in student.sons : 
            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
                meta_data = {"son_id":son.id}
            )

        # i deleted him here because i want to get its sons before
        if not student.user:
            student.delete()

        return JsonResponse({
            'success': True,
            'message': f'{len(student_ids)} students were deleted.'
        })




@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def mark_attendance_of_a_student(request,student_id,group_id):
    """Mark attendance for a students in a group"""

    attendance_date = request.data.get('attendance_date')
    attendance_start_time = request.data.get('attendance_start_time')
    attendance_end_time = request.data.get('attendance_end_time')

    if not attendance_date or not attendance_start_time or not attendance_end_time:
        return JsonResponse({'error': 'Date and time range are required for the "specify" option'}, status=400)

    attendance_date = datetime.strptime(attendance_date, "%d/%m/%Y").date()
    attendance_start_time = datetime.strptime(attendance_start_time, "%H:%M").time()
    attendance_end_time = datetime.strptime(attendance_end_time, "%H:%M").time()

    teacher = request.user.teacher

    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return JsonResponse({'error': 'Group not found'}, status=404)
    try : 
        student = Student.objects.get(id=student_id)
    except Student.DoesNotExist:
        return JsonResponse({'error': 'Student not enrolled in this group'}, status=404)
    
    try:
        student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
    except GroupEnrollment.DoesNotExist:
        return JsonResponse({'error': 'Student is not enrolled in this group'}, status=404)

    teacher_subject = TeacherSubject.objects.filter(teacher=teacher,level=group.level,section=group.section,subject=group.subject).first()

    if student_group_enrollment.attended_non_paid_classes >= 3 : 
        # only when i have 3 non paid classes, mark them as attended_and_the_payment_due  because since then we will mark the next class as attended_and_the_payment_due
        if student_group_enrollment.attended_non_paid_classes == 3 :
            Class.objects.filter(group_enrollment=student_group_enrollment, status='attended_and_the_payment_not_due').update(status='attended_and_the_payment_due')
            student_group_enrollment.unpaid_amount += teacher_subject.price_per_class * 3
        # create the next class as attended_and_the_payment_due
        Class.objects.create(enrollement=student_group_enrollment,
                            attendance_date=attendance_date,
                            attendance_start_time=attendance_start_time,
                            attendance_end_time=attendance_end_time,
                            status = 'attended_and_the_payment_due')
        student_group_enrollment.unpaid_amount += teacher_subject.price_per_class
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
        student_teacher_pronoun = "Votre professeur" if teacher.gender == "male" else "Votre professeure"
        student_message = f"{student_teacher_pronoun} {teacher.fullname} vous a marqué comme présent(e) dans le cours de {group.subject.name} le {attendance_date.strftime('%d/%m/%Y')} de {attendance_start_time.strftime('%H:%M')} à {attendance_end_time.strftime('%H:%M')}."
        StudentNotification.objects.create(
            student=student,
            image=teacher.image,
            message=student_message,
            meta_data={"group_id": group.id}
        )

    # Notify the parents
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "male" else "La professeure"
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