from rest_framework import serializers
from student.models import Student
from teacher.models import TeacherEnrollment,GroupEnrollment,Class

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


class TeacherClassListSerializer(serializers.ModelSerializer):
    class Meta:
        model = Class
        fields = ['id', 'status', 'attendance_date', 'attendance_start_time','attendance_end_time','paid_at']   

class TeacherStudentDetailSerializer(serializers.ModelSerializer):
    student_level_finance = serializers.SerializerMethodField()
    groups = serializers.SerializerMethodField()

    class Meta:
        model = Student
        fields = [
            'id', 'image', 'fullname', 'level', 'section', 'phone_number',
            'paid_amount', 'unpaid_amount', 'groups'
        ]

    def get_student_level_finance(self, student_obj):
        teacher = self.context['request'].user.teacher
        student_teacher_enrollment = student_obj.teacherenrollment_set.get(teacher=teacher)
        return {
            'paid_amount': student_teacher_enrollment.paid_amount,
            'unpaid_amount': student_teacher_enrollment.unpaid_amount
        }


    def get_groups(self, student_obj):
        request = self.context['request']
        teacher_obj = request.user.teacher
        group_id = request.parser_context['kwargs'].get('group_id')
        
        groups = student_obj.groups.all(teacher=teacher_obj)
        json_groups = []

        for group in groups:
            json_group = {
                'id': group.id,
                'label': f"{group.teacher_subject.subject.name} - {group.name}",
            }
            if group.id == group_id :
                student_group_enrollment = group.groupenrollment_set.get(student=student_obj)
                json_group['paid_amount'] = student_group_enrollment.paid_amount
                json_group['unpaid_amount'] = student_group_enrollment.unpaid_amount
                json_group['classes'] =  TeacherClassListSerializer(student_group_enrollment.class_set.all(), many=True).data
            
            json_groups.append(json_group)

        return json_groups      
