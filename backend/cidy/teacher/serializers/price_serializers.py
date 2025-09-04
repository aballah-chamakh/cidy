from rest_framework import serializers
from ..models import Level, Section, Subject, TeacherSubject
from student.models import Student

class LevelSerializer(serializers.ModelSerializer):
    class Meta:
        model = Level
        fields = ['id', 'name']

class SectionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Section
        fields = ['id', 'name']

class SubjectSerializer(serializers.ModelSerializer):
    class Meta:
        model = Subject
        fields = ['id', 'name']

class TeacherSubjectSerializer(serializers.ModelSerializer):
    class Meta:
        model = TeacherSubject
        fields = ['id', 'level', 'section', 'subject', 'price_per_class']

    def validate(self, attrs):

        # validate the level,section and subject fields only for creation
        if not self.instance : 
            level = attrs.get('level')
            section = attrs.get('section')
            subject = attrs.get('subject')

            # in the case of the section not None 
            if subject.section is not None :
                # check if the section belong to the level 
                if section.level != level:
                    raise serializers.ValidationError("Section does not belong to the selected Level.")
                # check if the subject belongs to the section
                if subject.section != section:
                    raise serializers.ValidationError("Subject does not belong to the selected Section.")
            else : # in the case of the section is None 
                # check if the subject belongs to the level
                if subject.level != level:
                    raise serializers.ValidationError("Subject does not belong to the selected Level.")

            request = self.context.get("request")
            teacher = request.user.teacher
            if TeacherSubject.objects.filter(teacher=teacher, level=level, section=section, subject=subject).exists() :
                raise serializers.ValidationError("This subject already exists for the selected level and section.")

        return attrs


class TeacherLevelsSectionsSubjectsHierarchySerializer(serializers.Serializer):


    def to_representation(self, queryset):
        levels = {}

        for ts in queryset:
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

        return levels

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
