from student.models import  StudentUnreadNotification
from parent.models import  ParentUnreadNotification
from teacher.models import TeacherUnreadNotification

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

def increment_teacher_unread_notifications(teacher):
    """Helper function to increment teacher unread notifications count"""
    unread_obj, created = TeacherUnreadNotification.objects.get_or_create(teacher=teacher)
    unread_obj.unread_notifications += 1
    unread_obj.save()