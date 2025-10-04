from datetime import datetime, timedelta
from rest_framework import serializers
from django.db.models import Sum, Q
from ..models import Group
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

class GroupDetailsSerializer(serializers.ModelSerializer):
    level = LevelSerializer(source='teacher_subject.level', read_only=True)
    subject = SubjectSerializer(source='teacher_subject.subject', read_only=True)    
    start_time = serializers.TimeField(
        format="%H:%M", 
        input_formats=["%H:%M", "%H:%M:%S"]
    )
    end_time = serializers.TimeField(
        format="%H:%M", 
        input_formats=["%H:%M", "%H:%M:%S"]
    )
    students = serializers.SerializerMethodField()

    class Meta:
        model = Group
        fields = [
            'id', 'name', 'level', 'section', 'subject', 
            'week_day', 'start_time', 'end_time',
            'total_paid', 'total_unpaid','students'
        ]

    def get_students(self, group_obj):
        request = self.context['request']
        teacher = request.user.teacher
        search_term = request.GET.get('search', '')
        sort_by = request.GET.get('sort_by', '')

        students = group_obj.students.all()

        # Apply search filter
        if search_term:
            students = students.filter(fullname__icontains=search_term)
        
        # Apply sorting
        if sort_by:
            if sort_by == 'paid_amount_desc':
                students = students.annotate(
                    paid=Sum('teacherenrollment_set__paid_amount', filter=Q(teacherenrollment_set__teacher=teacher))
                ).order_by('-paid')
            elif sort_by == 'paid_amount_asc':
                students = students.annotate(
                    paid=Sum('teacherenrollment_set__paid_amount', filter=Q(teacherenrollment_set__teacher=teacher))
                ).order_by('paid')
            elif sort_by == 'unpaid_amount_desc':
                students = students.annotate(
                    unpaid=Sum('teacherenrollment_set__unpaid_amount', filter=Q(teacherenrollment_set__teacher=teacher))
                ).order_by('-unpaid')
            elif sort_by == 'unpaid_amount_asc':
                students = students.annotate(
                    unpaid=Sum('teacherenrollment_set__unpaid_amount', filter=Q(teacherenrollment_set__teacher=teacher))
                ).order_by('unpaid')

        page = request.GET.get('page', 1)
        page_size = request.GET.get('page_size', 30)
        paginator = Paginator(students, page_size)
        try:
            paginated_students = paginator.page(page)
        except Exception:
            # If page is out of range, deliver last page
            paginated_students = paginator.page(paginator.num_pages)
        total_students = paginator.count
        serializer = GroupStudentListSerializer(paginated_students, many=True)

        return {
            'students': serializer.data,
            'total_students': total_students,
        }
    
class GroupCreateUpdateSerializer(serializers.ModelSerializer):
    schedule_change_type = serializers.ChoiceField(choices=['permanent', 'temporary'], write_only=True, required=False)
    start_time = serializers.TimeField(
        format="%H:%M", 
        input_formats=["%H:%M", "%H:%M:%S"]
    )
    end_time = serializers.TimeField(
        format="%H:%M", 
        input_formats=["%H:%M", "%H:%M:%S"]
    )
    class Meta:
        model = Group
        fields = [
            'name', 'teacher_subject', 
            'week_day', 'start_time', 'end_time'
        ]

    def validate(self, data):
        
        # Check for schedule conflicts
        # for the edit and create case bring the name and the teacher from the request 
        name = data.get('name')
        teacher = self.context['request'].user.teacher
        # for the edit case bring the teacher_subject from the instance
        if self.instance:
            teacher_subject = self.instance.teacher_subject
        # for the create case bring the teacher_subject from the request data
        else : 
            teacher_subject = data.get('teacher_subject')

        # Check for duplicate group name
        duplicate_query = Group.objects.filter(
            teacher=teacher,
            name=name,
            teacher_subject=teacher_subject
        )
        
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
            (Q(start_time__lte=start_time) & Q(end_time__gte=start_time)) |
            (Q(start_time__lte=end_time) & Q(end_time__gte=end_time)) |
            (Q(start_time__gte=start_time) & Q(end_time__lte=end_time))
        )
        # in the case of the edit, exclude the group 
        if self.instance : 
            conflicting_groups = conflicting_groups.exclude(id=self.instance.id)
        
        if conflicting_groups.exists():
            raise serializers.ValidationError("SCHEDULE_CONFLICT_DETECTED")
        
        return data
    
    def update(self,instance,**validate_data):
        schedule_change_type = validate_data.get('schedule_change_type')
        if schedule_change_type == 'temporary':
            validate_data['temporary_week_day'] = validate_data['week_day']
            validate_data['temporary_start_time'] = validate_data['start_time'] 
            validate_data['temporary_end_time'] = validate_data['end_time']
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

        super().update(instance,validate_data)

    def create(self,validated_data):
        validated_data['teacher'] = self.context['request'].user.teacher
        super().create(validated_data)


class GroupCreateStudentSerializer(serializers.ModelSerializer):
    image = serializers.CharField(source='image.url', read_only=True)
    class Meta : 
        model = Student
        fields = ['id', 'image', 'fullname','phone_number','gender','level','section']