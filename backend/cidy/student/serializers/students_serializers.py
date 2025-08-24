from rest_framework import serializers
from ..models import Student, StudentNotification


class StudentListSerializer(serializers.ModelSerializer):
    class Meta : 
        model = Student 
        fields = ['id','image','fullname','paid_amount','unpaid_amount']
