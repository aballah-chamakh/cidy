from django.core.paginator import Paginator
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from common.tools import increment_parent_unread_notifications
from teacher.models import Teacher,Level,TeacherNotification
from ..serializers import TesLevelsSectionsSubjectsSerializer,TeacherListSerializer

# this one will be user in the filter of the teacher list
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_tes_levels_sections_subjects(request):
    """Get all of the subjects that the student can study for his level and section."""
   
    levels_qs  = Level.objects.all()
    serializer = TesLevelsSectionsSubjectsSerializer(levels_qs, many=True)

    return Response({'tes': serializer.data})

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_teachers(request):
    """Get a filtered and paginated list of teachers for the logged student"""

    parent = request.user.parent

    fullname_filter = request.GET.get('fullname', None)
    level_id = request.GET.get('level_id', None)
    section_id = request.GET.get('section_id', None)
    subject_ids = request.GET.getlist('subject_ids', None)


    # Apply fullname filter
    if fullname_filter:
        teachers = Teacher.objects.filter(fullname__icontains=fullname_filter)
    
    # Apply level,section and subject filters 
    if level_id : 
        teachers = teachers.filter(
            teachersubject_set__level__id=int(level_id),
        ).distinct()
        if section_id :
            teachers = teachers.filter(
                teachersubject_set__section__id=int(section_id)
            ).distinct()
        else :
            teachers = teachers.filter(
                teachersubject_set__section__isnull=True
            ).distinct()

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
    serializer = TeacherListSerializer(paginated_teachers, many=True)

    return Response({
        'teachers': serializer.data,
        'total_count': paginator.count,
        'current_page': page
    })



@api_view(['GET'])
@permission_classes([IsAuthenticated])
def parenting_request_form_data(request,teacher_id):
    
    try : 
        teacher = Teacher.objects.get(id=teacher_id)
    except Teacher.DoesNotExist:
        return Response({'error': 'Teacher not found'}, status=404)
    
    serializer = TeacherListSerializer(teacher)
    teacher_detail = serializer.data

    parent = request.user.parent
    # Get all sons of the parent who aren't attached to a student enrolled with the teacher
    parent_sons = parent.son_set.exclude(student__teacherenrollment__teacher=teacher).distinct()

    return Response({'teacher': teacher_detail, 'parent_sons': parent_sons})


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def send_parenting_request(request, teacher_id):

    try:
        teacher = Teacher.objects.get(id=teacher_id)
    except Teacher.DoesNotExist:
        return Response({'error': 'Teacher not found'}, status=404)

    son_ids = request.data.get('son_ids', [])
    if not son_ids:
        return Response({'error': 'No son IDs provided'}, status=400)
    

    # ensure that the requested sons belong to the parent
    if not (parent.son_set.filter(id__in=son_ids).count() == len(son_ids)):
        return Response({'error': 'Invalid son IDs provided'}, status=400)

    parent = request.user.parent
    son_pronoun = "son fils" if parent.gender == "male" else "sa fille"
    son_names = [son.fullname for son in parent.son_set.filter(id__in=son_ids)]
    if len(son_ids) == 1:
        message = f"Le parent {parent.fullname} demande un accès parental pour {son_pronoun} : {son_names[0]}."
    else:
        message = f"Le parent {parent.fullname} demande un accès parental pour ses enfants : {', '.join(son_names)}."
    
    TeacherNotification.objects.create(
        image=parent.image,
        teacher=teacher,
        message=message,
        meta_data={'parent_id': parent.id, 'son_ids': son_ids}
    )

    return Response({'success': 'Parenting request sent successfully'})
