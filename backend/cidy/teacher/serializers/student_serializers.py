from rest_framework import serializers
from student.models import Student
from teacher.models import Class,Level, TeacherEnrollment, Group, GroupEnrollment

class TeacherStudentListSerializer(serializers.ModelSerializer):
    image = serializers.CharField(source='image.url')
    paid_amount = serializers.DecimalField(max_digits=10, decimal_places=2,read_only=True)
    unpaid_amount = serializers.DecimalField(max_digits=10, decimal_places=2,read_only=True)
    level = serializers.CharField(source='level.name')
    section = serializers.CharField(source='level.section')
    class Meta:
        model = Student
        fields = ['id', 'fullname', 'image', 'level', 'section', 'paid_amount', 'unpaid_amount']


    
class TeacherStudentCreateSerializer(serializers.ModelSerializer):
    level = serializers.CharField( write_only=True)
    section = serializers.CharField( write_only=True)
    class Meta:
        model = Student
        fields = ['image','fullname', 'phone_number', 'gender', 'level', 'section']
    
    def validate(self, attrs):
        print(attrs)
        level_name = attrs['level']
        section_name = attrs['section']
        del attrs['section']
        attrs['level'] = Level.objects.get(name=level_name, section=section_name)
        return attrs


class TeacherClassListSerializer(serializers.ModelSerializer):
    class Meta:
        model = Class
        fields = ['id', 'status', 'attendance_date', 'attendance_start_time','attendance_end_time','paid_at']   

class TeacherStudentDetailSerializer(serializers.ModelSerializer):
    paid_amount = serializers.SerializerMethodField()
    unpaid_amount = serializers.SerializerMethodField()
    groups = serializers.SerializerMethodField()
    level = serializers.CharField(source='level.name')
    section = serializers.CharField(source='level.section')
    image = serializers.CharField(source='image.url')
    class Meta:
        model = Student
        fields = [
            'id', 'image', 'fullname', 'level', 'section', 'phone_number',
            'paid_amount', 'unpaid_amount', 'groups'
        ]

    def get_paid_amount(self, student_obj):
        teacher = self.context['request'].user.teacher
        enrollment = TeacherEnrollment.objects.filter(teacher=teacher, student=student_obj).first()
        return enrollment.paid_amount if enrollment else 0

    def get_unpaid_amount(self, student_obj):
        teacher = self.context['request'].user.teacher
        enrollment = TeacherEnrollment.objects.filter(teacher=teacher, student=student_obj).first()
        return enrollment.unpaid_amount if enrollment else 0

    def get_groups(self, student_obj):
        teacher = self.context['request'].user.teacher
        
        # Get all groups the student is enrolled in with the current teacher
        student_groups = Group.objects.filter(
            teacher=teacher, 
            students=student_obj
        )

        group_data = []
        for group in student_groups:
            enrollment = GroupEnrollment.objects.get(group=group, student=student_obj)
            group_info = {
                'id': group.id,
                'name': group.name,
                'label': f"{group.teacher_subject.subject.name} - {group.name}",
                'paid_amount': enrollment.paid_amount,
                'unpaid_amount': enrollment.unpaid_amount,
                'week_day': group.week_day,
                'start_time': group.start_time.strftime('%H:%M'),
                'end_time': group.end_time.strftime('%H:%M'),
                'classes': TeacherClassListSerializer(enrollment.class_set.all(), many=True).data
            }
            group_data.append(group_info)
            
        return group_data      
