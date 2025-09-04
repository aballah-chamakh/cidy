from datetime import datetime
from rest_framework import serializers
from teacher.models import GroupEnrollment
from teacher.serializers import TeacherClassListSerializer

class StudentSubjectListSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source='group.teacher_subject.subject.name', read_only=True)
    teacher_name = serializers.CharField(source='group.teacher.fullname', read_only=True)
    schedule = serializers.SerializerMethodField()
    monthly_price = serializers.SerializerMethodField()


    class Meta:
        model = GroupEnrollment
        fields = ['id','name', 'teacher_name', 'schedule', 'monthly_price','paid_amount','unpaid_amount']

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


class StudentSubjectDetailSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source='group.teacher_subject.subject.name', read_only=True)
    teacher_name = serializers.CharField(source='group.teacher.fullname', read_only=True)
    schedule = serializers.SerializerMethodField()
    monthly_price = serializers.SerializerMethodField()
    classes = serializers.SerializerMethodField()

    class Meta:
        model = GroupEnrollment
        fields = ['name', 'teacher_name', 'schedule', 'monthly_price','paid_amount','unpaid_amount','classes']

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