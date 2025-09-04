from rest_framework import serializers
from parent.models import Parent


class ParentListSerializer(serializers.ModelSerializer):
    # name of the subject
    name = serializers.CharField(source='subject.name', read_only=True)
    class Meta:
        model = Parent
        fields = ['image', 'fullname']