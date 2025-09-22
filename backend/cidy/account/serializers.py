from rest_framework import serializers
from .models import User
from student.models import Student
from teacher.models import Teacher
from parent.models import Parent 
from teacher.serializers import SectionSerializer
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from teacher.models import Level,Section 



class UserRegistrationSerializer(serializers.Serializer):
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

    level = serializers.CharField(required=False)
    section = serializers.CharField(required=False, allow_blank=True)
    
    password = serializers.CharField(
        min_length=8,
        write_only=True,
        style={'input_type': 'password'},
        error_messages={
            'required': 'Password is required.',
            'min_length': 'Password must be at least 8 characters long.'
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
    
    
    
    def create(self, validated_data):

        # Create the user
        user = User.objects.create_user(
            email=validated_data['email'],
            phone_number=validated_data['phone_number'],
            password=validated_data['password']
        )

        profile_type = validated_data.get('profile_type')
        fullname = validated_data.get('fullname')
        gender = validated_data.get('gender')
        if profile_type == 'student':
            print("create a student")
            level = validated_data.get('level')
            section = validated_data.get('section')
            if level : 
                level = Level.objects.get(name=level)
                if section : 
                    section = Section.objects.get(name=section,level = level)
            Student.objects.create(
                user=user,
                fullname=fullname,
                gender=gender,
                phone_number=user.phone_number,
                level = level,
                section = section if isinstance(section,Section) else None
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




class LevelsAndSectionsSerializer(serializers.ModelSerializer):

    sections = serializers.SerializerMethodField()
    
    class Meta:
        model = Level
        fields = ['id', 'name', 'sections']

    def get_sections(self, level):
        sections = level.section_set.all()
        return SectionSerializer(sections, many=True).data



class MyAccessTokenSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)

        # 🔑 Add your extra claim(s)
        # assuming your User model has a field or property called profile_type
        if hasattr(user, 'student'):
            token['profile_type'] = 'student'
        elif hasattr(user, 'teacher'):
            token['profile_type'] = 'teacher'
        elif hasattr(user, 'parent'):
            token['profile_type'] = 'parent'

        return token
    
    def validate(self, attrs):
        data = super().validate(attrs)
        # Only return access token
        data['user'] = {
            'id': self.user.id,
            'email': self.user.email,
            'profile_type': data.get('profile_type')
        }
        return {'access': data['access']}