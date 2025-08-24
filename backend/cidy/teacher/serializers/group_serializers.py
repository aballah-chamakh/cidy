from datetime import datetime, timedelta
from rest_framework import serializers
from django.db.models import Sum, Q
from ..models import Group, Enrollment, Finance
from student.models import Student
from common.serializers import LevelSerializer, SectionSerializer, SubjectSerializer
from django.core.paginator import Paginator


class GroupListSerializer(serializers.ModelSerializer):
    level = serializers.CharField(source='level.name', read_only=True)
    section = serializers.CharField(source='section.name', read_only=True)
    subject = serializers.CharField(source='subject.name', read_only=True)
    class Meta:
        model = Group
        fields = [
            'id', 'name', 'level', 'section', 
            'subject', 'total_paid', 'total_unpaid'
        ]

class GroupStudentListSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    image_url = serializers.ImageField(source='image.url')
    fullname = serializers.CharField()
    paid_amount = serializers.DecimalField(max_digits=10, decimal_places=2)
    unpaid_amount = serializers.DecimalField(max_digits=10, decimal_places=2)
    
    class Meta : 
        fields = ['id','image_url','fullname','paid_amount','unpaid_amount']

class GroupDetailsSerializer(serializers.ModelSerializer):
    level = LevelSerializer(read_only=True)
    section = SectionSerializer(read_only=True)
    subject = SubjectSerializer(read_only=True)
    students = serializers.SerializerMethodField()
    class Meta:
        model = Group
        fields = [
            'id', 'name', 'level', 'section', 'subject', 
            'week_day', 'start_time_range', 'end_time_range',
            'total_paid', 'total_unpaid','students'
        ]

    def get_students(self, group_obj):
        request = self.context['request']
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
                    paid=Sum('enrollment__finance__paid_amount', filter=Q(enrollment__group=group_obj))
                ).order_by('-paid')
            elif sort_by == 'paid_amount_asc':
                students = students.annotate(
                    paid=Sum('enrollment__finance__paid_amount', filter=Q(enrollment__group=group_obj))
                ).order_by('paid')
            elif sort_by == 'unpaid_amount_desc':
                students = students.annotate(
                    unpaid=Sum('enrollment__finance__unpaid_amount', filter=Q(enrollment__group=group_obj))
                ).order_by('-unpaid')
            elif sort_by == 'unpaid_amount_asc':
                students = students.annotate(
                    unpaid=Sum('enrollment__finance__unpaid_amount', filter=Q(enrollment__group=group_obj))
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
    class Meta:
        model = Group
        fields = [
            'name', 'level', 'section', 'subject', 
            'week_day', 'start_time_range', 'end_time_range'
        ]

    def validate(self, data):
        
        # Check for schedule conflicts
        # for the edit and create case bring the name and the teacher from the request 
        name = data.get('name')
        teacher = self.context['request'].user.teacher
        # for the edit case bring the level, section and subject from the instance
        if self.instance:
            level = self.instance.level
            section = self.instance.section
            subject = self.instance.subject
        # for the create case bring the level, section and subject from the request data
        else : 
            level = data.get('level')
            section = data.get('section')
            subject = data.get('subject')

        # Check for duplicate group name
        duplicate_query = Group.objects.filter(
            teacher=teacher,
            name=name,
            level=level,
            subject=subject
        )
        
        if section:
            duplicate_query = duplicate_query.filter(section=section)
        else:
            duplicate_query = duplicate_query.filter(section__isnull=True)
        
        if duplicate_query.exists():
            raise serializers.ValidationError("ALREADY_EXISTING_GROUP_NAME_DETECTED")
        
        # check for schdule conflict 
        week_day = data.get('week_day')
        start_time_range = data.get('start_time_range')
        end_time_range = data.get('end_time_range')
        
        conflicting_groups = Group.objects.filter(
            teacher=teacher,
            week_day=week_day
        ).filter(
            (Q(start_time_range__lte=start_time_range) & Q(end_time_range__gte=start_time_range)) |
            (Q(start_time_range__lte=end_time_range) & Q(end_time_range__gte=end_time_range)) |
            (Q(start_time_range__gte=start_time_range) & Q(end_time_range__lte=end_time_range))
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
            validate_data['temporary_start_time_range'] = validate_data['start_time_range'] 
            validate_data['temporary_end_time_range'] = validate_data['end_time_range']
            # Set the clear_temporary_schedule_at to the end of the current week
            today = datetime.now()
            end_of_week = today + timedelta(days=(6 - today.weekday()))
            end_of_week = datetime(end_of_week.year, end_of_week.month, end_of_week.day, 23, 59, 59)
            validate_data['clear_temporary_schedule_at'] = end_of_week
        elif schedule_change_type == 'permanent':
            validate_data['temporary_week_day'] = None 
            validate_data['temporary_start_time_range'] = None
            validate_data['temporary_end_time_range'] = None
            validate_data['clear_temporary_schedule_at'] = None 

        super().update(instance,validate_data)

    def create(self,validated_data):
        validated_data['teacher'] = self.context['request'].user.teacher
        super().create(validated_data)


class GroupCreateStudentSerializer(serializers.ModelSerializer):
    
    class Meta : 
        model = Student
        fields = ['id', 'image', 'fullname','phone_number','gender','level','section']