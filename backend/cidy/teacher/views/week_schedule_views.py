import datetime
from tracemalloc import start
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from ..models import Group
from student.models import StudentNotification, StudentUnreadNotification
from parent.models import ParentNotification, ParentUnreadNotification, Son 
from ..serializers import GroupCreateUpdateSerializer

def increment_student_unread_notifications(student):
    """Helper function to increment student unread notifications count"""
    unread_obj, created = StudentUnreadNotification.objects.get_or_create(student=student)
    unread_obj.unread_notifications += 1
    unread_obj.save()

def increment_parent_unread_notifications(parent):
    """Helper function to increment parent unread notifications count"""
    unread_obj, created = ParentUnreadNotification.objects.get_or_create(parent=parent)
    unread_obj.unread_notifications += 1
    unread_obj.save()

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_week_schedule(request):
    """
    Get all groups of the teacher with their schedule details for the week schedule screen
    """
    teacher = request.user.teacher
    groups = Group.objects.filter(teacher=teacher)
    
    schedule_data = []
    today = datetime.date.today()
    for group in groups:
        teacher_subject = group.teacher_subject
        level = teacher_subject.level
        subject = teacher_subject.subject
        temporary_schedule = False 
        week_day = group.week_day
        start_time = group.start_time
        end_time = group.end_time

        if group.clear_temporary_schedule_at and today < group.clear_temporary_schedule_at : 
            temporary_schedule = True
            week_day = group.temporary_week_day
            start_time = group.temporary_start_time
            end_time = group.temporary_end_time

        schedule_data.append({
            'id': group.id,
            'name': group.name,
            'level': level.name+(f" {level.section}" if level.section else ""),
            'subject':  subject.name,
            'temporary_schedule' : temporary_schedule,
            'week_day': week_day,
            'start_time': start_time.strftime("%H:%M"),
            'end_time': end_time.strftime("%H:%M"),
        })
    print(schedule_data)
    return Response({'groups': schedule_data})

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
        return Response({'error': 'Group not found'}, status=404)
    
    # pass the data to update the serializer
    serializer = GroupCreateUpdateSerializer(group,data=request.data, context={'request': request}, partial=True)
    
    # Validate the data
    if not serializer.is_valid():
        return Response({'error': serializer.errors}, status=400)
    
    # update the group
    serializer.save()
    
    # get the data from the serializer
    change_type = serializer.validated_data.get('schedule_change_type')
    
    # get the students of the group
    students = group.get_students()
    
    # create the notification message
    if change_type == 'permanent':
        message = f"The schedule for your {group.teacher_subject.subject.name} group has been permanently changed. Please check the new schedule."
    else: # temporary
        message = f"The schedule for your {group.teacher_subject.subject.name} group has been temporarily changed for this week. Please check the new schedule."
    
    # send notifications to students and parents
    for student in students:
        # create student notification
        StudentNotification.objects.create(student=student, message=message)
        # increment student unread notifications
        increment_student_unread_notifications(student)
        
        # check if the student has a parent and send notification
        try:
            # A student can be linked to a Son entry, which in turn is linked to a Parent.
            son_record = Son.objects.filter(student_teacher_enrollments__student=student).first()
            if son_record:
                parent = son_record.parent
                ParentNotification.objects.create(parent=parent, message=message)
                increment_parent_unread_notifications(parent)
        except Exception: 
            # Continue even if there's an issue finding a parent or creating a notification
            continue
            
    return Response(serializer.data)
    group = serializer.save()

    schedule_change_type = request.data.get("schedule_change_type")
    
    # Send notifications to students and their parents
    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

    for student in group.students.all():
        # Create notification for each student
        student_message = f"{student_teacher_pronoun} {teacher.fullname} a modifié l'horaire du cours de {group.subject.name} à : {group.week_day} de {group.start_time_range} à {group.end_time_range} {'seulement cette semaine' if schedule_change_type == 'temporary' else 'de façon permanente'}."
        StudentNotification.objects.create(
            student=student,
            image=teacher.image,
            message=student_message
        )
        increment_student_unread_notifications(student)


        # If student has parents, notify them too
        child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
        for son in Son.objects.filter(student_teacher_enrollments__student=student).all() :
            # Assuming `son` has an attribute `gender` that can be 'male' or 'female'
            parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a modifié l'horaire du cours de {group.subject.name} de {child_pronoun} {son.fullname} à : {group.week_day} de {group.start_time_range} à {group.end_time_range} {'seulement cette semaine' if schedule_change_type == 'temporary' else 'de façon permanente'}."
            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
            )
            increment_parent_unread_notifications(son.parent)

    return Response({
        'status': 'success',
        'message': 'Group schedule updated successfully',
    })
