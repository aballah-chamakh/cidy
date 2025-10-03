from rest_framework import serializers
from teacher.models import Level
from teacher.serializers import SubjectSerializer
from teacher.models import Teacher, TeacherSubject



class TesLevelsSectionsSubjectsSerializer(serializers.ModelSerializer):
    subjects = SubjectSerializer(many=True)
    class Meta:
        model = Level
        fields = ['id', 'name', 'section','subjects']





class TeacherSubjectListSerializer(serializers.ModelSerializer):
    # name of the subject
    name = serializers.CharField(source='subject.name', read_only=True)
    class Meta:
        model = TeacherSubject
        fields = ['name']


class TeacherListSerializer(serializers.ModelSerializer):
    image = serializers.ImageField(source='image.url', read_only=True)
    phone_number = serializers.CharField(source='user.phone_number',read_only=True)
    subjects = serializers.SerializerMethodField()
    levels_and_sections = serializers.SerializerMethodField()

    class Meta:
        model = Teacher
        fields = ['id','phone_number','fullname', 'image', 'subjects', 'levels_and_sections']

    def get_subjects(self, teacher):
        # Get the teacher's subjects for the specific student level and section
        teacher_subjects = TeacherSubject.objects.filter(teacher=teacher).distinct('subject')
        serializer = TeacherSubjectListSerializer(teacher_subjects, many=True)
        return serializer.data

    def get_levels_and_sections(self, teacher):
        teacher_subjects = TeacherSubject.objects.filter(teacher=teacher).select_related('level', 'section')
        unique_combinations_of_levels_and_sections = {}

        for ts in teacher_subjects:
            level_id = ts.level.id
            section_id = ts.section.id if ts.section else None

            unique_key = str(level_id) + '_' + str(section_id)
            if unique_key not in unique_combinations_of_levels_and_sections:
                unique_combinations_of_levels_and_sections[unique_key] = ts.level.name + (f"_{ts.section.name}" if ts.section else '')


        return list(unique_combinations_of_levels_and_sections.values())