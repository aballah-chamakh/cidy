from rest_framework import serializers
from account.models import User
from teacher.models import Teacher

class TeacherAccountInfoSerializer(serializers.ModelSerializer):
    """Serializer for retrieving teacher account information."""
    image = serializers.ImageField(source='image.url', read_only=True)
    email = serializers.EmailField(source='user.email', read_only=True)
    phone_number = serializers.CharField(source='user.phone_number', read_only=True)

    class Meta:
        model = Teacher
        fields = ['image', 'fullname', 'email', 'phone_number', 'gender']


class UpdateTeacherAccountInfoSerializer(serializers.ModelSerializer):
    """ModelSerializer for updating teacher account information."""
    email = serializers.EmailField( required=True, write_only=True)
    phone_number = serializers.CharField(min_length=8, max_length=8, required=True, write_only=True)
    current_password = serializers.CharField(write_only=True, required=True)

    class Meta:
        model = Teacher
        fields = ['image', 'fullname', 'email', 'phone_number', 'gender', 'current_password']

    def validate_current_password(self, value):
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError("Incorrect current password.")
        return value

    def update(self, teacher, validated_data):
        validated_data.pop('current_password', None)
        email = validated_data.pop('email', None)
        phone_number = validated_data.pop('phone_number', None)
        user = teacher.user

        # Update user fields
        if email is not None:
            user.email = email
        if phone_number is not None:
            user.phone_number = phone_number
        user.save()

        return super().update(teacher, validated_data)


class ChangeTeacherPasswordSerializer(serializers.ModelSerializer):
    """Serializer for changing teacher password."""
    current_password = serializers.CharField(write_only=True, required=True)
    new_password = serializers.CharField(write_only=True, min_length=8, required=True)

    class Meta:
        model = Teacher
        fields = ['current_password', 'new_password']


    def validate_current_password(self, value):
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError("Incorrect current password.")
        return value
    

    def update(self, teacher, validated_data):
        # only update the password
        new_password = validated_data.pop('new_password', None)
        user = teacher.user

        if new_password is not None:
            user.set_password(new_password)
        user.save()

        return teacher

