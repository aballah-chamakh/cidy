from django.db import models
from account.models import User
from teacher.models import TeacherEnrollment
from teacher.models import Level
from django.db.models.signals import post_save
from django.dispatch import receiver

class Parent(models.Model):
    image = models.ImageField(default='defaults/parent.png', upload_to='parent_images/', null=True, blank=True)
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    fullname = models.CharField(max_length=255)
    gender = models.CharField(max_length=10, choices=(('M', 'Male'), ('F', 'Female')), default='M')
    join_date = models.DateField(auto_now_add=True)

    def __str__(self):
        return f"{self.fullname} -- {self.user.email}"
    
class Son(models.Model):
    image = models.ImageField(default='defaults/son.jpg', upload_to='son_images/', null=True, blank=True)
    parent = models.ForeignKey(Parent, on_delete=models.CASCADE)
    student_teacher_enrollments = models.ManyToManyField(TeacherEnrollment)
    fullname = models.CharField(max_length=255)
    gender = models.CharField(max_length=10, choices=(('M', 'Male'), ('F', 'Female')), default='M')
    level = models.ForeignKey(Level, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.fullname} -- {self.parent.user.email}"


class ParentUnreadNotification(models.Model):
    parent = models.ForeignKey(Parent, on_delete=models.CASCADE)
    unread_notifications = models.PositiveIntegerField(default=0)

class ParentNotification(models.Model):
    parent = models.ForeignKey(Parent, on_delete=models.CASCADE)
    image = models.ImageField(default='defaults/due_payment_notification.png')
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    meta_data = models.JSONField(default=dict)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Notification for {self.teacher.fullname} - {self.created_at}"
    
@receiver(post_save, sender=Parent)
def create_parent_unread_notification(sender, instance, created, **kwargs):
    if created:
        ParentUnreadNotification.objects.create(parent=instance)