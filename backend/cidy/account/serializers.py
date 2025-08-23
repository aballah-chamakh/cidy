from rest_framework import serializers
from .models import User
from student.models import Student
from teacher.models import Teacher
from parent.models import Parent 


class RegisterSerializer(serializers.Serializer):
    """
    Serializer for user registration that matches the register screen requirements.
    """
    PROFILE_TYPE_CHOICES = [
        ('teacher', 'Teacher'),
        ('student', 'Student'),
        ('parent', 'Parent'),
    ]
    
    GENDER_CHOICES = [
        ('M', 'Male'),
        ('F', 'Female'),
    ]
    
    profile_type = serializers.ChoiceField(
        choices=PROFILE_TYPE_CHOICES,
        required=True,
        error_messages={
            'required': 'Profile type is required.',
            'invalid_choice': 'Please select a valid profile type (Teacher, Student, or Parent).'
        }
    )
    
    fullname = serializers.CharField(
        max_length=255,
        required=True,
        allow_blank=False,
        error_messages = {
            'required': 'Full name is required.',
            'blank': 'Full name cannot be empty.',
            'max_length': 'Full name cannot exceed 255 characters.'
        }
    )
    
    email = serializers.EmailField(
        required=True,
        error_messages={
            'required': 'Email is required.',
            'invalid': 'Please enter a valid email address.'
        }
    )
    
    phone_number = serializers.CharField(
        min_length=8,
        max_length=8,
        required=True,
        error_messages={
            'required': 'Phone number is required.',
            'min_length': 'Phone number must be exactly 8 digits.',
            'max_length': 'Phone number must be exactly 8 digits.'
        }
    )
    
    gender = serializers.ChoiceField(
        choices=GENDER_CHOICES,
        required=True,
        error_messages={
            'required': 'Gender is required.',
            'invalid_choice': 'Please select either Male or Female.'
        }
    )
    
    password = serializers.CharField(
        min_length=8,
        write_only=True,
        style={'input_type': 'password'},
        error_messages={
            'required': 'Password is required.',
            'min_length': 'Password must be at least 8 characters long.'
        }
    )
    
    confirm_password = serializers.CharField(
        min_length=8,
        write_only=True,
        style={'input_type': 'password'},
        error_messages={
            'required': 'Password confirmation is required.',
            'min_length': 'Password confirmation must be at least 8 characters long.'
        }
    )
    
    def validate_email(self, value):
        """
        Check that the email is unique.
        """
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("A user with this email already exists.")
        return value
    
    def validate_phone_number(self, value):
        """
        Validate phone number format and uniqueness.
        """
        # Check if phone number contains only digits
        if not value.isdigit():
            raise serializers.ValidationError("Phone number must contain only digits.")
        
        # Check uniqueness
        if User.objects.filter(phone_number=value).exists():
            raise serializers.ValidationError("A user with this phone number already exists.")
        
        return value
    
    
    def validate(self, attrs):
        """
        Check that password and confirm_password match.
        """
        password = attrs.get('password')
        confirm_password = attrs.get('confirm_password')
        
        if password and confirm_password and password != confirm_password:
            raise serializers.ValidationError("Password and confirm password do not match.")
        
        return attrs
    
    def create(self, validated_data):

        # Create the user
        user = User.objects.create_user(
            email=validated_data['email'],
            phone_number=validated_data['phone_number'],
            password=validated_data['password']
        )

        profile_type = validated_data.pop('profile_type')
        fullname = validated_data.pop('fullname')
        gender = validated_data.pop('gender')
        if profile_type == 'student':
            Student.objects.create(
                user=user,
                fullname=fullname,
                gender=gender
            )
        elif profile_type == 'teacher':
            Teacher.objects.create(
                user=user,
                fullname=fullname,
                gender=gender
            )
        else :
            Parent.objects.create(
                user=user,
                fullname=fullname,
                gender=gender
            )

        return user





