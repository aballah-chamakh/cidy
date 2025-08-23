from django.db import models
from account.models import User
from student.models import Student
from common.models import Level, Section,Subject

class Teacher(models.Model):
    image = models.ImageField(default='defaults/teacher.png',upload_to='teacher_images/')
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    fullname = models.CharField(max_length=255)
    gender = models.CharField(max_length=10, choices=(('M', 'Male'), ('F', 'Female')), default='M')
    join_date = models.DateField(auto_now_add=True)

    def __str__(self):
        return f"{self.fullname} -- {self.user.email}"
    

class Group(models.Model):
    teacher = models.ForeignKey(Teacher, on_delete=models.CASCADE)
    name = models.CharField(max_length=100)
    level = models.ForeignKey(Level, on_delete=models.CASCADE)
    section = models.ForeignKey(Section, on_delete=models.CASCADE, null=True,blank=True)
    subject = models.ForeignKey(Subject, on_delete=models.CASCADE)
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
    start_time_range = models.DecimalField(max_digits=4, decimal_places=2) # format : HH:MM
    end_time_range = models.DecimalField(max_digits=4, decimal_places=2) # format : HH:MM
    temporary_week_day = models.CharField(max_length=50, choices=[
        ('Monday', 'Monday'),
        ('Tuesday', 'Tuesday'),
        ('Wednesday', 'Wednesday'),
        ('Thursday', 'Thursday'),
        ('Friday', 'Friday'),
        ('Saturday', 'Saturday'),
        ('Sunday', 'Sunday'),
    ], null=True)
    temporary_start_time_range = models.DecimalField(max_digits=4, decimal_places=2, null=True, blank=True) # format : HH:MM
    temporary_end_time_range = models.DecimalField(max_digits=4, decimal_places=2, null=True, blank=True) # format : HH:MM
    clear_temporary_schedule_at = models.DateTimeField(null=True, blank=True)
    students = models.ManyToManyField(Student,through="Enrollment",related_name="groups")


    def __str__(self):
        return f"{self.subject.name} group : {self.name}"

class Enrollment(models.Model):
    student = models.ForeignKey(Student, on_delete=models.CASCADE)
    group = models.ForeignKey(Group, on_delete=models.CASCADE)
    date = models.DateField(auto_now_add=True)

    def __str__(self):
        return f"{self.student.fullname} enrolled in {self.group.name}"
    
    class Meta:
        unique_together = ('student', 'group')

class Finance(models.Model):
    enrollment = models.OneToOneField(Enrollment, on_delete=models.CASCADE)
    paid_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    unpaid_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)

    def __str__(self):
        return f"Finance record for {self.enrollment.student.fullname} in {self.enrollment.group.name}"

class ClassBatch(models.Model):
    enrollment = models.ForeignKey(Enrollment, on_delete=models.CASCADE)
    status = models.CharField(
        max_length=20,
        choices=(
            ('paid', 'Paid'),
            ('not_due', 'Not Due'),
            ('not_paid', 'Not Paid'),
            ('partially_paid', 'Partially Paid'),
        ),
        default='not_due'
    )

    def __str__(self):
        return f"Class Batch for {self.enrollment.student.fullname} in {self.enrollment.group.name} - {self.status}"

class Class(models.Model):
    batch = models.ForeignKey(ClassBatch, on_delete=models.CASCADE)
    status = models.CharField(
        max_length=50,
        choices=(
            ('future', 'Future'),
            ('attended_and_paid', 'Attended & paid'),     
            ('attended_and_the_payment_not_due', 'Attended & the payment not due'), 
            ('attended_and_the_payment_due', 'Attended & the payment due')
        )
    )
    last_status_update = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Class for {self.batch.enrollment.group.name} - {self.status}"


class TeacherSubject(models.Model): 
    teacher = models.ForeignKey(Teacher, on_delete=models.CASCADE)
    level = models.ForeignKey(Level, on_delete=models.CASCADE)
    section = models.ForeignKey(Section, on_delete=models.CASCADE,null=True,blank=True)
    subject = models.ForeignKey(Subject, on_delete=models.CASCADE)
    price = models.DecimalField(max_digits=10, decimal_places=2, default=0)

    def __str__(self):
        return f"{self.teacher.fullname} teaches {self.subject.name}"
    

class TeacherNotification(models.Model):
    teacher = models.ForeignKey(Teacher, on_delete=models.CASCADE)
    image = models.ImageField(default='defaults/due_payment_notification.png')
    message = models.TextField()
    meta_data = models.JSONField(null=True, blank=True)
    type = models.CharField(max_length=50, choices=[
        ('due_payment', 'Due payment'),
        ('student', 'Student'),
        ('parent', 'Parent'),
    ])
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Notification for {self.teacher.fullname} - {self.created_at}"