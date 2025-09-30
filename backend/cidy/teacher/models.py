from django.utils import timezone
from django.db import models
from account.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver

class Level(models.Model):
    name = models.CharField(max_length=100)

    def __str__(self):
        return self.name

class Section(models.Model):
    image = models.ImageField(null=True, blank=True)
    name = models.CharField(max_length=100)
    #level = models.ForeignKey(Level, on_delete=models.CASCADE)

    def __str__(self):
        return self.name

class Subject(models.Model):
    name = models.CharField(max_length=100)
    #level = models.ForeignKey(Level, on_delete=models.CASCADE,null=True, blank=True)
    #section = models.ForeignKey(Section, on_delete=models.CASCADE,null=True, blank=True)

    def __str__(self):
        return self.name

class Teacher(models.Model):
    image = models.ImageField(default='defaults/teacher.png',upload_to='teacher_images/')
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    fullname = models.CharField(max_length=255)
    gender = models.CharField(max_length=10, choices=(('M', 'Male'), ('F', 'Female')), default='M')
    join_datetime = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.fullname} -- {self.user.email}"
    

class TeacherSubject(models.Model): 
    teacher = models.ForeignKey(Teacher, on_delete=models.CASCADE)
    level = models.ForeignKey(Level, on_delete=models.CASCADE)
    section = models.ForeignKey(Section, on_delete=models.CASCADE,null=True,blank=True)
    subject = models.ForeignKey(Subject, on_delete=models.CASCADE)
    price_per_class = models.DecimalField(max_digits=10, decimal_places=2, default=0)

    def __str__(self):
        return f"{self.teacher.fullname} teaches {self.subject.name}"
    

class TeacherEnrollment(models.Model):
    teacher = models.ForeignKey(Teacher, on_delete=models.CASCADE)
    student = models.ForeignKey('student.Student', on_delete=models.CASCADE)
    paid_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    unpaid_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    date = models.DateField(auto_now_add=True)

    class Meta:
        unique_together = ('teacher', 'student')

class Group(models.Model):
    teacher = models.ForeignKey(Teacher, on_delete=models.CASCADE)
    name = models.CharField(max_length=100)
    teacher_subject = models.ForeignKey(TeacherSubject, on_delete=models.CASCADE)
    week_day = models.CharField(
        max_length=50,
        choices=[
            ('Monday', 'Monday'),
            ('Tuesday', 'Tuesday'),
            ('Wednesday', 'Wednesday'),
            ('Thursday', 'Thursday'),
            ('Friday', 'Friday'),
            ('Saturday', 'Saturday'),
            ('Sunday', 'Sunday'),
        ],
        default='Monday'
    )
    start_time = models.TimeField()
    end_time = models.TimeField()
    
    temporary_week_day = models.CharField(max_length=50, choices=[
        ('Monday', 'Monday'),
        ('Tuesday', 'Tuesday'),
        ('Wednesday', 'Wednesday'),
        ('Thursday', 'Thursday'),
        ('Friday', 'Friday'),
        ('Saturday', 'Saturday'),
        ('Sunday', 'Sunday'),
    ], null=True)
    temporary_start_time = models.TimeField(null=True, blank=True)
    temporary_end_time = models.TimeField(null=True, blank=True)
    clear_temporary_schedule_at = models.DateTimeField(null=True, blank=True)
    students = models.ManyToManyField('student.Student',through="GroupEnrollment",related_name="groups")
    total_paid = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    total_unpaid = models.DecimalField(max_digits=10, decimal_places=2, default=0)

    def __str__(self):
        return f"{self.teacher_subject.subject.name} group : {self.name}"
    
class GroupEnrollment(models.Model):
    student = models.ForeignKey('student.Student', on_delete=models.CASCADE)
    group = models.ForeignKey(Group, on_delete=models.CASCADE)
    date = models.DateField(default=timezone.now)
    paid_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    unpaid_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    attended_non_paid_classes = models.IntegerField(default=0)
    def __str__(self):
        return f"{self.student.fullname} enrolled in {self.group.name}"
    
    class Meta:
        unique_together = ('student', 'group')


class Class(models.Model):
    group_enrollment = models.ForeignKey(GroupEnrollment, on_delete=models.CASCADE)
    status = models.CharField(
        max_length=50,
        choices=(
            ('attended_and_paid', 'Attended & paid'),     
            ('attended_and_the_payment_not_due', 'Attended & the payment not due'), 
            ('attended_and_the_payment_due', 'Attended & the payment due'),
            ('absent', 'Absent')
        ),
    )
    attendance_date = models.DateField(null=True, blank=True)
    attendance_start_time = models.TimeField(null=True, blank=True)
    attendance_end_time = models.TimeField(null=True, blank=True)
    #absence_date = models.DateField(null=True, blank=True)
    absence_start_time = models.TimeField(null=True, blank=True)
    absence_end_time = models.TimeField(null=True, blank=True)
    #paid_at = models.DateTimeField(null=True, blank=True)
    last_status_date = models.DateTimeField(default=timezone.now)

    def __str__(self):
        return f"Class for {self.group_enrollment.group.name} - {self.status}"

class TeacherUnreadNotification(models.Model):
    teacher = models.OneToOneField(Teacher, on_delete=models.CASCADE)
    unread_notifications = models.PositiveIntegerField(default=0)

    def __str__(self):
        return f"{self.teacher.fullname} - Unread Notifications: {self.unread_notifications}"

class TeacherNotification(models.Model):
    teacher = models.ForeignKey(Teacher, on_delete=models.CASCADE)
    image = models.ImageField(default='defaults/due_payment_notification.png')
    message = models.TextField()
    meta_data = models.JSONField(null=True, blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Notification for {self.teacher.fullname} - {self.created_at}"
    

@receiver(post_save, sender=Teacher)
def create_teacher_unread_notification(sender, instance, created, **kwargs):
    if created:
        TeacherUnreadNotification.objects.create(teacher=instance)