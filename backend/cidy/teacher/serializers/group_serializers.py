from datetime import datetime, timedelta
from rest_framework import serializers
from django.db.models import Sum, Q,Value,DecimalField
from django.db.models.functions import Coalesce

from ..models import Group, TeacherSubject
from student.models import Student
from .price_serializers import LevelSerializer, SubjectSerializer
from django.core.paginator import Paginator


class GroupListSerializer(serializers.ModelSerializer):
    level = serializers.CharField(source='teacher_subject.level.name', read_only=True)
    section = serializers.CharField(source='teacher_subject.level.section', read_only=True)
    subject = serializers.CharField(source='teacher_subject.subject.name', read_only=True)
    class Meta:
        model = Group
        fields = [
            'id', 'name', 'level', 'section', 
            'subject','week_day', 'start_time', 'end_time','total_paid', 'total_unpaid'
        ]

class GroupStudentListSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    image = serializers.CharField(source='image.url')
    fullname = serializers.CharField()
    paid_amount = serializers.DecimalField(max_digits=10, decimal_places=2)
    unpaid_amount = serializers.DecimalField(max_digits=10, decimal_places=2)
    
    class Meta : 
        fields = ['id','image','fullname','paid_amount','unpaid_amount']

class GroupPossibleStudentListSerializer(serializers.ModelSerializer):
    image = serializers.CharField(source='image.url',read_only=True)
    class Meta : 
        model = Student 
        fields = ['id','image','fullname']

class GroupDetailsSerializer(serializers.ModelSerializer):
    level = serializers.CharField(source='teacher_subject.level.name', read_only=True)
    section = serializers.CharField(source='teacher_subject.level.section', read_only=True)
    subject = serializers.CharField(source='teacher_subject.subject.name', read_only=True)    
    week_day = serializers.SerializerMethodField()
    start_time = serializers.SerializerMethodField()
    end_time = serializers.SerializerMethodField()
    is_temporary_schedule = serializers.SerializerMethodField()
    students = serializers.SerializerMethodField()
    

    class Meta:
        model = Group
        fields = [
            'id', 'name', 'level', 'section', 'subject', 
            'week_day', 'start_time', 'end_time','is_temporary_schedule',
            'total_paid', 'total_unpaid','students'
        ]

    def get_start_time(self, group):
        today = datetime.now().date()
        if group.clear_temporary_schedule_at and group.clear_temporary_schedule_at >= today:
            return group.temporary_start_time.strftime("%H:%M")
        else : 
            return group.start_time.strftime("%H:%M")
    

    def get_end_time(self, group):
        today = datetime.now().date()
        if group.clear_temporary_schedule_at and group.clear_temporary_schedule_at >= today:
            return group.temporary_end_time.strftime("%H:%M")
        else : 
            return group.end_time.strftime("%H:%M")
        
    def get_week_day(self, group):
        today = datetime.now().date()
        if group.clear_temporary_schedule_at and group.clear_temporary_schedule_at >= today:
            return group.temporary_week_day
        else : 
            return group.week_day

    def get_is_temporary_schedule(self, group):
        today = datetime.now().date()
        return bool(group.clear_temporary_schedule_at and group.clear_temporary_schedule_at >= today)

    
    def get_students(self, group_obj):
        request = self.context['request']
        teacher = request.user.teacher
        search_term = request.GET.get('search', '')
        sort_by = request.GET.get('sort_by', '')

        students = group_obj.students.all()

        if not students.exists():
            return {
                'students': [],
                'total_students': 0,
            }
        # Apply search filter
        if search_term:
            students = students.filter(fullname__icontains=search_term)
        
        students = students.annotate(
            paid_amount=Coalesce(
                Sum('groupenrollment__paid_amount', filter=Q(groupenrollment__group=group_obj)),
                Value(0),
                output_field=DecimalField()
            ),
            unpaid_amount=Coalesce(
                Sum('groupenrollment__unpaid_amount', filter=Q(groupenrollment__group=group_obj)),
                Value(0),
                output_field=DecimalField()
            )
        )

        # Apply sorting
        if sort_by:
            if sort_by == 'paid_amount_desc':
                students = students.order_by('-paid_amount')
            elif sort_by == 'paid_amount_asc':
                students = students.order_by('paid_amount')
            elif sort_by == 'unpaid_amount_desc':
                students = students.order_by('-unpaid_amount')
            elif sort_by == 'unpaid_amount_asc':
                students = students.order_by('unpaid_amount')
        else : 
            students = students.order_by('-id')  # Default sorting by newest
        
        page = request.GET.get('page', 1)
        page_size = request.GET.get('page_size', 30)
        paginator = Paginator(students, page_size)
        try:
            paginated_students = paginator.page(page)
        except Exception:
            # If page is out of range, deliver last page
            paginated_students = paginator.page(1)
            page = 1 
        total_students = paginator.count
        serializer = GroupStudentListSerializer(paginated_students, many=True)

        return {
            'students': serializer.data,
            'total_students': total_students,
            'page': page,
        }
    
class GroupCreateUpdateSerializer(serializers.ModelSerializer):
    schedule_change_type = serializers.ChoiceField(choices=['permanent', 'temporary'], write_only=True, required=False)
    start_time = serializers.TimeField(
        format="%H:%M", 
        input_formats=["%H:%M", "%H:%M"]
    )
    end_time = serializers.TimeField(
        format="%H:%M", 
        input_formats=["%H:%M", "%H:%M"]
    )
    level = serializers.CharField(write_only=True, required=True)
    section = serializers.CharField(write_only=True, required=False, allow_null=True, allow_blank=True)
    subject = serializers.CharField(write_only=True, required=True)

    class Meta:
        model = Group
        fields = [
            'name', 
            'level', 
            'section', 
            'subject',
            'week_day',
            'start_time',
            'end_time',
            'schedule_change_type'
        ]

    def validate(self, data):
        print("Validating data:", data)
        # Check for schedule conflicts
        # for the edit and create case bring the name and the teacher from the request 
        name = data.get('name')
        teacher = self.context['request'].user.teacher
        # in the case of the create, get the teacher_subject from the level, section and subject
        # specified in the request
        if not self.instance : 
            level = data.pop('level')
            section = data.pop('section')
            subject = data.pop('subject')
            if section : 
                teacher_subject = TeacherSubject.objects.filter(teacher=teacher,level__name=level,level__section=section, subject__name=subject).first()
            else :
                teacher_subject = TeacherSubject.objects.filter(teacher=teacher,level__name=level,level__section__isnull=True, subject__name=subject).first()
        else : 
            # in the case of the edit, get the teacher_subject from the instance
            teacher_subject = self.instance.teacher_subject

        # Check for duplicate group name
        duplicate_query = Group.objects.filter(
            teacher=teacher,
            name=name,
            teacher_subject=teacher_subject
        )

        # exclude the current instance in case of update
        if self.instance:
            duplicate_query = duplicate_query.exclude(id=self.instance.id)
        
        if duplicate_query.exists():
            raise serializers.ValidationError("ALREADY_EXISTING_GROUP_NAME_DETECTED")
        
        # check for schdule conflict 
        week_day = data.get('week_day')
        start_time = data.get('start_time')
        end_time = data.get('end_time')
        
        conflicting_groups = Group.objects.filter(
            teacher=teacher,
            week_day=week_day
        ).filter(
           Q(start_time__lt=end_time) & Q(end_time__gt=start_time)
        )
        # in the case of the edit, exclude the group 
        if self.instance : 
            conflicting_groups = conflicting_groups.exclude(id=self.instance.id)
        
        if conflicting_groups.exists():
            print("Conflict detected with groups:")
            for group in conflicting_groups:
                print(f"- {group.name} {group.teacher_subject.level} {group.teacher_subject.level.section} ({group.start_time} - {group.end_time})")
            raise serializers.ValidationError("SCHEDULE_CONFLICT_DETECTED")
        
        data['teacher_subject'] = teacher_subject
        return data
    
    def update(self,instance,validate_data):
        schedule_change_type = validate_data.get('schedule_change_type')
        if schedule_change_type == 'temporary':
            validate_data['temporary_week_day'] = validate_data.pop('week_day')
            validate_data['temporary_start_time'] = validate_data.pop('start_time')
            validate_data['temporary_end_time'] = validate_data.pop('end_time')
            # Set the clear_temporary_schedule_at to the end of the current week
            today = datetime.now()
            end_of_week = today + timedelta(days=(6 - today.weekday()))
            end_of_week = datetime(end_of_week.year, end_of_week.month, end_of_week.day, 23, 59, 59)
            validate_data['clear_temporary_schedule_at'] = end_of_week
        elif schedule_change_type == 'permanent':
            validate_data['temporary_week_day'] = None 
            validate_data['temporary_start_time'] = None
            validate_data['temporary_end_time'] = None
            validate_data['clear_temporary_schedule_at'] = None 

        return super().update(instance,validate_data)

    def create(self,validated_data):
        validated_data['teacher'] = self.context['request'].user.teacher
        return super().create(validated_data)


class GroupCreateStudentSerializer(serializers.ModelSerializer):
    class Meta : 
        model = Student
        fields = ['id', 'image', 'fullname','phone_number','gender']