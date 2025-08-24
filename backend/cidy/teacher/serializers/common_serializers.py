from rest_framework import serializers

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
                levels[level_id]["sections"][section_id]["subjects"][subject_id].append({
                    "name": ts.subject.name
                })
            else : 
                levels[level_id]['subjects'] = levels[level_id].get("subjects", {})  
                levels[level_id]['subjects'][subject_id].append({
                    "name": ts.subject.name
                })

        return levels