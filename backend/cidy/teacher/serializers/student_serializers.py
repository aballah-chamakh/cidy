from rest_framework import serializers
from student.models import Student
from teacher.models import Class,Level, TeacherEnrollment, Group, GroupEnrollment
from django.utils import timezone


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
    level = serializers.CharField(write_only=True)
    section = serializers.CharField(write_only=True,allow_blank=True)
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

    def validate_phone_number(self, value):
        teacher = self.context['request'].user.teacher
        # Ensure phone number is unique
        if Student.objects.filter(teacherenrollment__teacher=teacher, phone_number=value).exists():
            raise serializers.ValidationError("student with this phone number already exists.")
        return value


class TeacherStudentUpdateSerializer(serializers.ModelSerializer):
    level = serializers.CharField(write_only=True)
    section = serializers.CharField(write_only=True,allow_blank=True)

    class Meta:
        model = Student
        fields = ['image', 'fullname', 'phone_number', 'gender', 'level', 'section']

    def validate(self, attrs):
        print("validate called")
        print(attrs)
        level = attrs.get('level')
        section = attrs.get('section')

        if level or section :
            level = Level.objects.get(name=level, section=section)
            print(level)
            attrs['level'] = level

        if 'section' in attrs:
            attrs.pop('section')

        return attrs
    
    def validate_phone_number(self, value):
        teacher = self.context['request'].user.teacher
        # Ensure phone number is unique
        if Student.objects.filter(teacherenrollment__teacher=teacher, phone_number=value).exclude(id=self.instance.id).exists():
            raise serializers.ValidationError("student with this phone number already exists.")
        return value

class TeacherClassListSerializer(serializers.ModelSerializer):
    class Meta:
        model = Class
        fields = ['id', 'status', 'attendance_date', 'attendance_start_time','attendance_end_time','absence_date','absence_start_time','absence_end_time','paid_at']   

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
            'gender',
            'paid_amount', 'unpaid_amount', 'groups'
        ]

    def get_paid_amount(self, student_obj):
        teacher = self.context['request'].user.teacher
        enrollment = TeacherEnrollment.objects.get(teacher=teacher, student=student_obj)
        return str(enrollment.paid_amount if enrollment else 0)

    def get_unpaid_amount(self, student_obj):
        teacher = self.context['request'].user.teacher
        enrollment = TeacherEnrollment.objects.get(teacher=teacher, student=student_obj)
        return str(enrollment.unpaid_amount if enrollment else 0)

    def get_groups(self, student_obj):
        teacher = self.context['request'].user.teacher
        
        # Get all groups the student is enrolled in with the current teacher
        student_groups = Group.objects.filter(
            teacher=teacher, 
            students=student_obj
        )

        group_data = []
        today = timezone.localdate()

        for group in student_groups:
            enrollment = GroupEnrollment.objects.get(group=group, student=student_obj)
            
            group_info = {
                'id': group.id,
                'name': group.name,
                'label': f"{group.teacher_subject.subject.name} - {group.name}",
                'paid_amount': str(enrollment.paid_amount),
                'unpaid_amount': str(enrollment.unpaid_amount),
                'week_day': group.week_day,
                'start_time': group.start_time.strftime('%H:%M'),
                'end_time': group.end_time.strftime('%H:%M'),
                'classes': TeacherClassListSerializer(enrollment.class_set.all(), many=True).data
            }

            if group.clear_temporary_schedule_at and today < group.clear_temporary_schedule_at:
                group_info['temporary_shedule'] = {
                    'week_day': group.temporary_week_day,
                    'start_time': group.temporary_start_time.strftime('%H:%M'),
                    'end_time': group.temporary_end_time.strftime('%H:%M'),
                }

            group_data.append(group_info)
            
        return group_data      
