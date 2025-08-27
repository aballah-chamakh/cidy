from django.http import JsonResponse
from rest_framework.permissions import IsAuthenticated
from rest_framework.decorators import api_view, permission_classes
from ..models import Group, TeacherSubject,Enrollment,Class
from student.models import Student

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
    students = Student.objects.filter(enrollement_set__group__teacher=teacher)

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
        students = students.filter(enrollement_set__group__subject__id=int(subject_id)).distinct()

    # Apply sorting
    sort_by = request.GET.get('sort_by', '')
    if sort_by == 'paid_desc':
        students = students.annotate(total_paid=models.Sum('enrollment__paid_amount')).order_by('-total_paid')
    elif sort_by == 'paid_asc':
        students = students.annotate(total_paid=models.Sum('enrollment__paid_amount')).order_by('total_paid')
    elif sort_by == 'unpaid_desc':
        students = students.annotate(total_unpaid=models.Sum('enrollment__unpaid_amount')).order_by('-total_unpaid')
    elif sort_by == 'unpaid_asc':
        students = students.annotate(total_unpaid=models.Sum('enrollment__unpaid_amount')).order_by('total_unpaid')

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
    serializer = GroupStudentListSerializer(paginated_students, many=True)

    # Get teacher levels, sections, and subjects hierarchy for filter options
    teacher_subjects = TeacherSubject.objects.filter(teacher=teacher).select_related('level', 'section', 'subject')
    teacher_levels_sections_subjects_hierarchy = TeacherLevelsSectionsSubjectsHierarchySerializer(teacher_subjects, many=True)

    return JsonResponse({
        'students_total_count': paginator.count,
        'students': serializer.data,
        'teacher_levels_sections_subjects_hierarchy': teacher_levels_sections_subjects_hierarchy.data
    })
