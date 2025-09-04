from django.http import JsonResponse
from django.core.paginator import Paginator
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated

from student.models import Student,StudentNotification
from parent.models import Parent,ParentNotification,Son
from teacher.models import Group,GroupEnrollment
from common.tools import increment_student_unread_notifications, increment_parent_unread_notifications

from ..models import TeacherNotification,TeacherUnreadNotification
from ..serializers import TeacherNotificationSerializer,StudentListToReplaceBySerializer


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_unread_notifications_count(request):
    teacher = request.user.teacher
    teacher_unread_notifications = TeacherUnreadNotification.objects.get(teacher=teacher)
    return JsonResponse({'unread_count': teacher_unread_notifications.unread_notifications})

# this will be used to mark the notifications as read after leaving the notification screen
# starting from the last notification ID loaded in the screen and going backward 
@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def mark_notifications_as_read(request):
    last_notification_id = request.data.get('last_notification_id')

    if not last_notification_id or not isinstance(last_notification_id, int):
        return JsonResponse({'status': 'error', 'message': 'Invalid notification ID'}, status=400)

    teacher = request.user.teacher
    TeacherNotification.objects.filter(
        teacher=teacher,
        id__lte=last_notification_id
    ).update(is_read=True)
    return JsonResponse({'status': 'success'})



@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_notifications(request):
    """Get paginated notifications for the teacher"""
    teacher = request.user.teacher
    
    # Get query parameters
    start_from_notification_id = request.GET.get('start_from_notification_id')
    if not start_from_notification_id or not start_from_notification_id.isdigit():
        return JsonResponse({'status': 'error', 'message': 'Invalid start_from_notification_id'}, status=400)

    page = request.GET.get('page', 1)
    
    # Get notifications, excluding those with IDs >= start_from_notification_id (to avoid duplicates notifications in the screen)
    notifications = TeacherNotification.objects.filter(teacher=teacher
                                                      ).exclude(id__gte=int(start_from_notification_id)
                                                      ).order_by('-id')
    # Paginate results
    paginator = Paginator(notifications, 30)
    try:
        paginated_notifications = paginator.page(page)
    except Exception:
        # If page is out of range, deliver last page
        paginated_notifications = paginator.page(paginator.num_pages)
        page = paginator.num_pages

    # Serialize the data
    serializer = TeacherNotificationSerializer(paginated_notifications, many=True)
    
    return JsonResponse({
        'notifications': serializer.data,
        'unread_count': teacher.teacher_unread_notifications.unread_notifications,
        'total_count': paginator.count,
        'total_pages': paginator.num_pages,
        'current_page': int(page)
    })



@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_new_notifications(request):
    """Get new notifications for the teacher"""
    teacher = request.user.teacher
    
    # Get query parameters
    start_from_notification_id = request.GET.get('start_from_notification_id')
    if not start_from_notification_id or not start_from_notification_id.isdigit():
        return JsonResponse({'status': 'error', 'message': 'Invalid start_from_notification_id'}, status=400)


    # Get notifications with IDs >= start_from_notification_id (to avoid duplicates notifications in the screen)
    notifications = TeacherNotification.objects.filter(teacher=teacher, id__gte=int(start_from_notification_id)).order_by('-id')


    # Serialize the data
    serializer = TeacherNotificationSerializer(notifications, many=True)
    
    return JsonResponse({
        'new_notifications': serializer.data,
    })


# this will be used in the case of the user clicked on an action button
# of a notification then he canceled the action 
@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def mark_a_notification_as_read(request, notification_id):
    """Mark a single notification as read"""

    teacher = request.user.teacher
    try:
        notification = TeacherNotification.objects.get(id=notification_id, teacher=teacher)
        notification.is_read = True
        notification.save()
        return JsonResponse({'status': 'success'})
    except TeacherNotification.DoesNotExist:
        return JsonResponse({'status': 'error', 'message': 'Notification not found'}, status=404)
    


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def student_request_accept_form_data(request, notification_id):
    """ returns the form data for accepting a student request notification"""
    # get the teacher notification of the notification_id to get the student id
    teacher = request.user.teacher
    teacher_notification = TeacherNotification.objects.get(teacher=teacher, id=notification_id)
    if not teacher_notification:
        return JsonResponse({'status': 'error', 'message': 'Notification not found'}, status=404)
    
    # mark the notification as read 
    teacher_notification.is_read = True
    teacher_notification.save()
    
    # get the student to get his level and section to return students with the same level and section
    student_id = teacher_notification.meta_data.get('student_id')
    student = Student.objects.get(id=student_id)

    # get the students with the same level and section as the student of the teacher notification with the groups of this teacher that they belong to
    student_qs = Student.objects.filter(teacher_enrollment__teacher=teacher, level=student.level, section=student.section,gender=student.gender)
    serializer = StudentListToReplaceBySerializer(student_qs, many=True)
    students_to_replace_by_options = serializer.data

    # for each requested teacher subject bring the groups of the teacher teaching this subject
    requested_teacher_subjects = teacher_notification.meta_data.get('requested_teacher_subjects', [])

    for teacher_subject in requested_teacher_subjects :
        groups = Group.objects.filter(teacher=teacher, teacher_subject__id=teacher_subject['id'])
        teacher_subject['groups'] = []
        for group in groups : 
            teacher_subject['groups'].append({
                'id' : group.id,
                'name' : group.name 
            })

    data = {
        'student' : {
            'image' : student.image.url,
            'fullname' : student.fullname,
            'level' : student.level.name,
            'section' : student.section.name if student.section else None,
            'phone_number' : student.phone_number
        },
        'students_to_replace_by_options' : students_to_replace_by_options,
        'requested_teacher_subjects' : requested_teacher_subjects
    }
    return JsonResponse({'status': 'success', 'data': data})



@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def accept_student_request(request, notification_id):
    """Accept a student request notification"""
    # ensure that the teacher accepted at least one subject 
    accepted_subjects = request.data.get('accepted_subjects', [])
    if not accepted_subjects : 
        return JsonResponse({'status': 'error', 'message': 'At least one subject must be accepted'}, status=400)

    # get the teacher notification of the notification_id to get the student id
    teacher = request.user.teacher
    teacher_notification = TeacherNotification.objects.get(teacher=teacher, id=notification_id)
    
    if not teacher_notification:
        return JsonResponse({'status': 'error', 'message': 'Notification not found'}, status=404)

    # mark the notification as accepted
    teacher_notification.meta_data['accepted'] = True 
    # mark the notification as read 
    teacher_notification.is_read = True
    teacher_notification.save()
    # get the student to accept the request
    requested_student_id = teacher_notification.meta_data.get('student_id')
    requesting_student = Student.objects.get(id=requested_student_id)

    # get the id of the student to replace by 
    student_to_replace_by_id = request.data.get('student_to_replace_by_id')
    final_student = requesting_student
    if student_to_replace_by_id : 
        """ Override the attribute of the student to replace by the ones of the requesting student except for the join date """
        # hold the user of the requesting student 
        requesting_student_user = requesting_student.user
        requesting_student.user = None
        requesting_student.save()

        # assign the user of the student to replace by to the requesting student
        student_to_replace_by = Student.objects.get(id=student_to_replace_by_id,teacher_enrollment_set__teacher=teacher)
        student_to_replace_by.user = requesting_student_user
        student_to_replace_by.image = requesting_student.image
        student_to_replace_by.fullname = requesting_student.fullname
        student_to_replace_by.phone_number = requesting_student.phone_number
        student_to_replace_by.gender = requesting_student.gender
        student_to_replace_by.level = requesting_student.level
        student_to_replace_by.section = requesting_student.section
        student_to_replace_by.save()

        # delete the requesting student
        requesting_student.delete()
        final_student = student_to_replace_by

    # add the final student to groups of the accepted subjects
    for subject in accepted_subjects:
        new_group = Group.objects.get(id=subject['group_id'], teacher=teacher)
        # enroll the student in the group 
        GroupEnrollment.objects.create(group=new_group, student=final_student)


    """ send notifications to the student and to his parents, informing them about the acceptance"""

    # Notify the student
    teacher_pronoun = "Le professeur" if teacher.gender == "male" else "La professeure"
    student_message = f"{teacher_pronoun} {teacher.fullname} a accepté votre demande d'inscription dans la/les matière(s) suivante(s) : {', '.join([sub['name'] for sub in accepted_subjects])}"
    if request.data.get('rejected_subjects') :
        student_message += f" Cependant, votre demande d'inscription dans la/les matière(s) suivante(s) a été refusée : {', '.join([sub['name'] for sub in request.data['rejected_subjects']])}."
    else : 
        student_message += "."

    StudentNotification.objects.create(
            student=final_student,
            image=teacher.image,
            message=student_message
    )
    increment_student_unread_notifications(final_student)

    # Notify the parents
    child_pronoun = "votre fils" if final_student.gender == "male" else "votre fille"
    for son in final_student.sons.all():
        parent_message = f"{teacher_pronoun} {teacher.fullname} a accepté la demande d'inscription de {child_pronoun} {son.fullname} dans la/les matière(s) suivante(s) : {', '.join([sub['name'] for sub in accepted_subjects])}."
        if request.data.get('rejected_subjects'):
            parent_message += f" Cependant, la demande d'inscription dans la/les matières suivante(s) a été refusée : {', '.join([sub['name'] for sub in request.data['rejected_subjects']])}."
        else:
            parent_message += "."
        ParentNotification.objects.create(
            parent=son.parent,
            image=son.image,
            message=parent_message,
            meta_data={"son_id": son.id}
        )
        increment_parent_unread_notifications(son.parent)

    return JsonResponse({'status': 'success','message':"the student request was accepted successfully"})

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def reject_student_request(request, notification_id):
    """Reject a student request notification"""
    # get the teacher notification of the student request
    teacher = request.user.teacher
    teacher_notification = TeacherNotification.objects.get(teacher=teacher, id=notification_id)
    if not teacher_notification:
        return JsonResponse({'status': 'error', 'message': 'Notification not found'}, status=404)

    # mark the rejection of the student request
    teacher_notification.meta_data['accepted'] = False
    # mark the notification as read
    teacher_notification.is_read = True
    teacher_notification.save()

    # Get the requesting student
    requesting_student = Student.objects.get(id=teacher_notification.meta_data['student_id'])

    # Notify the student about the rejection 
    teacher_pronoun = "Le professeur" if teacher.gender == "male" else "La professeure"
    student_message = f"{teacher_pronoun} {teacher.fullname} a refusé votre demande d'inscription."

    StudentNotification.objects.create(
            student=requesting_student,
            image=teacher.image,
            message=student_message
    )
    increment_student_unread_notifications(requesting_student)

    # Notify the parents of the student about the rejection
    child_pronoun = "votre fils" if requesting_student.gender == "male" else "votre fille"
    for son in requesting_student.sons.all():
        parent_message = f"{teacher_pronoun} {teacher.fullname} a refusé la demande d'inscription de {child_pronoun} {son.fullname}."
        ParentNotification.objects.create(
            parent=son.parent,
            image=son.image,
            message=parent_message,
            meta_data={"son_id": son.id}
        )
        increment_parent_unread_notifications(son.parent)

    return JsonResponse({'status': 'success','message':"the student request was rejected successfully"})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def parent_request_accept_form_data(request, notification_id):
    # Get the teacher notification of the parent request
    teacher = request.user.teacher
    teacher_notification = TeacherNotification.objects.get(teacher=teacher, id=notification_id)
    if not teacher_notification:
        return JsonResponse({'status': 'error', 'message': 'Notification not found'}, status=404)

    # mark the notification as read
    teacher_notification.is_read = True
    teacher_notification.save()

    # Get the requesting parent
    parent_id = teacher_notification.meta_data['parent_id']
    requesting_parent = Parent.objects.get(id=parent_id)

    # Get the requested sons to attach to students
    requested_son_ids = teacher_notification.meta_data.get('requested_son_ids', [])
    requested_sons = Son.objects.filter(parent=requesting_parent,id__in=requested_son_ids)

    requested_sons_json = [
        {
            'id': son.id,
            'fullname': son.fullname,
            'level': son.level.name if son.level else None,
            'section': son.section.name if son.section else None,
            'student_options' : [  
                                  {
                                      'id' : student.id,
                                      'fullname': student.fullname,
                                  }
                                 for student in Student.objects.filter(teacher_enrollment_set__teacher=teacher, level=son.level, section=son.section,gender=son.gender) ]
        }
        for son in requested_sons
    ]

    # Prepare the form data
    form_data = {
        'parent': {
            'image': requesting_parent.image.url,
            'fullname': requesting_parent.fullname,
            'phone_number': requesting_parent.phone_number
        },
        'sons' : requested_sons_json
    }

    return JsonResponse({'status': 'success', 'form_data': form_data})


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def accept_parent_request(request, notification_id):
    accepted_sons = request.data.get('accepted_sons', [])
    if not accepted_sons:
        return JsonResponse({'status': 'error', 'message': 'you must attach at least one son to a student'}, status=400)

    # Get the teacher notification of the parent request
    teacher = request.user.teacher
    teacher_notification = TeacherNotification.objects.get(teacher=teacher, id=notification_id)
    if not teacher_notification:
        return JsonResponse({'status': 'error', 'message': 'Notification not found'}, status=404)


    # Mark the notification of the parent request as accepted
    teacher_notification.meta_data['accepted'] = True
    # mark the notification as read
    teacher_notification.is_read = True
    teacher_notification.save()

    parent_id = teacher_notification.meta_data['parent_id']
    requesting_parent = Parent.objects.get(id=parent_id)

    # attach the selected student to the accepted son(s)
    for son in accepted_sons:
        son = Son.objects.get(parent=requesting_parent,id=son['id'])
        student = Student.objects.get(id=son['student_id'],teacher_enrollment_set__teacher=teacher)
        son.student = student
        son.save()

    # Notify the selected students about their new parent
    teacher_pronoun_student = "Votre professeur" if teacher.gender == "male" else "Votre professeure"
    teacher_pronoun_parent = "Le professeur" if requesting_parent.gender == "male" else "La professeure"
    parent_pronoun = "M." if requesting_parent.gender == "male" else "Mme."
    
    student_message = f"{teacher_pronoun_student} {teacher.fullname} a accepté {parent_pronoun} {requesting_parent.fullname} comme votre parent."

    selected_student_ids = [son['student_id'] for son in accepted_sons]
    selected_student_qs = Student.objects.filter(id__in=selected_student_ids)
    
    for student in selected_student_qs:
        StudentNotification.objects.create(
            student=student,
            image=teacher.image,
            message=student_message
        )
        increment_student_unread_notifications(student)

    # Notify the parent about the acceptance
    parent_message = f"{teacher_pronoun_parent} {teacher.fullname} vous a accepté comme parent de : {', '.join([son['fullname'] for son in accepted_sons])}"
    if request.data.get('rejected_sons'):
        parent_message += f". Cependant, {'il' if teacher.gender == 'male' else 'elle'} vous a refusé comme parent de : {', '.join([son['fullname'] for son in request.data['rejected_sons']])}."
    else : 
        parent_message += "."

    ParentNotification.objects.create(
        parent=requesting_parent,
        image=teacher.image,
        message=parent_message,
    )
    increment_parent_unread_notifications(requesting_parent)

    return JsonResponse({'status': 'success', 'message': 'Parent request accepted successfully'})

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def decline_parent_request(request, notification_id):
    # Get the teacher notification of the parent request
    teacher = request.user.teacher
    teacher_notification = TeacherNotification.objects.get(teacher=teacher, id=notification_id)
    if not teacher_notification:
        return JsonResponse({'status': 'error', 'message': 'Notification not found'}, status=404)

    # Mark the notification of the parent request as declined
    teacher_notification.meta_data['declined'] = True
    # mark the notification as read
    teacher_notification.is_read = True
    teacher_notification.save()

    parent_id = teacher_notification.meta_data['parent_id']
    requesting_parent = Parent.objects.get(id=parent_id)

    # Notify the parent about the decline
    teacher_pronoun_parent = "Le professeur" if requesting_parent.gender == "male" else "La professeure"
    parent_message = f"{teacher_pronoun_parent} {teacher.fullname} a refusé votre demande de parentalité."

    ParentNotification.objects.create(
        parent=requesting_parent,
        image=teacher.image,
        message=parent_message,
    )
    increment_parent_unread_notifications(requesting_parent)

    return JsonResponse({'status': 'success', 'message': 'Parent request declined successfully'})