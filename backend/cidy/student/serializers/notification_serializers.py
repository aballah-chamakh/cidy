from rest_framework import serializers
from ..models import StudentNotification

class StudentNotificationSerializer(serializers.ModelSerializer):
    image = serializers.CharField(source="image.url")
    class Meta : 
        model = StudentNotification
        fields = ['id', 'image', 'message', 'meta_data', 'is_read', 'created_at']
