from django.http import JsonResponse
from django.core.paginator import Paginator
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from teacher.models import Teacher, TeacherSubject,Subject
from teacher.serializers.price_serializers import SubjectSerializer
from student.models import Student, StudentNotification
from common.tools import increment_teacher_unread_notifications
from ..serializers import TeacherListSerializer



@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_student_possible_subjects(request):
    """Get all subjects available for the student's level and section."""
    student = request.user.student
    student_level = student.level
    student_section = student.section

    # Filter subjects based on the student's level and section
    subjects = Subject.objects.filter(
        level=student_level,
        section=student_section if student_section else None
    )

    serializer = SubjectSerializer(subjects, many=True)

    return JsonResponse({'subjects': serializer.data})

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_teachers(request):
    """Get a filtered and paginated list of teachers for the logged student"""
    student = request.user.student
    fullname_filter = request.GET.get('fullname', '')
    subject_ids = request.GET.getlist('subject_ids', [])
    
    # Get the level and section of the student
    student_level = student.level
    student_section = student.section

    # Filter teachers based on level and section of the student 
    teachers = Teacher.objects.filter(
        teachersubject_set__level=student_level,
        teachersubject_set__section=student_section if student_section else None
    ).distinct()

    # Apply fullname filter
    if fullname_filter:
        teachers = teachers.filter(fullname__icontains=fullname_filter)

    # Apply subject filter
    if subject_ids:
        teachers = teachers.filter(teachersubject_set__subject__id__in=subject_ids).distinct()

    # Pagination
    page = request.GET.get('page', 1)
    page_size = 30
    paginator = Paginator(teachers, page_size)
    try:
        paginated_teachers = paginator.page(page)
    except Exception:
        paginated_teachers = paginator.page(paginator.num_pages)
        page = paginator.num_pages

    # Serialize the teachers
    serializer = TeacherListSerializer(paginated_teachers, many=True, context={'student':student} )

    return JsonResponse({
        'teachers': serializer.data,
        'total_count': paginator.count,
        'current_page': page
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def enroll_in_subjects(request, teacher_id):
    """Send an enrollment request notification to a teacher"""
    student = request.user.student
    subjects_to_enroll = request.data.get('subject_ids', [])

    if not subjects_to_enroll:
        return JsonResponse({'status': 'error', 'message': 'At least one subject must be selected'}, status=400)

    try:
        teacher = Teacher.objects.get(id=teacher_id)
    except Teacher.DoesNotExist:
        return JsonResponse({'status': 'error', 'message': 'Teacher not found'}, status=404)

    # Filter out subjects the student is already studying with this teacher
    existing_subject_ids = TeacherSubject.objects.filter(
        teacher=teacher,
        group__groupenrollment__student=student
    ).values_list('subject__id', flat=True)
    subjects_to_enroll = [sub_id for sub_id in subjects_to_enroll if sub_id not in existing_subject_ids]

    if not subjects_to_enroll:
        return JsonResponse({'status': 'error', 'message': 'No new subjects to enroll in'}, status=400)

    # Create a notification for the teacher
    subject_names = TeacherSubject.objects.filter(id__in=subjects_to_enroll).values_list('subject__name', flat=True)
    message = f"{student.fullname} has requested to enroll in the following subjects: {', '.join(subject_names)}"
    StudentNotification.objects.create(
        student=student,
        teacher=teacher,
        message=message,
        meta_data={'subject_ids': subjects_to_enroll}
    )
    increment_teacher_unread_notifications(teacher)

    return JsonResponse({'status': 'success', 'message': 'Enrollment request sent successfully'})