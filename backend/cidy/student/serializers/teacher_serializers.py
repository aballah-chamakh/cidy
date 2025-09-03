from rest_framework import serializers
from teacher.models import Teacher, TeacherSubject

class TeacherListSerializer(serializers.ModelSerializer):
    subjects = serializers.SerializerMethodField()

    class Meta:
        model = Teacher
        fields = ['id', 'fullname', 'image', 'subjects']

    def get_subjects(self, teacher):
        student = self.context.get('student')
        return list(TeacherSubject.objects.filter(
            teacher=teacher,
            level=student.level,
            section=student.section if student.section else None
        ).values_list('subject__name', flat=True))