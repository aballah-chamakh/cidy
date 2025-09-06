from rest_framework import serializers
from ..models import ParentNotification

class ParentNotificationSerializer(serializers.ModelSerializer):
    image = serializers.CharField(source="image.url")
    class Meta : 
        model = ParentNotification
        fields = ['id', 'image', 'message', 'meta_data', 'is_read', 'created_at']
