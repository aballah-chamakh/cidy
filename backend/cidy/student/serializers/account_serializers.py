from rest_framework import serializers
from teacher.serializers import LevelSerializer
from teacher.models import Level 
from ..models import Student


class LevelsAndSectionsSerializer(serializers.ModelSerializer):
    sections = serializers.SerializerMethodField()

    class Meta:
        model = Level
        fields = ['id', 'name', 'sections']



class StudentAccountInfoSerializer(serializers.ModelSerializer):
    """Serializer for retrieving student account information."""
    image = serializers.ImageField(source='image.url', read_only=True)
    email = serializers.EmailField(source='user.email', read_only=True)
    phone_number = serializers.CharField(source='user.phone_number', read_only=True)
    level = LevelSerializer()
    level_options = serializers.SerializerMethodField()
    
    class Meta:
        model = Student
        fields = ['image', 'fullname', 'email', 'phone_number', 'gender', 'level', 'section', 'level_options']

    def get_level_options(self, student):
        levels = Level.objects.all()
        return LevelSerializer(levels, many=True).data

class UpdateStudentAccountInfoSerializer(serializers.ModelSerializer):
    """ModelSerializer for updating student account information."""
    email = serializers.EmailField(source='user.email', required=True, write_only=True)
    phone_number = serializers.CharField(source='user.phone_number', min_length=8, max_length=8, required=True, write_only=True)
    current_password = serializers.CharField(write_only=True, required=True)

    class Meta:
        model = Student
        fields = ['image', 'fullname', 'email', 'phone_number', 'gender', 'level', 'section', 'current_password']

    def validate_current_password(self, value):
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError("Incorrect current password.")
        return value
    
    def validate(self,attrs):
        if self.instance : 
            level = attrs.get('level')
            section = attrs.get('section')
            if self.instance.level != level or self.instance.section != section:
                if self.instance.groupenrollment_set.all().exists() : 
                    raise serializers.ValidationError("YOU_CANNOT_CHANGE_LEVEL_OR_SECTION_WHILE_BEING_ENROLLED_IN_A_GROUP")
        return attrs

    def update(self, student, validated_data):
        validated_data.pop('current_password', None)
        email = validated_data.pop('email', None)
        phone_number = validated_data.pop('phone_number', None)
        user = student.user

        # Update user fields
        if email is not None:
            user.email = email
        if phone_number is not None:
            user.phone_number = phone_number
        user.save()

        return super().update(student, validated_data)


class ChangeStudentPasswordSerializer(serializers.ModelSerializer):
    """Serializer for changing student password."""
    current_password = serializers.CharField(write_only=True, required=True)
    new_password = serializers.CharField(write_only=True, min_length=8, required=True)

    class Meta:
        model = Student
        fields = ['current_password', 'new_password']


    def validate_current_password(self, value):
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError("Incorrect current password.")
        return value
    

    def update(self, student, validated_data):
        # only update the password
        new_password = validated_data.pop('new_password', None)
        user = student.user

        if new_password is not None:
            user.set_password(new_password)
        user.save()

        return student



"""
class IncompatibleGroupsSerializer(serializers.ModelSerializer):
    ""Serializer for incompatible groups.""
    subject_name = serializers.CharField(source='teacher_subject.subject.name', read_only=True)
    class Meta:
        model = Group
        fields = ['subject_name']

"""