from django.db import models
from account.models import User
from common.models import Level, Section

class Student(models.Model):
    image = models.ImageField(default='defaults/student.png',upload_to='student_images/')
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    fullname = models.CharField(max_length=255)
    phone_number = models.CharField(max_length=8, null=True)
    gender = models.CharField(max_length=10, choices=(('M', 'Male'), ('F', 'Female')), default='M')
    level = models.ForeignKey(Level, on_delete=models.CASCADE) 
    section = models.ForeignKey(Section, on_delete=models.CASCADE, null=True, blank=True)
    join_date = models.DateField(auto_now_add=True)

    def __str__(self):
        return f"{self.fullname} -- {self.user.email}"


class StudentNotification(models.Model):
    student = models.ForeignKey(Student, on_delete=models.CASCADE)
    image = models.ImageField(default='defaults/due_payment_notification.png')
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Notification for {self.parent.fullname} - {self.created_at}"