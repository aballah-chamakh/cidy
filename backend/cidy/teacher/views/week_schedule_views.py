from django.http import JsonResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from ..models import Group
from student.models import StudentNotification
from parent.models import ParentNotification
from ..serializers import GroupCreateUpdateSerializer
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

    teacher = request.user.teacher
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return JsonResponse({'error': 'Group not found'}, status=404)
    
    # pass the data to update the serializer
    serializer = GroupCreateUpdateSerializer(group,data=request.data, context={'request': request}, partial=True)
    
    # Validate the data
    if not serializer.is_valid():
        return JsonResponse({'error': serializer.errors}, status=400)
    
    # update the group
    group = serializer.save()
    
    # Send notifications to students and their parents
    student_teacher_pronoun = "Votre professeur" if teacher.gender == "male" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "male" else "La professeure"

    for student in group.students.all():
        # Create notification for each student
        student_message = f"{student_teacher_pronoun} {teacher.fullname} a modifié l'horaire du cours de {group.subject.name} à : {group.week_day} de {group.start_time_range} à {group.end_time_range} {'seulement cette semaine' if schedule_change_type == 'temporary' else 'de façon permanente'}."
        StudentNotification.objects.create(
            student=student,
            image=teacher.image,
            message=student_message
        )


        # If student has parents, notify them too
        child_pronoun = "votre fils" if student.gender == "male" else "votre fille"
        for son in student.sons.all() :
            # Assuming `son` has an attribute `gender` that can be 'male' or 'female'
            parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a modifié l'horaire du cours de {group.subject.name} de {child_pronoun} {son.fullname} à : {group.week_day} de {group.start_time_range} à {group.end_time_range} {'seulement cette semaine' if schedule_change_type == 'temporary' else 'de façon permanente'}."
            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
            )

    return JsonResponse({
        'status': 'success',
        'message': 'Group schedule updated successfully',
    })
