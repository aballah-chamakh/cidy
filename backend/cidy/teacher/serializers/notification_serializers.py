from rest_framework import serializers
from ..models import TeacherNotification

class TeacherNotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = TeacherNotification
        fields = ['id', 'teacher', 'image', 'message', 'meta_data', 'type', 'is_read', 'created_at']
        read_only_fields = ['created_at']