from rest_framework import serializers
from ..models import Level, Subject, TeacherSubject
from student.models import Student

class LevelSerializer(serializers.ModelSerializer):
    class Meta:
        model = Level
        fields = ['id', 'name']

class SubjectSerializer(serializers.ModelSerializer):
    class Meta:
        model = Subject
        fields = ['id', 'name']

class TeacherSubjectSerializer(serializers.ModelSerializer):
    level = serializers.CharField(write_only=True)
    section = serializers.CharField(write_only=True, allow_blank=True)
    subject = serializers.CharField(write_only=True)

    class Meta:
        model = TeacherSubject
        fields = ['id', 'level','section', 'subject', 'price_per_class']

    def create(self, validated_data):
        level = Level.objects.get(name=validated_data.pop('level'), section=validated_data.pop('section') )
        subject = Subject.objects.get(name=validated_data.pop('subject'))
        teacher = self.context['request'].user.teacher
        validated_data['level'] = level
        validated_data['subject'] = subject
        validated_data['teacher'] = teacher

        return super().create(validated_data)


class EditTeacherSubjectPriceSerializer(serializers.ModelSerializer):
    class Meta:
        model = TeacherSubject
        fields = ['price_per_class']

class TeacherLevelsSectionsSubjectsHierarchySerializer:

    def __init__(self, teacher_subjects_qs, with_prices=False):
        levels = {}

        for ts in teacher_subjects_qs:
            level_name = ts.level.name
            section_name = ts.level.section

            level_entry = levels.setdefault(level_name, {})

            if section_name:
                sections = level_entry.setdefault('sections', {})
                section_entry = sections.setdefault(section_name, {})
                subjects_list = section_entry.setdefault('subjects', [])
            else:
                subjects_list = level_entry.setdefault('subjects', [])

            if with_prices:
                subject_payload = {
                    'id': ts.id,
                    'name': ts.subject.name,
                    'price_per_class': ts.price_per_class,
                }
            else:
                subject_payload = ts.subject.name

            subjects_list.append(subject_payload)

        self.data = levels

class TesLevelsSectionsSubjectsHierarchySerializer:

    def __init__(self, levels_qs):
        levels = {}

        for level in levels_qs:

            level_data = levels.setdefault(level.name, {})

            if level.section :
                sections_data = level_data.setdefault('sections', {})
                sections_data[level.section] = [subject.name for subject in level.subjects.all()]
            else:
                level_data['subjects'] = [subject.name for subject in level.subjects.all()]

        self.data = levels

"""
            level_id = ts.level.id
            section_id = ts.section.id if ts.section else None
            subject_id = ts.subject.id

            # --- Ensure level exists ---
            if level_id not in levels:
                levels[level_id] = {
                    "name": ts.level.name,
                }

            # --- Ensure section exists ---
            if section_id:
                levels[level_id]['sections'] = levels[level_id].get("sections", {})  
                if section_id not in levels[level_id]["sections"]:
                    levels[level_id]["sections"][section_id] = {
                        "name": ts.section.name,
                        "subjects": []
                    }

                # Add subject
                levels[level_id]["sections"][section_id]["subjects"].append({
                    "id": subject_id,
                    "name": ts.subject.name
                })
            else : 
                levels[level_id]['subjects'] = levels[level_id].get("subjects", [])  
                levels[level_id]['subjects'].append({
                    "id": subject_id,
                    "name": ts.subject.name,
                    "price": ts.price_per_class
                })
"""
        

class StudentListToReplaceBySerializer(serializers.ModelSerializer):
    
    groups = serializers.SerializerMethodField()

    class Meta:
        model = Student
        fields = ['id', 'fullname', 'groups']

    def get_groups(self, student_obj):
        request = self.context['request']
        teacher_obj = request.user.teacher
        groups = student_obj.groups.all(teacher=teacher_obj)
        json_groups = []

        for group in groups:
            json_group = {
                'id': group.id,
                'name': group.name,
            }
            json_groups.append(json_group)
        
        return json_groups
