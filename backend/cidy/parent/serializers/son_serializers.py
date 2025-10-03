from datetime import datetime 
from rest_framework import serializers
from teacher.models import GroupEnrollment,Level
from teacher.serializers import TeacherClassListSerializer
from ..models import Son

class SonListSerializer(serializers.ModelSerializer):
    image = serializers.CharField(source='image.url', read_only=True)
    level = serializers.CharField(source='level.name', read_only=True)
    section = serializers.CharField(source='section.name', read_only=True)
    has_student = serializers.SerializerMethodField()

    class Meta:
        model = Son
        fields = ['id', 'image', 'fullname', 'level','gender', 'section', 'has_student']

    def get_has_student(self, obj):
        return obj.student.exists()
    

class SonSubjectListSerializer(serializers.ModelSerializer):
    image = serializers.CharField(source='group.teacher_subject.subject.image.url', read_only=True)
    name = serializers.CharField(source='group.teacher_subject.subject.name', read_only=True)
    teacher_name = serializers.CharField(source='group.teacher.fullname', read_only=True)
    schedule = serializers.SerializerMethodField()
    monthly_price = serializers.SerializerMethodField()

    class Meta:
        model = GroupEnrollment
        fields = ['id','image','name', 'teacher_name', 'schedule', 'monthly_price','paid_amount','unpaid_amount']

    def get_schedule(self, group_enrollment):
        schedule = {}
        if group_enrollment.clear_temporary_schedule_at and group_enrollment.clear_temporary_schedule_at > datetime.now():
            schedule['temporary'] = {
                "week_day": group_enrollment.group.temporary_week_day,
                "start_time": group_enrollment.group.temporary_start_time,
                "end_time": group_enrollment.group.temporary_end_time,
            }
        schedule['permanent'] = {
            "week_day": group_enrollment.group.week_day,
            "start_time": group_enrollment.group.start_time,
            "end_time": group_enrollment.group.end_time,
        }
        return schedule

    def get_monthly_price(self, group_enrollment):
        return group_enrollment.group.teacher_subject.price_per_class * 4  # Assuming 4 classes a month

class SonDetailSerializer(serializers.ModelSerializer):
    image = serializers.CharField(source='image.url', read_only=True)
    level = serializers.CharField(source='level.name', read_only=True)
    section = serializers.CharField(source='section.name', read_only=True)
    subjects = serializers.SerializerMethodField()
    has_student = serializers.SerializerMethodField()

    class Meta:
        model = Son
        fields = ['id', 'image', 'fullname', 'level', 'section', 'has_student']

    def get_subjects(self, son):
        # get son's student teacher enrollments
        son_student_teacher_enrollments = son.student_teacher_enrollments.all()
        if not son_student_teacher_enrollments.exists():
            return []
        
        # get the group enrollment related to each student_teacher_enrollment of the son 
        student_group_enrollments = GroupEnrollment.objects.none() 
        for son_student_teacher_enrollment in son_student_teacher_enrollments:
            student_group_enrollments |= GroupEnrollment.objects.filter(student=son_student_teacher_enrollment.student, group__teacher=son_student_teacher_enrollment.teacher)
        
        serializer = SonSubjectListSerializer(student_group_enrollments, many=True)
        son_subjects = serializer.data
        return son_subjects
    
    def get_has_student(self, son):
        return son.student_teacher_enrollments.exists()


class SonSubjectDetailSerializer(serializers.ModelSerializer):
    image = serializers.CharField(source='group.teacher_subject.subject.image.url', read_only=True)
    name = serializers.CharField(source='group.teacher_subject.subject.name', read_only=True)
    teacher_name = serializers.CharField(source='group.teacher.fullname', read_only=True)
    schedule = serializers.SerializerMethodField()
    monthly_price = serializers.SerializerMethodField()

    class Meta:
        model = GroupEnrollment
        fields = ['id','image','name', 'teacher_name', 'schedule', 'monthly_price','paid_amount','unpaid_amount']

    def get_schedule(self, group_enrollment):
        schedule = {}
        if group_enrollment.clear_temporary_schedule_at and group_enrollment.clear_temporary_schedule_at > datetime.now():
            schedule['temporary'] = {
                "week_day": group_enrollment.group.temporary_week_day,
                "start_time": group_enrollment.group.temporary_start_time,
                "end_time": group_enrollment.group.temporary_end_time,
            }
        schedule['permanent'] = {
            "week_day": group_enrollment.group.week_day,
            "start_time": group_enrollment.group.start_time,
            "end_time": group_enrollment.group.end_time,
        }
        return schedule

    def get_monthly_price(self, group_enrollment):
        return group_enrollment.group.teacher_subject.price_per_class * 4  # Assuming 4 classes a month

    def get_classes(self, group_enrollment):
        classes_qs = group_enrollment.class_set.all()
        return TeacherClassListSerializer(classes_qs, many=True).data


class TesLevelsSectionsSerializer(serializers.ModelSerializer):

    class Meta:
        model = Level
        fields = ['id', 'name', 'section']
    

class SonCreateEditSerializer(serializers.ModelSerializer):
    class Meta:
        model = Son
        fields = ['id','image','fullname','gender', 'level', 'section']
