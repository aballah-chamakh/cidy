from student.models import Student
from teacher.models import Group,Class,GroupEnrollment

student_id = 6666
group_id = 2391

student = Student.objects.get(id=student_id)
group = Group.objects.get(id=group_id)
group_enrollment = GroupEnrollment.objects.get(student=student,group=group)

classes = Class.objects.filter(group_enrollment=group_enrollment)
print(classes)
print(classes.count())