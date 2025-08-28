from rest_framework import serializers
from student.models import Student

class TeacherStudentListSerializer(serializers.ModelSerializer):
    image = serializers.CharField(source='image.url')
    paid_amount = serializers.DecimalField(max_digits=10, decimal_places=2,read_only=True)
    unpaid_amount = serializers.DecimalField(max_digits=10, decimal_places=2,read_only=True)
    subjects = serializers.SerializerMethodField()
    class Meta:
        model = Student
        fields = ['id', 'fullname', 'image', 'level', 'section', 'subjects', 'paid_amount', 'unpaid_amount']

    def get_subjects(self, student):
        request = self.context['request']
        teacher = request.user.teacher
        subjects = []
        for subject in student.groupenrollment_set.filter(group__teacher=teacher):
            subjects.append(subject.name)
        return subjects
    
class TeacherStudentCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Student
        fields = ['image','fullname', 'phone_number', 'gender', 'level', 'section']


class TeacherStudentDetailSerializer(serializers.ModelSerializer):
    student_level_finance = serializers.SerializerMethodField()
    group_level_finance = serializers.SerializerMethodField()
    groups = serializers.SerializerMethodField()

    class Meta:
        model = Student
        fields = [
            'id', 'image', 'fullname', 'level', 'section', 'phone_number',
            'paid_amount', 'unpaid_amount', 'groups'
        ]

    def get_student_level_finance(self, student):
        teacher = self.context['request'].user.teacher
        student_teacher_enrollment = TeacherEnrollment.objects.get(teacher=teacher, student=student)
        return {
            'paid_amount': student_teacher_enrollment.paid_amount,
            'unpaid_amount': student_teacher_enrollment.unpaid_amount
        }


    def get_groups(self, obj):
        groups = obj.groups.all()
        return [
            {
                'id': group.id,
                'label': f"{group.subject.name} - {group.name}",
                'paid_amount': GroupEnrollment.objects.filter(student=obj, group=group).aggregate(
                    total_paid=Sum('paid_amount')
                )['total_paid'] or 0,
                'unpaid_amount': GroupEnrollment.objects.filter(student=obj, group=group).aggregate(
                    total_unpaid=Sum('unpaid_amount')
                )['total_unpaid'] or 0,
            }
            for group in groups
        ]