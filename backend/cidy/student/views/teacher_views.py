from django.core.paginator import Paginator
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from teacher.models import Teacher,Subject,TeacherNotification
from teacher.serializers import SubjectSerializer
from common.tools import increment_teacher_unread_notifications
from ..serializers import TeacherListSerializer



@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_student_possible_subjects(request):
    """Get all of the subjects that the student can study for his level and section."""
    student = request.user.student
    student_level = student.level
    student_section = student.section

    # Filter subjects based on the student's level and section
    subjects = Subject.objects.filter(
        level=student_level,
        section=student_section if student_section else None
    )

    serializer = SubjectSerializer(subjects, many=True)

    return Response({'subjects': serializer.data})

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
    if not student_section : 
        teachers = Teacher.objects.filter(
            teachersubject_set__level=student_level,
            teachersubject_set__section__isnull=True
        ).distinct()
    else :
        teachers = Teacher.objects.filter(
            teachersubject_set__level=student_level,
            teachersubject_set__section=student_section
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

    return Response({
        'teachers': serializer.data,
        'total_count': paginator.count,
        'current_page': page
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_a_student_request(request, teacher_id):
    """Send a student request notification to a teacher"""
    student = request.user.student
    requested_teacher_subjects = request.data.get('requested_teacher_subjects', [])

    try : 
        teacher = Teacher.objects.get(id=teacher_id)
    except Teacher.DoesNotExist:
        return Response({'status': 'error', 'message': 'Teacher not found'}, status=404)

    requested_subject_names = [subject['name'] for subject in requested_teacher_subjects]
    TeacherNotification.objects.create(
        teacher=teacher,
        image=student.image,
        message=f"l'étudiant {student.fullname} de niveau {student.level} {student.section if student.section else ''} veut s'inscrire dans la/les matière(s) suivante(s) : {', '.join(requested_subject_names)}.",
        meta_data={'student_id': student.id, 'requested_teacher_subjects': requested_teacher_subjects}
    )
    increment_teacher_unread_notifications(teacher)

    return Response({'status': 'success', 'message': 'Student request sent successfully to the teacher'})