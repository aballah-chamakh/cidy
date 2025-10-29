from datetime import datetime
from tokenize import group
from django.utils import timezone
import time 
from django.core.paginator import Paginator
from django.db.models import Q

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from student.models import Student, StudentNotification, StudentUnreadNotification
from parent.models import ParentNotification,Son 
from common.tools import increment_student_unread_notifications, increment_parent_unread_notifications

from ..models import Group, TeacherSubject,GroupEnrollment,Class,TeacherEnrollment
from django.http import HttpResponseServerError
from ..serializers import (GroupCreateStudentSerializer,GroupStudentListSerializer,StudentsWithOverlappingClasses,
                           GroupListSerializer, TeacherLevelsSectionsSubjectsHierarchySerializer,
                           GroupCreateUpdateSerializer,GroupDetailsSerializer,GroupPossibleStudentListSerializer)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def can_create_group(request):
    """Check if a teacher has the ability to create a new group"""
    teacher = request.user.teacher
    
    # Check if teacher has any level with subjects
    has_level_with_subjects = TeacherSubject.objects.filter(teacher=teacher).exists()
    
    if not has_level_with_subjects:
        return Response({
            'can_create': False,
            'message': 'You need to set up at least one level with subjects in the Prices screen before creating a group.'
        })
    
    return Response({
        'can_create': True
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_groups(request):
    time.sleep(1)
    #return HttpResponseServerError("An unexpected error occurred.")
    """Get a filtered list of groups for the teacher"""
    teacher = request.user.teacher
    groups = Group.objects.filter(teacher=teacher)
    # get teacher levels sections subjects hierarchy to use them as options for the filters
    teacher_subjects = TeacherSubject.objects.filter(teacher=teacher).select_related('level','subject').order_by('-level__order')
    teacher_levels_sections_subjects_hierarchy = TeacherLevelsSectionsSubjectsHierarchySerializer(teacher_subjects)
    # Check if teacher has any groups
    if not groups.exists():
        response = {
            'has_groups': False,
            'groups': [],
            'teacher_levels_sections_subjects_hierarchy': teacher_levels_sections_subjects_hierarchy.data
        }
        print(response)
        return Response(response)
    
    # Apply search filter
    search_term = request.GET.get('name', '')
    if search_term:
        groups = groups.filter(name__icontains=search_term)
    
    # Apply level filter
    level = request.GET.get('level')
    if level :
        groups = groups.filter(teacher_subject__level__name=level)
    
    # Apply section filter
    section = request.GET.get('section')
    if section :
        groups = groups.filter(teacher_subject__level__section=section)
    
    # Apply subject filter
    subject = request.GET.get('subject')
    if subject:
        groups = groups.filter(teacher_subject__subject__name=subject)

    # Apply week day filter
    week_day = request.GET.get('week_day')
    if week_day:
        groups = groups.filter(week_day=week_day)
    
    # Apply time range filter
    start_time = request.GET.get('start_time')
    print(f"start_time : {start_time}")
    if start_time :
        start_time = start_time.replace('_',':')
        start_time = datetime.strptime(start_time, "%H:%M").time()
        groups = groups.filter(
            start_time__gte=start_time
        )

    end_time = request.GET.get('end_time')

    if end_time : 
        end_time = end_time.replace('_',':')
        end_time = datetime.strptime(end_time, "%H:%M").time()
        groups = groups.filter(
            end_time__lte=end_time
        )


    # Apply sorting
    sort_by = request.GET.get('sort_by')
    if sort_by:
        if sort_by == 'paid_amount_desc':
            groups = groups.order_by('-total_paid')
        elif sort_by == 'paid_amount_asc':
            groups = groups.order_by('total_paid')
        elif sort_by == 'unpaid_amount_desc':
            groups = groups.order_by('-total_unpaid')
        elif sort_by == 'unpaid_amount_asc':
            groups = groups.order_by('total_unpaid')
    else : 
        # default sorting by level order descending
        groups = groups.order_by('-teacher_subject__level__order','name')

    

    # Pagination
    """
    page = request.GET.get('page', 1)
    page_size = request.GET.get('page_size', 30)
    paginator = Paginator(groups, page_size)
    try:
        paginated_groups = paginator.page(page)
    except Exception:
        # If page is out of range, deliver last page
        paginated_groups = paginator.page(paginator.num_pages)
        page = paginator.num_pages
    """
    serializer = GroupListSerializer(groups, many=True)

    
    response = {
        'has_groups': True,
        'groups_total_count': groups.count(),
        'groups': serializer.data,
        'teacher_levels_sections_subjects_hierarchy': teacher_levels_sections_subjects_hierarchy.data
    }
    print(response)
    return Response(response)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_group(request):
    #Group.objects.all().delete()
    """Create a new group"""

    # Create a serializer with the request data
    print(request.data)
    serializer = GroupCreateUpdateSerializer(data=request.data, context={'request': request})
    
    # Validate the data
    if not serializer.is_valid():
        print(serializer.errors)
        return Response(serializer.errors, status=400)
    
    # Create the group
    group = serializer.save()
    
    return Response({
        'group_id': group.id,
        'success': True,
        'message': 'Group created successfully'
    },status=status.HTTP_201_CREATED)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_groups(request):

    """Delete selected groups"""
    teacher = request.user.teacher
    group_ids = request.data.get('group_ids', [])
    
    if not group_ids:
        return Response({'error': 'No groups selected'}, status=400)
    
    # Get the groups to delete
    groups = Group.objects.filter(teacher=teacher, id__in=group_ids)
    
    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"
    for group in groups:
        students = group.students.all()
        for student in students:
            # send a notification to each student with an independant account
            if student.user :
                student_message = f"{student_teacher_pronoun} {teacher.fullname} a supprimé le groupe {group.teacher_subject.subject.name} dans lequel vous étiez inscrit."
                StudentNotification.objects.create(
                    student = student,
                    image = teacher.image,
                    message = student_message)
                increment_student_unread_notifications(student)
            # send a notification to the parent of the sons attached to each student belongs to the group
            for son in Son.objects.filter(student_teacher_enrollments__student=student).all() : 
                child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
                parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a supprimé le groupe du {group.teacher_subject.subject.name} dans lequel {child_pronoun} {son.fullname} était inscrit."

                ParentNotification.objects.create(
                    parent=son.parent,
                    image=son.image,
                    message=parent_message,
                    meta_data = {"son_id":son.id}
                )
                increment_parent_unread_notifications(son.parent)
        group.delete()    
    
    return Response({
        'success': True,
        'message': f'{len(groups)} groups deleted successfully'
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_group_details(request, group_id):
    """Get detailed information about a specific group"""
    time.sleep(1)
    teacher = request.user.teacher

    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)
    
    
    serializer = GroupDetailsSerializer(group,context={'request':request})
    
    return Response(serializer.data)


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def edit_group(request, group_id):
    """Edit an existing group"""
    teacher = request.user.teacher
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)
    
    # pass the data to update the serializer
    serializer = GroupCreateUpdateSerializer(group,data=request.data, context={'request': request}, partial=True)
    
    # Validate the data
    if not serializer.is_valid():
        return Response(serializer.errors, status=400)
    
    # update the group
    group = serializer.save()

    # Check if the schedule of the group has changed
    schedule_change_type = request.data.get('schedule_change_type')
    if schedule_change_type : 
        student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
        parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

        for student in group.students.all() :
            # Create notification for each student
            student_message = f"{student_teacher_pronoun} {teacher.fullname} a modifié l'horaire du cours de {group.teacher_subject.subject.name} à : {group.week_day} de {group.start_time.strftime('%H:%M')} à {group.end_time.strftime('%H:%M')} {'seulement cette semaine' if schedule_change_type == 'temporary' else 'de façon permanente'}."
            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message,
                meta_data = {'group_id': group.id}
            )
            increment_student_unread_notifications(student)

            # If student has parents, notify them too
            child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
            for son in Son.objects.filter(student_teacher_enrollments__student=student).all() :
                parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a modifié l'horaire du cours de {group.teacher_subject.subject.name} de {child_pronoun} {son.fullname} à : {group.week_day} de {group.start_time.strftime('%H:%M')} à {group.end_time.strftime('%H:%M')} {'seulement cette semaine' if schedule_change_type == 'temporary' else 'de façon permanente'}."
                ParentNotification.objects.create(
                    parent=son.parent,
                    image=son.image,
                    message=parent_message,
                    meta_data = {"son_id":son.id,'group_id':group.id}
                )
                increment_parent_unread_notifications(son.parent)
    
    return Response({
        'success': True,
        'message': 'Group updated successfully'
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_group_students(request,group_id):
    """
    Get all students of the teacher with filtering options
    """
    teacher = request.user.teacher
    
    try: 
        group = Group.objects.get(id=group_id,teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)

    # Get students associated with this group
    students = group.students.all()

    # Apply fullname filter
    fullname = request.GET.get('fullname', '')
    if fullname:
        students = students.filter(fullname__icontains=fullname)
    

    page = request.GET.get('page', 1)
    page_size = request.GET.get('page_size', 30)
    paginator = Paginator(students, page_size)
    
    try:
        paginated_students = paginator.page(page)
    except Exception:
        # If page is out of range, deliver last page
        page = paginator.num_pages
        paginated_students = paginator.page(paginator.num_pages)
    
    serializer = GroupStudentListSerializer(paginated_students,many=True)
    
    return Response({
        'students': serializer.data,
        'total_students': paginator.count,
        'page':page
    })


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def create_group_student(request, group_id):
    """Create a new student then add them to the specified group"""
    teacher = request.user.teacher

    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)

    # Create a serializer with the request data
    serializer = GroupCreateStudentSerializer(data=request.data)

    # Validate the data
    if not serializer.is_valid():
        print(serializer.errors)
        return Response(serializer.errors, status=400)

    # Save the student
    student = serializer.save(level=group.teacher_subject.level)

    # Add the student to the group
    group.students.add(student)

    
    return Response({
        'success': True,
        'message': 'Student created and added to the group successfully'
    },status=status.HTTP_201_CREATED)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_the_possible_students_for_a_group(request,group_id):
    teacher = request.user.teacher
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)
    
    teacher_subject = group.teacher_subject 
    
    student_qs = Student.objects.filter(teacherenrollment__teacher=teacher,level=teacher_subject.level)

    # Exclude students already in the group
    student_qs = student_qs.exclude(groups=group)
   
    # Apply fullname filter
    fullname = request.GET.get('fullname', '')
    if fullname:
        student_qs = student_qs.filter(fullname__icontains=fullname)

    page = request.GET.get('page', 1)
    page_size = request.GET.get('page_size', 30)
    paginator = Paginator(student_qs, page_size)

    try:
        paginated_students = paginator.page(page)
    except Exception:
        # If page is out of range, deliver last page
        page = 1
        paginated_students = paginator.page(1)
    
    serializer = GroupPossibleStudentListSerializer(paginated_students,many=True)
    print(serializer.data)
    return Response({
        'students': serializer.data,
        'total_students': paginator.count,
        'page': int(page)
    })



@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def add_students_to_group(request,group_id):

    student_ids = request.data.get('student_ids',[])
    teacher = request.user.teacher
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)
    
    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"
    # add the students to the group 
    students_qs = Student.objects.filter(id__in=student_ids, teacherenrollment__teacher=teacher)
    for student in students_qs :
        # enroll the student in the group 
        GroupEnrollment.objects.create(group=group, student=student)
        # Create notification for each student that has an independant account
        if student.user : 
            student_message = f"{student_teacher_pronoun} {teacher.fullname} a ajouté vous à un groupe de {group.teacher_subject.subject.name}."
            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message,
                meta_data = {'group_id': group.id}
            )
            increment_student_unread_notifications(student)
        # If student has parents, notify them too
        child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
        for son in Son.objects.filter(student_teacher_enrollments__student=student).all() :
            # Assuming `son` has an attribute `gender` that can be 'male' or 'female'
            parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a ajouté {child_pronoun} {son.fullname} à un groupe de {group.teacher_subject.subject.name}."
            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
                meta_data = {"son_id":son.id,'group_id':group.id}
            )
            increment_parent_unread_notifications(son.parent)

    return Response({
        'success': True,
        'message': 'Students added to the group successfully'
    })


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def remove_students_from_group(request, group_id):

    """Remove students from a specific group"""
    teacher = request.user.teacher

    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)

    student_ids = request.data.get('student_ids', [])
    if not student_ids:
        return Response({'error': 'No student IDs provided'}, status=400)

    students_to_remove = group.students.filter(id__in=student_ids)
    if not students_to_remove.exists():
        return Response({'error': 'No matching students found in the group'}, status=404)

    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

    for student in students_to_remove:
        # Notify the student if they have an independent account
        if student.user:
            student_message = f"{student_teacher_pronoun} {teacher.fullname} vous a retiré du groupe de {group.teacher_subject.subject.name}."
            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message
            )
            increment_student_unread_notifications(student)

        # Notify the parents of the student
        child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
        for son in Son.objects.filter(student_teacher_enrollments__student=student).all():
            parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a retiré {child_pronoun} {son.fullname} du groupe de {group.teacher_subject.subject.name}."
            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
                meta_data={"son_id": son.id}
            )
            increment_parent_unread_notifications(son.parent)

        # Remove the student from the group
        group.students.remove(student)

    return Response({
        'success': True,
        'message': f'{students_to_remove.count()} students removed from the group successfully'
    })

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def mark_attendance(request, group_id):
    time.sleep(3)
    """Mark attendance for selected students in a group"""
    # validate the request data
    student_ids = request.data.get('student_ids', [])
    print(f"student_ids : {student_ids}")
    print(f"group id  : {group_id}")
    if not student_ids:
        print("No student IDs provided")
        return Response({'error': 'No student IDs provided'}, status=400)

    attendance_date = request.data.get('date')
    attendance_start_time = request.data.get('start_time')
    attendance_end_time = request.data.get('end_time')
    
    if not attendance_date or not attendance_start_time or not attendance_end_time:
        print("The date, start time and end time are required")
        return Response({'error': 'The date, start time and end time are required'}, status=400)

    attendance_date = datetime.strptime(attendance_date, "%d/%m/%Y").date()
    attendance_start_time = datetime.strptime(attendance_start_time, "%H:%M").time()
    attendance_end_time = datetime.strptime(attendance_end_time, "%H:%M").time()


    teacher = request.user.teacher

    # check if the group exists and belongs to the teacher
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)

    # check if these students are enrolled in the group of the teacher
    students = group.students.filter(id__in=student_ids, teacherenrollment__teacher=teacher)
    if not students.exists():
        return Response({'error': 'No students found in the group'}, status=404)

    teacher_subject = group.teacher_subject

    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

    print("starting to mark attendance for students...")
    students_with_overlapping_classes = []
    for student in students:
        student_teacher_enrollment = TeacherEnrollment.objects.get(student=student, teacher=teacher)
        student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)

        # across all the classes of this student with this teacher, check if the attendance date and time overlaps with another class
        overlapping_classes = Class.objects.filter(
            group_enrollment__student=student,
            group_enrollment__group__teacher=teacher
        ).filter(
           Q(Q(absence_date=attendance_date) & Q(absence_start_time__lt=attendance_end_time) & Q(absence_end_time__gt=attendance_start_time)) |
            Q(Q(attendance_date=attendance_date) & Q(attendance_start_time__lt=attendance_end_time) & Q(attendance_end_time__gt=attendance_start_time))
        )
        
        if overlapping_classes.exists() : 
            students_with_overlapping_classes.append({
                "id" : student.id,
                "image" : student.image.url,
                "fullname": student.fullname
            })
            continue
        
        unpaid_amount_did_increase = False 
        # check if the class of this attendance completes the next batch of 4 classes
        if (student_group_enrollment.attended_non_paid_classes + 1) % 4 == 0 : 
            # mark the non due payment classes of this group enrollment as due 
            Class.objects.filter(group_enrollment=student_group_enrollment, status='attended_and_the_payment_not_due').update(status='attended_and_the_payment_due')
            
            # create the class of this attendance as due
            Class.objects.create(group_enrollment=student_group_enrollment,
                                attendance_date=attendance_date,
                                attendance_start_time=attendance_start_time,
                                attendance_end_time=attendance_end_time,
                                status = 'attended_and_the_payment_due'
                                )
            
            student_group_enrollment.unpaid_amount += teacher_subject.price_per_class * 4
            student_teacher_enrollment.unpaid_amount += teacher_subject.price_per_class * 4
            group.total_unpaid += teacher_subject.price_per_class * 4
            unpaid_amount_did_increase = True
        else : 
            # create the class of this attendance as not due
            Class.objects.create(group_enrollment=student_group_enrollment,
                                attendance_date=attendance_date,
                                attendance_start_time=attendance_start_time,
                                attendance_end_time=attendance_end_time,
                                status = 'attended_and_the_payment_not_due'
                                )
        
        student_group_enrollment.attended_non_paid_classes +=  1
        student_group_enrollment.save()
        student_teacher_enrollment.save()
        group.save()
        
        print(f"group_enrollment.attended_non_paid_classes : {student_group_enrollment.attended_non_paid_classes}")
        print(f"group_enrollment.unpaid_amount : {student_group_enrollment.unpaid_amount}")
        print(f"teacher_enrollment.unpaid_amount : {student_teacher_enrollment.unpaid_amount}")
        # Notify the student
        if student.user:
            student_message = (
                f"{student_teacher_pronoun} {teacher.fullname} a marqué votre présence "
                f"dans la séance de {group.teacher_subject.subject.name} qui a eu lieu le "
                f"{attendance_date.strftime('%d/%m/%Y')} de {attendance_start_time.strftime('%H:%M')} "
                f"à {attendance_end_time.strftime('%H:%M')}"
            )
            if unpaid_amount_did_increase:
                student_message += (
                    f", et le montant impayé pour cette matière est désormais de "
                    f"{student_group_enrollment.unpaid_amount} DT."
                )
            else:
                student_message += "."
            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message,
                meta_data={"group_id": group.id}
            )
            increment_student_unread_notifications(student)

        # Notify the parents
        child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
        for son in Son.objects.filter(student_teacher_enrollments__student=student).all():
            parent_message = (
                f"{parent_teacher_pronoun} {teacher.fullname} a marqué la présence de "
                f"{child_pronoun} {son.fullname} dans la séance de "
                f"{group.teacher_subject.subject.name} qui a eu lieu le "
                f"{attendance_date.strftime('%d/%m/%Y')} de {attendance_start_time.strftime('%H:%M')} "
                f"à {attendance_end_time.strftime('%H:%M')}"
            )
            if unpaid_amount_did_increase:
                parent_message += (
                    f", et le montant impayé pour cette matière est désormais de "
                    f"{student_group_enrollment.unpaid_amount} DT."
                )
            else:
                parent_message += "."

            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
                meta_data={"son_id": son.id,"group_id": group.id}
            )
            increment_parent_unread_notifications(son.parent)

    print("response :")
    print({
        'success': True,
        'students_with_overlapping_classes': students_with_overlapping_classes,
        'students_marked_count': len(student_ids) - len(students_with_overlapping_classes)

    })
    return Response({
        'success': True,
        'students_marked_count': len(student_ids) - len(students_with_overlapping_classes),
        'students_with_overlapping_classes': students_with_overlapping_classes,
    })

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def unmark_attendance(request, group_id):
    time.sleep(3)

    """Unmark attendance for selected students in a group"""
    teacher = request.user.teacher

    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)

    teacher_subject = group.teacher_subject
    student_ids = request.data.get('student_ids', [])
    if not student_ids:
        return Response({'error': 'No student IDs provided'}, status=400)

    num_classes_to_unmark = request.data.get('number_of_classes')
    if not num_classes_to_unmark or not isinstance(num_classes_to_unmark, int) or num_classes_to_unmark < 1:
        return Response({'error': 'Invalid number of classes to unmark'}, status=400)

    students = group.students.filter(id__in=student_ids)
    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

    students_without_enough_classes_to_unmark_their_attendance = []

    for student in students:
        student_teacher_enrollment = TeacherEnrollment.objects.get(student=student, teacher=teacher)
        student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)

        # get all of the attended classes of this student in this group
        attended_classes = Class.objects.filter(
            group_enrollment=student_group_enrollment,
            status__in=['attended_and_the_payment_not_due', 'attended_and_the_payment_due']
        ).order_by('attendance_date','attendance_start_time','id')

        attended_classes_count = attended_classes.count()
        print(f"attended_classes_count : {attended_classes_count}")
        print(f"num_classes_to_unmark : {num_classes_to_unmark}")
        # collect student with missing classes to unmark their attendance
        missing_number_of_classes_to_unmark = num_classes_to_unmark - attended_classes_count
        if (missing_number_of_classes_to_unmark > 0): 
            students_without_enough_classes_to_unmark_their_attendance.append({
                'id' : student.id,
                'image' : student.image.url,  
                'fullname': student.fullname,
                'missing_number_of_classes' : missing_number_of_classes_to_unmark
            })

        if attended_classes_count == 0 :
            continue

        # get the recent {num_classes_to_unmark} attended classes to delete them
        start_idx = 0 if attended_classes_count-num_classes_to_unmark <= 0 else attended_classes_count-num_classes_to_unmark
        attended_classes_to_delete = attended_classes[start_idx:]
        attended_classes_to_delete_count = attended_classes_to_delete.count()
        print(f"attended_classes_to_delete_count : {attended_classes_to_delete_count}")

        # delete these classes
        for attended_class in attended_classes_to_delete :
            
            # decrease unpaid amount by the price of the class if it was due
            if attended_class.status == 'attended_and_the_payment_due' :
                student_group_enrollment.unpaid_amount -= teacher_subject.price_per_class
                student_teacher_enrollment.unpaid_amount -= teacher_subject.price_per_class
                group.total_unpaid -= teacher_subject.price_per_class

            # delete the class 
            attended_class.delete()
            
            # decrease the attended an non paid classes 
            student_group_enrollment.attended_non_paid_classes -= 1 

        # after the delete of the classes, if the last batch of classes has less then 4 classes 
        # mark them as not due
        remaining_classes_count = student_group_enrollment.attended_non_paid_classes % 4
        if (remaining_classes_count > 0) : 
            # get the remaining classes 
            remaining_classes = Class.objects.filter(group_enrollment=student_group_enrollment,
                                                              status__in=['attended_and_the_payment_not_due',
                                                                           'attended_and_the_payment_due']).order_by('-attendance_date','-attendance_start_time','-id')[:remaining_classes_count]
            for remaining_class in remaining_classes :
                # for each class marked as due
                if remaining_class.status == 'attended_and_the_payment_due' :
                    # mark it as not due
                    remaining_class.status = 'attended_and_the_payment_not_due'
                    remaining_class.save()

                    # remove it's unpaid amount
                    student_group_enrollment.unpaid_amount -= teacher_subject.price_per_class
                    student_teacher_enrollment.unpaid_amount -= teacher_subject.price_per_class
                    group.total_unpaid -= teacher_subject.price_per_class
            
        student_group_enrollment.save()
        student_teacher_enrollment.save()
        group.save()


        print(f"group_enrollment.attended_non_paid_classes : {student_group_enrollment.attended_non_paid_classes}")
        print(f"group_enrollment.unpaid_amount : {student_group_enrollment.unpaid_amount}")
        print(f"teacher_enrollment.unpaid_amount : {student_teacher_enrollment.unpaid_amount}")

        # Notify the student
        if student.user:
            student_message = (
                f"{student_teacher_pronoun} {teacher.fullname} a annulé votre présence "
                f"pour {attended_classes_to_delete_count} séance(s) de "
                f"{group.teacher_subject.subject.name}."
            )            
            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message,
                meta_data={"group_id": group.id}
            )
            increment_student_unread_notifications(student)

        # Notify the parents
        child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
        for son in Son.objects.filter(student_teacher_enrollments__student=student).all():
            parent_message = (
                    f"{parent_teacher_pronoun} {teacher.fullname} a annulé la présence de "
                    f"{child_pronoun} {son.fullname} pour {attended_classes_to_delete_count} "
                    f"séance(s) de {group.teacher_subject.subject.name}."
            )
            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
                meta_data={"son_id": son.id, "group_id": group.id}
            )
            increment_parent_unread_notifications(son.parent)
    response = {
        'success': True,
        'students_unmarked_completely_count': len(student_ids) - len(students_without_enough_classes_to_unmark_their_attendance),
        'students_without_enough_classes_to_unmark_their_attendance':students_without_enough_classes_to_unmark_their_attendance
    }
    print(response)
    return Response(response)
        
@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def mark_absence(request,group_id):
    """Mark absence for the specified students in the specified group"""

    # validate the request data
    student_ids = request.data.get('student_ids', [])
    if not student_ids:
        return Response({'error': 'No student IDs provided'}, status=400)

    absence_date = request.data.get('date')
    absence_start_time = request.data.get('start_time')
    absence_end_time = request.data.get('end_time')

    if not absence_date or not absence_start_time or not absence_end_time:
        return Response({'error': 'Date and time range are required'}, status=400)

    absence_date = datetime.strptime(absence_date, "%d/%m/%Y").date()
    absence_start_time = datetime.strptime(absence_start_time, "%H:%M").time()
    absence_end_time = datetime.strptime(absence_end_time, "%H:%M").time()

    teacher = request.user.teacher

    # check if the group exists and belongs to the teacher
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)

    # check if these students have a relationship with the teacher
    students = Student.objects.filter(id__in=student_ids, teacherenrollment__teacher=teacher)
    if not students.exists():
        return Response({'error': 'No students found in the group'}, status=404)

    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"


    students_with_overlapping_classes = []
    
    for student in students:
        
        # across all the classes of this student with this teacher, check if the absence date and time overlaps with another class
        existing_classes = Class.objects.filter(
            group_enrollment__student=student,
            group_enrollment__group__teacher=teacher
        ).filter(
            Q(Q(absence_date=absence_date) & Q(absence_start_time__lt=absence_end_time) & Q(absence_end_time__gt=absence_start_time)) |
            Q(Q(attendance_date=absence_date) & Q(attendance_start_time__lt=absence_end_time) & Q(attendance_end_time__gt=absence_start_time))
        )
        
        if existing_classes.exists():
            students_with_overlapping_classes.append({
                'id': student.id,
                'image': student.image.url,
                'fullname': student.fullname
            })
        else:
            student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
            Class.objects.create(group_enrollment=student_group_enrollment,
                                absence_date=absence_date,
                                absence_start_time=absence_start_time,
                                absence_end_time=absence_end_time,
                                status='absent')
        
            # Notify the student
            if student.user:
                student_message = (
                    f"{student_teacher_pronoun} {teacher.fullname} a marqué votre absence "
                    f"dans la séance de {group.teacher_subject.subject.name} qui a eu lieu le "
                    f"{absence_date} de {absence_start_time} à {absence_end_time}."
                )
                StudentNotification.objects.create(
                    student=student,
                    image=teacher.image,
                    message=student_message,
                    meta_data={"group_id": group.id}
                )
                increment_student_unread_notifications(student)

            # Notify the parents
            child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
            for son in Son.objects.filter(student_teacher_enrollments__student=student).all():
                parent_message = (
                        f"{parent_teacher_pronoun} {teacher.fullname} a marqué l’absence de "
                        f"{child_pronoun} {son.fullname} dans la séance de "
                        f"{group.teacher_subject.subject.name} qui a eu lieu le "
                        f"{absence_date} de {absence_start_time} à {absence_end_time}."
                )               
                ParentNotification.objects.create(
                    parent=son.parent,
                    image=son.image,
                    message=parent_message,
                    meta_data={"son_id": son.id, "group_id": group.id}
                )
                increment_parent_unread_notifications(son.parent)

    return Response({
        'success': True,
        'students_marked_count': len(student_ids) - len(students_with_overlapping_classes),
        'students_with_overlapping_classes': students_with_overlapping_classes,
    })

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def unmark_absence(request,group_id):
    """Unmark absence for the specified students in the specified group"""

    # validate the request data
    student_ids = request.data.get('student_ids', [])
    if not student_ids:
        return Response({'error': 'No student IDs provided'}, status=400)

    number_of_classes_to_unmark = request.data.get('number_of_classes')
    if not number_of_classes_to_unmark or not isinstance(number_of_classes_to_unmark, int) or number_of_classes_to_unmark < 1:
        return Response({'error': 'Invalid number of classes to unmark'}, status=400)

    teacher = request.user.teacher

    # check if the group exists and belongs to the teacher
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)

    # check if these students have a relationship with the teacher
    students = Student.objects.filter(id__in=student_ids, teacherenrollment__teacher=teacher)
    if not students.exists():
        return Response({'error': 'No students found in the group'}, status=404)

    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"
    students_without_enough_absent_classes_to_unmark = []
    for student in students:

        # get the absent classes of this student 
        student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
        absent_classes = student_group_enrollment.class_set.filter(status='absent').order_by('absence_date','absence_start_time','id')
        
         # check if the student has enough absent classes to unmark
        absent_classes_count = absent_classes.count()
        missing_number_of_classes_to_unmark = number_of_classes_to_unmark - absent_classes_count
        if (missing_number_of_classes_to_unmark > 0):
            students_without_enough_absent_classes_to_unmark.append({
                'id' : student.id,
                'image' : student.image.url,  
                'fullname': student.fullname,
                'missing_number_of_classes' : missing_number_of_classes_to_unmark
            })
        if (absent_classes_count == 0):
            continue
        print(f"absent_classes_count : {absent_classes_count}")
        # get the recent {number_of_classes_to_unmark} absent classes to delete them
        start_idx = 0 if absent_classes_count-number_of_classes_to_unmark <= 0 else absent_classes_count-number_of_classes_to_unmark
        absent_classes_to_delete = absent_classes[start_idx:]  
        absent_classes_to_delete_count = absent_classes_to_delete.count() 
        for obj in absent_classes_to_delete:
            obj.delete()

        # Notify the student
        if student.user:
            student_message = (
                f"{student_teacher_pronoun} {teacher.fullname} a annulé votre absence "
                f"pour {absent_classes_to_delete_count} séance(s) de "
                f"{group.teacher_subject.subject.name}."
            )            
            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message,
                meta_data={"group_id": group.id}
            )
            increment_student_unread_notifications(student)

        # Notify the parents
        child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
        for son in Son.objects.filter(student_teacher_enrollments__student=student).all():
            parent_message = (
                f"{parent_teacher_pronoun} {teacher.fullname} a annulé l’absence de "
                f"{child_pronoun} {son.fullname} pour {absent_classes_to_delete_count} "
                f"séance(s) de {group.teacher_subject.subject.name}."
            )
            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
                meta_data={"son_id": son.id, "group_id": group.id}
            )
            increment_parent_unread_notifications(son.parent)

    return Response({
        'success': True,
        'students_unmarked_completely_count': len(student_ids) - len(students_without_enough_absent_classes_to_unmark),
        'students_without_enough_absent_classes_to_unmark' : students_without_enough_absent_classes_to_unmark
    })

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def mark_payment(request, group_id):
    """Mark payment for selected students in a group"""
    teacher = request.user.teacher

    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)

    teacher_subject = group.teacher_subject

    student_ids = request.data.get('student_ids', [])
    if not student_ids:
        return Response({'error': 'No student IDs provided'}, status=400)

    num_classes_to_mark = request.data.get('number_of_classes')
    payment_datetime = request.data.get('payment_datetime')

    if not num_classes_to_mark or not isinstance(num_classes_to_mark, int) or num_classes_to_mark < 1:
        return Response({'error': 'Invalid number of classes to mark as paid'}, status=400)

    if not payment_datetime:
        return Response({'error': 'Payment datetime is required'}, status=400)

    payment_datetime = datetime.strptime(payment_datetime, "%H:%M:%S-%d/%m/%Y")

    students = group.students.filter(id__in=student_ids)
    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

    print("price per class  : ", teacher_subject.price_per_class)
    students_without_enough_classes_to_mark_their_payment = []

    for student in students:
        student_teacher_enrollment = TeacherEnrollment.objects.get(student=student, teacher=teacher)
        student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
        print(f"[before] attended non paid classes count : {student_group_enrollment.attended_non_paid_classes}")
        print(f"[before] student_teacher_enrollment.paid_amount : {student_teacher_enrollment.paid_amount}")
        print(f"[before] student_teacher_enrollment.unpaid_amount : {student_teacher_enrollment.unpaid_amount}")
        print(f"[before] student_group_enrollment.paid_amount : {student_group_enrollment.paid_amount}")
        print(f"[before] student_group_enrollment.unpaid_amount : {student_group_enrollment.unpaid_amount}")
        # get the attended classes that are not marked as paid yet
        attended_classes = Class.objects.filter(
            group_enrollment=student_group_enrollment,
            status__in=['attended_and_the_payment_due','attended_and_the_payment_not_due']
        ).order_by('attendance_date','attendance_start_time','id')
        attended_classes_count = attended_classes.count()
        
        missing_number_of_classes_to_mark = num_classes_to_mark - attended_classes_count
        if (missing_number_of_classes_to_mark > 0): 
            students_without_enough_classes_to_mark_their_payment.append({
                'id' : student.id,
                'image' : student.image.url,  
                'fullname': student.fullname,
                'missing_number_of_classes' : missing_number_of_classes_to_mark
            })

        attended_classes_to_mark_their_payment = attended_classes[:num_classes_to_mark]
        attended_classes_to_mark_their_payment_count = attended_classes_to_mark_their_payment.count()
        
        # Mark the payment for the classes that are already attended but not marked as paid
        for attended_class in attended_classes_to_mark_their_payment:

            # decrease the unpaid amount by the price of the class if it was due
            if attended_class.status == 'attended_and_the_payment_due' : 
                student_group_enrollment.unpaid_amount -= teacher_subject.price_per_class
                student_teacher_enrollment.unpaid_amount -= teacher_subject.price_per_class
                group.total_unpaid -= teacher_subject.price_per_class

            # mark the class as attended and paid
            attended_class.status = 'attended_and_paid'
            attended_class.paid_at = payment_datetime
            attended_class.save()

            # increase the paid amount by the price of the class 
            student_group_enrollment.paid_amount += teacher_subject.price_per_class
            student_teacher_enrollment.paid_amount += teacher_subject.price_per_class
            group.total_paid += teacher_subject.price_per_class

            # decrease the attended non paid classes 
            student_group_enrollment.attended_non_paid_classes -= 1 
            print(f"class with the id {attended_class.id} marked as paid")
            
        

        # correct the status of the remaining attended classes 
        print("attended_classes_count : ", attended_classes_count)
        print("num_classes_to_mark : ", num_classes_to_mark)
        if attended_classes_count - num_classes_to_mark > 0 :
            remaining_attended_classes = attended_classes[num_classes_to_mark:]
            remaining_attended_classes_count = remaining_attended_classes.count()
            number_of_classes_to_mark_as_non_due_payment = remaining_attended_classes_count % 4
            number_of_classes_to_mark_as_due_payment = remaining_attended_classes_count - number_of_classes_to_mark_as_non_due_payment
            print("remaining attended classes")
            print(remaining_attended_classes)
            print("remaining_attended_classes_count : ", remaining_attended_classes_count)
            for idx,remaining_attended_class in enumerate(remaining_attended_classes,start=1):
                if idx <= number_of_classes_to_mark_as_due_payment :
                    if remaining_attended_class.status == 'attended_and_the_payment_not_due' :
                        remaining_attended_class.status = 'attended_and_the_payment_due'
                        student_group_enrollment.unpaid_amount += teacher_subject.price_per_class
                        student_teacher_enrollment.unpaid_amount += teacher_subject.price_per_class
                        group.total_unpaid += teacher_subject.price_per_class
                        remaining_attended_class.save()
                else :
                    if remaining_attended_class.status == 'attended_and_the_payment_due' :
                        remaining_attended_class.status = 'attended_and_the_payment_not_due'
                        student_group_enrollment.unpaid_amount -= teacher_subject.price_per_class
                        student_teacher_enrollment.unpaid_amount -= teacher_subject.price_per_class
                        group.total_unpaid -= teacher_subject.price_per_class
                        remaining_attended_class.save()

        student_group_enrollment.save()
        student_teacher_enrollment.save()
        group.save()    

        print(f"[after] attended non paid classes count : {student_group_enrollment.attended_non_paid_classes}")
        print(f"[after] student_teacher_enrollment.paid_amount : {student_teacher_enrollment.paid_amount}")
        print(f"[after] student_teacher_enrollment.unpaid_amount : {student_teacher_enrollment.unpaid_amount}")
        print(f"[after] student_group_enrollment.paid_amount : {student_group_enrollment.paid_amount}")
        print(f"[after] student_group_enrollment.unpaid_amount : {student_group_enrollment.unpaid_amount}")
        
        # Notify the student
        if student.user:
            student_message = (
                f"{student_teacher_pronoun} {teacher.fullname} a marqué votre paiement "
                f"pour {attended_classes_to_mark_their_payment_count} séance(s) de "
                f"{group.teacher_subject.subject.name}."
            )
            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message,
                meta_data={"group_id": group.id}
            )
            increment_student_unread_notifications(student)

        # Notify the parents
        child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
        for son in Son.objects.filter(student_teacher_enrollments__student=student).all():
            parent_message = (
                f"{parent_teacher_pronoun} {teacher.fullname} a marqué le paiement de "
                f"{child_pronoun} {son.fullname} pour {attended_classes_to_mark_their_payment_count} "
                f"séance(s) de {group.teacher_subject.subject.name}."
            )
            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
                meta_data={"son_id": son.id, "group_id": group.id}
            )
            increment_parent_unread_notifications(son.parent)

    return Response({
        'success': True,
        'students_marked_completely_count': len(student_ids) - len(students_without_enough_classes_to_mark_their_payment),
        'students_without_enough_classes_to_mark_their_payment':students_without_enough_classes_to_mark_their_payment,
    })


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def unmark_payment(request, group_id):
    """Unmark payment for selected students in a group"""
    teacher = request.user.teacher

    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)

    teacher_subject = group.teacher_subject

    student_ids = request.data.get('student_ids', [])
    if not student_ids:
        return Response({'error': 'No student IDs provided'}, status=400)

    num_classes_to_unmark = request.data.get('number_of_classes')

    if not num_classes_to_unmark or not isinstance(num_classes_to_unmark, int) or num_classes_to_unmark < 1:
        return Response({'error': 'Invalid number of classes to unmark their payment'}, status=400)


    students = Student.objects.filter(id__in=student_ids)
    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

    students_without_enough_paid_classes_to_unmark = []
    for student in students:
        print("for student : ", student.fullname)
        student_teacher_enrollment = TeacherEnrollment.objects.get(student=student, teacher=teacher)
        student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)

        # i have to get the list of paid and attended classes to process 
        ## get all of the classes of the student 
        paid_classes = Class.objects.filter(
            group_enrollment=student_group_enrollment,
            status__in= ['attended_and_paid']
        )
        paid_classes_count = paid_classes.count()
        missing_number_of_paid_classes_to_unmark =  num_classes_to_unmark - paid_classes_count
        if missing_number_of_paid_classes_to_unmark > 0 : 
            students_without_enough_paid_classes_to_unmark.append({
                'id': student.id,
                'fullname': student.fullname,
                'image' : student.image.url,
                'missing_number_of_classes' : missing_number_of_paid_classes_to_unmark
            })

        if paid_classes_count == 0 :
            continue 

        ## get all of the attended classes of the student 
        attended_classes = Class.objects.filter(group_enrollment=student_group_enrollment,
                                                 status__in=['attended_and_the_payment_due','attended_and_the_payment_not_due'])
        attended_classes_count = attended_classes.count() 

        # calculate the start idx which starts to be at the first paid class to process
        start_idx = (paid_classes_count + attended_classes_count) - ( attended_classes_count + num_classes_to_unmark)
        start_idx = 0 if start_idx < 0 else start_idx
        
        paid_and_attended_classes = list(paid_classes) + list(attended_classes)
        paid_and_attended_classes = paid_and_attended_classes[start_idx:]
        print("\tthe paid_and_attended_classes to process : ")
        print(paid_and_attended_classes)
        paid_and_attended_classes_count = len(paid_and_attended_classes)
        print(f"\tpaid_and_attended_classes_count : {paid_and_attended_classes_count}")

        number_of_classes_to_mark_as_attended_and_not_due = paid_and_attended_classes_count % 4     
        number_of_classes_to_mark_as_attended_and_due = paid_and_attended_classes_count - number_of_classes_to_mark_as_attended_and_not_due

        real_number_of_classes_we_unmarked_their_payment = 0 
        unpaid_amount_did_increase = False
        # Unmark the payment of the specified number of classes 

        for idx,klass in enumerate(paid_and_attended_classes,start=1):
            # mark the classes with status attended_and_paid or attended_and_the_payment_not_due with 
            # the status attended_and_the_payment_due
            if idx <= number_of_classes_to_mark_as_attended_and_due :
                if klass.status == "attended_and_paid" : 
                    print(f"\tat the index : {idx} the class : {klass} will marked as attended_and_the_payment_due")
                    klass.status = "attended_and_the_payment_due"
                    klass.paid_at = None 
                    klass.save()
                    student_group_enrollment.attended_non_paid_classes += 1 
                    student_group_enrollment.paid_amount -= teacher_subject.price_per_class
                    student_group_enrollment.unpaid_amount += teacher_subject.price_per_class
                    student_teacher_enrollment.paid_amount -= teacher_subject.price_per_class
                    student_teacher_enrollment.unpaid_amount += teacher_subject.price_per_class
                    group.total_paid -= teacher_subject.price_per_class
                    group.total_unpaid += teacher_subject.price_per_class
                    real_number_of_classes_we_unmarked_their_payment += 1
                    unpaid_amount_did_increase = True

                elif klass.status == "attended_and_the_payment_not_due" : 
                    print(f"\tat the index : {idx} the class : {klass} will marked as attended_and_the_payment_due")
                    klass.status = "attended_and_the_payment_due" 
                    klass.save()
                    student_group_enrollment.unpaid_amount += teacher_subject.price_per_class
                    student_teacher_enrollment.unpaid_amount += teacher_subject.price_per_class
                    group.total_unpaid += teacher_subject.price_per_class
                    unpaid_amount_did_increase = True 
            else : 
                # mark the classes with the status attended_and_paid or attended_and_the_payment_due as attended_and_the_payment_not_due
                if klass.status == "attended_and_paid" : 
                    print(f"\tat the index : {idx} the class : {klass} will marked as attended_and_the_payment_not_due")
                    klass.status = "attended_and_the_payment_not_due"
                    klass.paid_at = None 
                    klass.save()
                    student_group_enrollment.attended_non_paid_classes += 1 
                    student_group_enrollment.paid_amount -= teacher_subject.price_per_class
                    student_teacher_enrollment.paid_amount -= teacher_subject.price_per_class
                    group.total_paid -= teacher_subject.price_per_class 
                    real_number_of_classes_we_unmarked_their_payment += 1
                elif klass.status == "attended_and_the_payment_due" :
                    print(f"\tat the index : {idx} the class : {klass} will marked as attended_and_the_payment_not_due")
                    klass.status = "attended_and_the_payment_not_due"
                    klass.save()
                    student_group_enrollment.unpaid_amount -= teacher_subject.price_per_class
                    student_teacher_enrollment.unpaid_amount -= teacher_subject.price_per_class
                    group.total_unpaid -= teacher_subject.price_per_class

                
        student_group_enrollment.save()
        student_teacher_enrollment.save()
        group.save()

        print("\tthe paid_and_attended_classes after the processing : ")
        print(paid_and_attended_classes)

        # Notify the student
        if student.user:
            student_message = (
                f"{student_teacher_pronoun} {teacher.fullname} a annulé "
                f"votre paiement pour {real_number_of_classes_we_unmarked_their_payment} séance(s) "
                f"de {group.teacher_subject.subject.name}"
            )
            if unpaid_amount_did_increase:
                student_message += (
                    f", et le montant impayé pour cette matière est désormais de "
                    f"{student_group_enrollment.unpaid_amount} DT."
                )
            else:
                student_message += "."

            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message,
                meta_data={"group_id": group.id}
            )
            increment_student_unread_notifications(student)

        # Notify the parents
        child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
        for son in Son.objects.filter(student_teacher_enrollments__student=student).all():
            parent_message = (
                f"{parent_teacher_pronoun} {teacher.fullname} a annulé le paiement pour "
                f"{real_number_of_classes_we_unmarked_their_payment} séance(s) de "
                f"{group.teacher_subject.subject.name} pour {child_pronoun} {son.fullname}"
            )
            if unpaid_amount_did_increase:
                parent_message += (
                    f", et le montant impayé pour cette matière est désormais de "
                    f"{student_group_enrollment.unpaid_amount} DT."
                )
            else:
                parent_message += "." 

            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
                meta_data={"son_id": son.id, "group_id": group.id}
            )
            increment_parent_unread_notifications(son.parent)

    return Response({
        'success': True,
        'students_unmarked_completely_count': len(student_ids) - len(students_without_enough_paid_classes_to_unmark),
        'students_without_enough_paid_classes_to_unmark' : students_without_enough_paid_classes_to_unmark
    })

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def mark_attendance_and_payment(request,group_id):
    """Mark attendance for selected students in a group"""
    # validate the request data
    student_ids = request.data.get('student_ids', [])
    print(f"student_ids : {student_ids}")
    print(f"group id  : {group_id}")
    if not student_ids:
        print("No student IDs provided")
        return Response({'error': 'No student IDs provided'}, status=400)

    attendance_date = request.data.get('date')
    attendance_start_time = request.data.get('start_time')
    attendance_end_time = request.data.get('end_time')
    payment_datetime = request.data.get('payment_datetime')

    
    if not attendance_date or not attendance_start_time or not attendance_end_time or not payment_datetime:
        print("The date, start time, end time and payment datetime are required")
        return Response({'error': 'The date, start time, end time and payment datetime are required'}, status=400)

    attendance_date = datetime.strptime(attendance_date, "%d/%m/%Y").date()
    attendance_start_time = datetime.strptime(attendance_start_time, "%H:%M").time()
    attendance_end_time = datetime.strptime(attendance_end_time, "%H:%M").time()
    payment_datetime = request.data.get('payment_datetime')

    teacher = request.user.teacher

    # check if the group exists and belongs to the teacher
    try:
        group = Group.objects.get(id=group_id, teacher=teacher)
    except Group.DoesNotExist:
        return Response({'error': 'Group not found'}, status=404)

    # check if these students are enrolled in the group of the teacher
    students = group.students.filter(id__in=student_ids, teacherenrollment__teacher=teacher)
    if not students.exists():
        return Response({'error': 'No students found in the group'}, status=404)

    teacher_subject = group.teacher_subject

    student_teacher_pronoun = "Votre professeur" if teacher.gender == "M" else "Votre professeure"
    parent_teacher_pronoun = "Le professeur" if teacher.gender == "M" else "La professeure"

    print("starting to mark attendance and payment for students...")
    students_with_overlapping_classes = []
    for student in students:

        # across all the classes of this student with this teacher, check if the attendance date and time overlaps with another class
        overlapping_classes = Class.objects.filter(
            group_enrollment__student=student,
            group_enrollment__group__teacher=teacher
        ).filter(
            Q(Q(absence_date=attendance_date) & Q(absence_start_time__lt=attendance_end_time) & Q(absence_end_time__gt=attendance_start_time)) |
            Q(Q(attendance_date=attendance_date) & Q(attendance_start_time__lt=attendance_end_time) & Q(attendance_end_time__gt=attendance_start_time))
        )
        if overlapping_classes.exists() : 
            overlapping_class = overlapping_classes.first()
            students_with_overlapping_classes.append({
                'id': student.id,
                'image': student.image.url,
                'fullname': student.fullname,
                'overlapping_class': [
                    {
                        'status': overlapping_class.status,
                        'date': overlapping_class.attendance_date if overlapping_class.attendance_date else overlapping_class.absence_date,
                        'start_time': overlapping_class.attendance_start_time if overlapping_class.attendance_start_time else overlapping_class.absence_start_time,
                        'end_time': overlapping_class.attendance_end_time if overlapping_class.attendance_end_time else overlapping_class.absence_end_time,
                    }
                ]
            })
            continue

        student_teacher_enrollment = TeacherEnrollment.objects.get(student=student, teacher=teacher)
        student_group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
        Class.objects.create(group_enrollment=student_group_enrollment,
                            attendance_date=attendance_date,
                            attendance_start_time=attendance_start_time,
                            attendance_end_time=attendance_end_time,
                            status = 'attended_and_paid',
                            paid_at = payment_datetime)
        # increase the paid amount by the price of the class 
        student_group_enrollment.paid_amount += teacher_subject.price_per_class
        student_teacher_enrollment.paid_amount += teacher_subject.price_per_class
        group.total_paid += teacher_subject.price_per_class
        student_group_enrollment.save()
        student_teacher_enrollment.save()
        group.save()

        # Notify the student
        if student.user:
            student_message = (
                f"{student_teacher_pronoun} {teacher.fullname.capitalize()} a marqué votre "
                f"présence et paiement pour la séance de {group.teacher_subject.subject.name} "
                f"qui a eu lieu le {attendance_date.strftime('%d/%m/%Y')} "
                f"de {attendance_start_time.strftime('%H:%M')} à {attendance_end_time.strftime('%H:%M')}."
            )
            StudentNotification.objects.create(
                student=student,
                image=teacher.image,
                message=student_message,
                meta_data={"group_id": group.id}
            )
            increment_student_unread_notifications(student)

        # Notify the parents
        child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
        for son in Son.objects.filter(student_teacher_enrollments__student=student).all():
            parent_message = (
               f"{parent_teacher_pronoun} {teacher.fullname.capitalize()} a marqué la présence et le paiement de "
               f"{child_pronoun} {son.fullname} pour la séance de {group.teacher_subject.subject.name} "
               f"qui a eu lieu le {attendance_date.strftime('%d/%m/%Y')} de "
               f"{attendance_start_time.strftime('%H:%M')} à {attendance_end_time.strftime('%H:%M')}."
            )   
            ParentNotification.objects.create(
                parent=son.parent,
                image=son.image,
                message=parent_message,
                meta_data={"son_id": son.id,"group_id": group.id}
            )
            increment_parent_unread_notifications(son.parent)


    return Response({
        'success': True,
        'students_with_overlapping_classes': students_with_overlapping_classes,
    })

"""


# Check if the student is already in a group with the same level, section, and subject
        student_groups = Group.objects.filter(
            students=student,
            teacher_subject=group.teacher_subject
        )
        if student_groups.exists():
            student_group = student_groups.first()
            student_group.students.remove(student)
            group.students.add(student)

            for student in group.students.all() :
                # Create notification for each student that has an independant account
                if student.user : 
                    student_message = f"{student_teacher_pronoun} {teacher.fullname} a changé votre groupe de {group.teacher_subject.subject.name}."
                    StudentNotification.objects.create(
                        student=student,
                        image=teacher.image,
                        message=student_message,
                        meta_data = {'group_id': group.id}
                    )
                    increment_student_unread_notifications(student)
                # If student has parents, notify them too
                child_pronoun = "votre fils" if student.gender == "M" else "votre fille"
                for son in Son.objects.filter(student_teacher_enrollments__student=student).all() :
                    # Assuming `son` has an attribute `gender` that can be 'male' or 'female'
                    parent_message = f"{parent_teacher_pronoun} {teacher.fullname} a changé le groupe de {group.teacher_subject.subject.name} de {child_pronoun} {son.fullname}."
                    ParentNotification.objects.create(
                        parent=son.parent,
                        image=son.image,
                        message=parent_message,
                        meta_data = {"son_id":son.id,'group_id':group.id}
                    )
                    increment_parent_unread_notifications(son.parent)
        else : 

        
        if student_group_enrollment.attended_non_paid_classes >= 3 : 
            # only when i have 3 non paid classes, mark them as attended_and_the_payment_due because since then we will mark the next class as attended_and_the_payment_due
            if student_group_enrollment.attended_non_paid_classes == 3 :
                Class.objects.filter(group_enrollment=student_group_enrollment, status='attended_and_the_payment_not_due').update(status='attended_and_the_payment_due')
                student_group_enrollment.unpaid_amount += teacher_subject.price_per_class * 3
                student_teacher_enrollment.unpaid_amount += teacher_subject.price_per_class * 3
                group.total_unpaid += teacher_subject.price_per_class * 3
            # create the next class as attended_and_the_payment_due
            Class.objects.create(group_enrollment=student_group_enrollment,
                                attendance_date=attendance_date,
                                attendance_start_time=attendance_start_time,
                                attendance_end_time=attendance_end_time,
                                status = 'attended_and_the_payment_due',
                                last_status_datetime = current_datetime)
            student_group_enrollment.unpaid_amount += teacher_subject.price_per_class
            student_teacher_enrollment.unpaid_amount += teacher_subject.price_per_class
            group.total_unpaid += teacher_subject.price_per_class
        else : 
            Class.objects.create(group_enrollment=student_group_enrollment,
                                attendance_date=attendance_date,
                                attendance_start_time=attendance_start_time,
                                attendance_end_time=attendance_end_time,
                                status = 'attended_and_the_payment_not_due',
                                last_status_datetime = current_datetime)
                            
        student_group_enrollment.attended_non_paid_classes += 1
        student_group_enrollment.save()
        student_teacher_enrollment.save()
        group.save()
        

                # check if all of the attended classes of the student are due 
        if student_group_enrollment.attended_non_paid_classes >= 4 :
            # since all of the the attended non paid classes of the student are due, remove the decrease the unpaid amount 
            # by the the number of classes to delete * price per class 
            student_group_enrollment.unpaid_amount -= teacher_subject.price_per_class * attended_classes_to_delete_count
            student_teacher_enrollment.unpaid_amount -= teacher_subject.price_per_class * attended_classes_to_delete_count
            group.total_unpaid -= teacher_subject.price_per_class * attended_classes_to_delete_count
            # if we still have less than 4 classes attended and their payment are due after deleting the classes
            # convert their status to attended and their payment not due and subtract their due unpaid amount from the unpaid amount of the student
            classes_to_not_delete_count = student_group_enrollment.attended_non_paid_classes - attended_classes_to_delete_count 
            if classes_to_not_delete_count > 0 and classes_to_not_delete_count < 4 : 
                Class.objects.filter(group_enrollment=student_group_enrollment, status='attended_and_the_payment_due').update(status='attended_and_the_payment_not_due')
                student_group_enrollment.unpaid_amount -= teacher_subject.price_per_class * classes_to_not_delete_count
                student_teacher_enrollment.unpaid_amount -= teacher_subject.price_per_class * classes_to_not_delete_count
                group.total_unpaid -= teacher_subject.price_per_class * classes_to_not_delete_count
        # remove the number of deleted classes from the attended non paid classes ones 
        student_group_enrollment.attended_non_paid_classes -= attended_classes_to_delete_count 
        student_group_enrollment.save()
        student_teacher_enrollment.save()


                    print(f"number_of_classes_to_create_and_mark_as_paid : {number_of_classes_to_create_and_mark_as_paid}")

            attended_classes_marked_as_paid_count = len(attended_classes[:num_classes_to_mark])
            total_number_of_classes_marked_as_paid = attended_classes_marked_as_paid_count + number_of_classes_to_create_and_mark_as_paid
            ## handle the finances 
            # if we have only attended and due payment classes 
            if student_group_enrollment.attended_non_paid_classes >= 4 : 
                
                # remove the unpaid amount of theses classes 
                student_group_enrollment.unpaid_amount -= teacher_subject.price_per_class * attended_classes_marked_as_paid_count
                student_teacher_enrollment.unpaid_amount -= teacher_subject.price_per_class * attended_classes_marked_as_paid_count
                group.total_unpaid -= teacher_subject.price_per_class * attended_classes_marked_as_paid_count
                # if number of due payment classes left after marking the payment is below 4 and higher than 0, convert them to not due payment classes
                attended_class_non_marked_as_paid_cnt = student_group_enrollment.attended_non_paid_classes - attended_classes_marked_as_paid_count
                if attended_class_non_marked_as_paid_cnt > 0 and attended_class_non_marked_as_paid_cnt < 4 : 
                    Class.objects.filter(group_enrollment=student_group_enrollment, status='attended_and_the_payment_due').update(status='attended_and_the_payment_not_due')
                    student_group_enrollment.unpaid_amount -= teacher_subject.price_per_class * attended_class_non_marked_as_paid_cnt
                    student_teacher_enrollment.unpaid_amount -= teacher_subject.price_per_class * attended_class_non_marked_as_paid_cnt
                    group.total_unpaid -= teacher_subject.price_per_class * attended_class_non_marked_as_paid_cnt
            
            student_group_enrollment.paid_amount += total_number_of_classes_marked_as_paid * teacher_subject.price_per_class
            student_teacher_enrollment.paid_amount += total_number_of_classes_marked_as_paid * teacher_subject.price_per_class
            group.total_paid += total_number_of_classes_marked_as_paid * teacher_subject.price_per_class
            student_group_enrollment.attended_non_paid_classes -= attended_classes_marked_as_paid_count
            student_group_enrollment.save()
            student_teacher_enrollment.save()
            group.save()
                

"""