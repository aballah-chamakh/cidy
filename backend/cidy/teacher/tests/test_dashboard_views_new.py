from django.test import TestCase
from rest_framework.test import APITestCase
from rest_framework import status
from django.urls import reverse
from django.contrib.auth import get_user_model
from datetime import datetime, timedelta, date
from decimal import Decimal
from teacher.models import Level, Section, Subject, Teacher, TeacherSubject, Group, GroupEnrollment, Class
from student.models import Student
import json

User = get_user_model()

class DashboardViewTestCaseNew(APITestCase):
    def setUp(self):
        """Set up test data for dashboard tests"""
        # Create users
        self.teacher_user = User.objects.create_user(
            email='teacher@test.com',
            password='testpass123',
            user_type='teacher'
        )
        
        self.student_user1 = User.objects.create_user(
            email='student1@test.com',
            password='testpass123',
            user_type='student'
        )
        
        self.student_user2 = User.objects.create_user(
            email='student2@test.com',
            password='testpass123',
            user_type='student'
        )
        
        # Create levels, sections, and subjects
        self.level1 = Level.objects.create(name='Level 1')
        self.level2 = Level.objects.create(name='Level 2')
        
        self.section1 = Section.objects.create(name='Section A', level=self.level1)
        self.section2 = Section.objects.create(name='Section B', level=self.level2)
        
        self.subject1 = Subject.objects.create(name='Math')
        self.subject2 = Subject.objects.create(name='Physics')
        
        # Create teacher
        self.teacher = Teacher.objects.create(
            user=self.teacher_user,
            fullname='Test Teacher',
            gender='M'
        )
        
        # Create students
        self.student1 = Student.objects.create(
            user=self.student_user1,
            fullname='Student One',
            level=self.level1,
            section=self.section1,
            gender='M',
            phone_number='12345678'
        )
        
        self.student2 = Student.objects.create(
            user=self.student_user2,
            fullname='Student Two',
            level=self.level2,
            section=self.section2,
            gender='F',
            phone_number='87654321'
        )
        
        # Create teacher subjects
        self.teacher_subject1 = TeacherSubject.objects.create(
            teacher=self.teacher,
            level=self.level1,
            section=self.section1,
            subject=self.subject1,
            price_per_class=Decimal('50.00')
        )
        
        self.teacher_subject2 = TeacherSubject.objects.create(
            teacher=self.teacher,
            level=self.level2,
            section=self.section2,
            subject=self.subject2,
            price_per_class=Decimal('75.00')
        )
        
        # Create groups
        self.group1 = Group.objects.create(
            teacher=self.teacher,
            name='Group 1',
            teacher_subject=self.teacher_subject1,
            week_day='Monday',
            start_time='10:00',
            end_time='11:00'
        )
        
        self.group2 = Group.objects.create(
            teacher=self.teacher,
            name='Group 2',
            teacher_subject=self.teacher_subject2,
            week_day='Wednesday',
            start_time='14:00',
            end_time='15:00'
        )
        
        # Create enrollments
        self.enrollment1 = GroupEnrollment.objects.create(
            student=self.student1,
            group=self.group1,
            date=date(2023, 1, 15),
            paid_amount=Decimal('100.00'),
            unpaid_amount=Decimal('50.00')
        )
        
        self.enrollment2 = GroupEnrollment.objects.create(
            student=self.student2,
            group=self.group2,
            date=date(2023, 2, 10),
            paid_amount=Decimal('150.00'),
            unpaid_amount=Decimal('75.00')
        )
        
        # Create classes
        # For enrollment1 (student1, group1)
        self.class1 = Class.objects.create(
            group_enrollment=self.enrollment1,
            status='attended_and_paid',
            attendance_date=date(2023, 1, 20)
        )
        
        self.class2 = Class.objects.create(
            group_enrollment=self.enrollment1,
            status='attended_and_paid',
            attendance_date=date(2023, 2, 5)
        )
        
        self.class3 = Class.objects.create(
            group_enrollment=self.enrollment1,
            status='attended_and_the_payment_due',
            attendance_date=date(2023, 3, 15)
        )
        
        # For enrollment2 (student2, group2)
        self.class4 = Class.objects.create(
            group_enrollment=self.enrollment2,
            status='attended_and_paid',
            attendance_date=date(2023, 2, 25)
        )
        
        self.class5 = Class.objects.create(
            group_enrollment=self.enrollment2,
            status='attended_and_the_payment_due',
            attendance_date=date(2023, 3, 10)
        )
        
        # Authenticate the teacher user
        self.client.force_authenticate(user=self.teacher_user)

    def test_unauthenticated_access(self):
        """Test that unauthenticated users cannot access the endpoint"""
        self.client.force_authenticate(user=None)
        response = self.client.get(reverse('teacher_get_dashboard_data'))
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_no_teacher_subjects(self):
        """Test response when teacher has no TeacherSubject records"""
        # Create new teacher with no subjects
        new_teacher_user = User.objects.create_user(
            email='newteacher@test.com',
            password='testpass123',
            user_type='teacher'
        )
        
        new_teacher = Teacher.objects.create(
            user=new_teacher_user,
            fullname='New Teacher',
            gender='M'
        )
        
        self.client.force_authenticate(user=new_teacher_user)
        response = self.client.get(reverse('teacher_get_dashboard_data'))
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['has_levels'], False)

    def test_default_date_range(self):
        """Test default date range (this_month) when no parameters provided"""
        response = self.client.get(reverse('teacher_get_dashboard_data'))
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['has_levels'])
        
        dashboard = response.data['dashboard']
        self.assertIn('total_paid_amount', dashboard)
        self.assertIn('total_unpaid_amount', dashboard)
        self.assertIn('total_active_students', dashboard)
        self.assertIn('levels', dashboard)

    def test_custom_date_range(self):
        """Test dashboard with custom date range"""
        # Set up a specific date range
        start_date = '2023-01-01'
        end_date = '2023-02-28'
        
        response = self.client.get(
            f"{reverse('teacher:get_dashboard_data')}?start_date={start_date}&end_date={end_date}"
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        dashboard = response.data['dashboard']
        
        # In this date range, we should have:
        # - class1 (paid, January, Level 1) - 50.00
        # - class2 (paid, February, Level 1) - 50.00
        # - class4 (paid, February, Level 2) - 75.00
        # Total paid: 175.00
        # Total unpaid: 0.00
        
        # Check top level metrics
        self.assertEqual(Decimal(str(dashboard['total_paid_amount'])), Decimal('175.00'))
        self.assertEqual(Decimal(str(dashboard['total_unpaid_amount'])), Decimal('0.00'))
        self.assertEqual(dashboard['total_active_students'], 2)
        
        # Check level metrics
        self.assertIn('Level 1', dashboard['levels'])
        self.assertIn('Level 2', dashboard['levels'])
        
        level1 = dashboard['levels']['Level 1']
        self.assertEqual(Decimal(str(level1['total_paid_amount'])), Decimal('100.00'))
        self.assertEqual(Decimal(str(level1['total_unpaid_amount'])), Decimal('0.00'))
        self.assertEqual(level1['total_active_students'], 1)
        
        level2 = dashboard['levels']['Level 2']
        self.assertEqual(Decimal(str(level2['total_paid_amount'])), Decimal('75.00'))
        self.assertEqual(Decimal(str(level2['total_unpaid_amount'])), Decimal('0.00'))
        self.assertEqual(level2['total_active_students'], 1)
        
        # Check section metrics
        self.assertIn('sections', level1)
        self.assertIn('Section A', level1['sections'])
        
        section_a = level1['sections']['Section A']
        self.assertEqual(Decimal(str(section_a['total_paid_amount'])), Decimal('100.00'))
        self.assertEqual(Decimal(str(section_a['total_unpaid_amount'])), Decimal('0.00'))
        self.assertEqual(section_a['total_active_students'], 1)
        
        # Check subject metrics
        self.assertIn('subjects', section_a)
        self.assertIn('Math', section_a['subjects'])
        
        math = section_a['subjects']['Math']
        self.assertEqual(Decimal(str(math['total_paid_amount'])), Decimal('100.00'))
        self.assertEqual(Decimal(str(math['total_unpaid_amount'])), Decimal('0.00'))
        self.assertEqual(math['total_active_students'], 1)

    def test_date_range_with_unpaid_classes(self):
        """Test dashboard with a date range that includes unpaid classes"""
        start_date = '2023-03-01'
        end_date = '2023-03-31'
        
        response = self.client.get(
            f"{reverse('teacher:get_dashboard_data')}?start_date={start_date}&end_date={end_date}"
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        dashboard = response.data['dashboard']
        
        # In this date range, we should have:
        # - class3 (unpaid, March, Level 1) - 50.00
        # - class5 (unpaid, March, Level 2) - 75.00
        # Total paid: 0.00
        # Total unpaid: 125.00
        
        # Check top level metrics
        self.assertEqual(Decimal(str(dashboard['total_paid_amount'])), Decimal('0.00'))
        self.assertEqual(Decimal(str(dashboard['total_unpaid_amount'])), Decimal('125.00'))
        self.assertEqual(dashboard['total_active_students'], 2)
        
        # Check level metrics
        self.assertIn('Level 1', dashboard['levels'])
        self.assertIn('Level 2', dashboard['levels'])
        
        level1 = dashboard['levels']['Level 1']
        self.assertEqual(Decimal(str(level1['total_paid_amount'])), Decimal('0.00'))
        self.assertEqual(Decimal(str(level1['total_unpaid_amount'])), Decimal('50.00'))
        self.assertEqual(level1['total_active_students'], 1)
        
        level2 = dashboard['levels']['Level 2']
        self.assertEqual(Decimal(str(level2['total_paid_amount'])), Decimal('0.00'))
        self.assertEqual(Decimal(str(level2['total_unpaid_amount'])), Decimal('75.00'))
        self.assertEqual(level2['total_active_students'], 1)

    def test_date_preset_this_week(self):
        """Test dashboard with 'this_week' preset"""
        # Since we can't manipulate the current date in the test, 
        # and our test data is fixed, we can only check the structure
        response = self.client.get(
            f"{reverse('teacher_get_dashboard_data')}?date_range=this_week"
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['has_levels'])
        
        dashboard = response.data['dashboard']
        self.assertIn('total_paid_amount', dashboard)
        self.assertIn('total_unpaid_amount', dashboard)
        self.assertIn('total_active_students', dashboard)
        self.assertIn('levels', dashboard)

    def test_date_preset_this_year(self):
        """Test dashboard with 'this_year' preset"""
        response = self.client.get(
            f"{reverse('teacher_get_dashboard_data')}?date_range=this_year"
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['has_levels'])
        
        dashboard = response.data['dashboard']
        self.assertIn('total_paid_amount', dashboard)
        self.assertIn('total_unpaid_amount', dashboard)
        self.assertIn('total_active_students', dashboard)
        self.assertIn('levels', dashboard)

    def test_full_year_data(self):
        """Test dashboard with a full year of data"""
        start_date = '2023-01-01'
        end_date = '2023-12-31'
        
        response = self.client.get(
            f"{reverse('teacher:get_dashboard_data')}?start_date={start_date}&end_date={end_date}"
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        dashboard = response.data['dashboard']
        
        # In this date range, we should have all classes:
        # - class1 (paid, Level 1) - 50.00
        # - class2 (paid, Level 1) - 50.00
        # - class3 (unpaid, Level 1) - 50.00
        # - class4 (paid, Level 2) - 75.00
        # - class5 (unpaid, Level 2) - 75.00
        # Total paid: 175.00
        # Total unpaid: 125.00
        
        # Check top level metrics
        self.assertEqual(Decimal(str(dashboard['total_paid_amount'])), Decimal('175.00'))
        self.assertEqual(Decimal(str(dashboard['total_unpaid_amount'])), Decimal('125.00'))
        self.assertEqual(dashboard['total_active_students'], 2)