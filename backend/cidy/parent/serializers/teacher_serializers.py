from rest_framework import serializers
from teacher.models import Level,Section
from teacher.serializers import SubjectSerializer


class SectionSerializer(serializers.ModelSerializer):
    subjects = serializers.SerializerMethodField(many=True)

    class Meta:
        model = Section
        fields = ['id', 'name', 'subjects']

    def get_subjects(self, section):
        subjects = section.subject_set.all()
        return SubjectSerializer(subjects, many=True).data

class TesLevelsSectionsSubjectsSerializer(serializers.ModelSerializer):
    sections = serializers.SerializerMethodField(many=True)

    class Meta:
        model = Level
        fields = ['id', 'name', 'sections']

    def get_sections(self, level):
        sections = level.section_set.all()
        return SectionSerializer(sections, many=True).data
