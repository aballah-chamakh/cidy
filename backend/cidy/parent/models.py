from django.db import models
from account.models import User
from student.models import Student
from common.models import Level, Section

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
    student = models.ForeignKey(Student, on_delete=models.SET_NULL, null=True, blank=True, related_name='sons')
    fullname = models.CharField(max_length=255)
    gender = models.CharField(max_length=10, choices=(('M', 'Male'), ('F', 'Female')), default='M')
    level = models.ForeignKey(Level, on_delete=models.CASCADE)
    section = models.ForeignKey(Section, on_delete=models.CASCADE, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.fullname} -- {self.parent.user.email}"


class ParentNotification(models.Model):
    parent = models.ForeignKey(Parent, on_delete=models.CASCADE)
    image = models.ImageField(default='defaults/due_payment_notification.png')
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Notification for {self.teacher.fullname} - {self.created_at}"
    
