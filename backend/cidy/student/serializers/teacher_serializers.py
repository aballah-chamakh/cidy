from rest_framework import serializers
from teacher.models import Teacher, TeacherSubject


class TeacherSubjectListSerializer(serializers.ModelSerializer):
    # name of the subject
    name = serializers.CharField(source='subject.name', read_only=True)
    class Meta:
        model = TeacherSubject
        fields = ['id', 'name']


class TeacherListSerializer(serializers.ModelSerializer):
    subjects = serializers.SerializerMethodField()
    phone_number = serializers.CharField(source='user.phone_number',read_only=True)

    class Meta:
        model = Teacher
        fields = ['id', 'fullname', 'image', 'subjects']

    def get_subjects(self, teacher):
        student = self.context.get('student')
        # Get the teacher's subjects for the specific student level and section
        teacher_subjects = TeacherSubject.objects.filter(teacher=teacher,
                                                         level=student.level,
                                                         section=student.section if student.section else None)
        serializer = TeacherSubjectListSerializer(teacher_subjects, many=True)
        return serializer.data