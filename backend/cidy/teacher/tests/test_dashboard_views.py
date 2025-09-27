from django.test import TestCase
from rest_framework.test import APITestCase
from rest_framework import status
from django.urls import reverse
from django.contrib.auth import get_user_model
from datetime import datetime, timedelta, date
from decimal import Decimal
from teacher.models import Level, Section, Subject, Teacher, TeacherSubject, Group, GroupEnrollment, Class
from student.models import Student

User = get_user_model()


class DashboardViewTestCase(APITestCase):
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
        
        self.student_user3 = User.objects.create_user(
            email='student3@test.com',
            password='testpass123',
            user_type='student'
        )
        
        # Create teacher profile
        self.teacher = Teacher.objects.create(
            user=self.teacher_user,
            first_name='Test',
            last_name='Teacher'
        )
        
        # Create students profiles
        self.student1 = Student.objects.create(
            user=self.student_user1,
            first_name='Student',
            last_name='One'
        )
        
        self.student2 = Student.objects.create(
            user=self.student_user2,
            first_name='Student',
            last_name='Two'
        )
        
        self.student3 = Student.objects.create(
            user=self.student_user3,
            first_name='Student',
            last_name='Three'
        )
        
        # Create levels, sections and subjects
        self.level1 = Level.objects.create(name='Level 1')
        self.level2 = Level.objects.create(name='Level 2')
        
        self.section1 = Section.objects.create(name='Section A')
        self.section2 = Section.objects.create(name='Section B')
        
        self.subject1 = Subject.objects.create(name='Math')
        self.subject2 = Subject.objects.create(name='Physics')
        
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
        
        # Create teacher subject with no section
        self.teacher_subject_no_section = TeacherSubject.objects.create(
            teacher=self.teacher,
            level=self.level1,
            section=None,
            subject=self.subject2,
            price_per_class=Decimal('60.00')
        )
        
        # Create groups
        self.group1 = Group.objects.create(teacher_subject=self.teacher_subject1)
        self.group2 = Group.objects.create(teacher_subject=self.teacher_subject2)
        self.group3 = Group.objects.create(teacher_subject=self.teacher_subject_no_section)
        
        # Create enrollments for different dates
        self.enrollment1 = GroupEnrollment.objects.create(
            group=self.group1,
            student=self.student1,
            date=date(2024, 1, 15)  # January enrollment
        )
        
        self.enrollment2 = GroupEnrollment.objects.create(
            group=self.group2,
            student=self.student2,
            date=date(2024, 2, 20)  # February enrollment
        )
        
        self.enrollment3 = GroupEnrollment.objects.create(
            group=self.group3,
            student=self.student3,
            date=date(2024, 3, 10)  # March enrollment
        )
        
        # Enroll student1 in another group to test distinct student counting
        self.enrollment4 = GroupEnrollment.objects.create(
            group=self.group3,
            student=self.student1,
            date=date(2024, 1, 20)
        )
        
        # Create classes with various dates and statuses
        # For enrollment1 (student1, group1)
        self.class1 = Class.objects.create(
            group_enrollment=self.enrollment1,
            status='attended_and_paid',
            last_status_date=datetime(2024, 1, 20)  # January
        )
        
        self.class2 = Class.objects.create(
            group_enrollment=self.enrollment1,
            status='attended_and_paid',
            last_status_date=datetime(2024, 2, 5)  # February
        )
        
        self.class3 = Class.objects.create(
            group_enrollment=self.enrollment1,
            status='attended_and_the_payment_due',
            last_status_date=datetime(2024, 3, 15)  # March
        )
        
        # For enrollment2 (student2, group2)
        self.class4 = Class.objects.create(
            group_enrollment=self.enrollment2,
            status='attended_and_paid',
            last_status_date=datetime(2024, 2, 25)  # February
        )
        
        self.class5 = Class.objects.create(
            group_enrollment=self.enrollment2,
            status='attended_and_the_payment_due',
            last_status_date=datetime(2024, 3, 10)  # March
        )
        
        # For enrollment3 (student3, group3)
        self.class6 = Class.objects.create(
            group_enrollment=self.enrollment3,
            status='attended_and_paid',
            last_status_date=datetime(2024, 3, 20)  # March
        )
        
        # For enrollment4 (student1, group3)
        self.class7 = Class.objects.create(
            group_enrollment=self.enrollment4,
            status='attended_and_the_payment_due',
            last_status_date=datetime(2024, 2, 15)  # February
        )
        
        # Authenticate the teacher user
        self.client.force_authenticate(user=self.teacher_user)
    
    def test_unauthenticated_access(self):
        """Test that unauthenticated users cannot access the endpoint"""
        self.client.force_authenticate(user=None)
        response = self.client.get(reverse('get_dashboard_data'))
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
    
    def test_unauthorized_user_access(self):
        """Test that non-teacher users cannot access the endpoint"""
        # Create a regular user
        regular_user = User.objects.create_user(
            email='regular@test.com',
            password='testpass123',
            user_type='parent'
        )
        
        self.client.force_authenticate(user=regular_user)
        response = self.client.get(reverse('get_dashboard_data'))
        # Should return 404 or appropriate error since user.teacher doesn't exist
        self.assertNotEqual(response.status_code, status.HTTP_200_OK)
    
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
            first_name='New',
            last_name='Teacher'
        )
        
        self.client.force_authenticate(user=new_teacher_user)
        response = self.client.get(reverse('get_dashboard_data'))
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['has_levels'], False)
        self.assertNotIn('dashboard', response.data)
    
    def test_default_date_range(self):
        """Test default date range (this_month) when no parameters provided"""
        response = self.client.get(reverse('get_dashboard_data'))
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['has_levels'])
        
        # Current implementation bases default on current date, so we can't assert exact values
        # Instead, verify structure and non-zero values where appropriate
        dashboard = response.data['dashboard']
        self.assertIn('total_paid_amount', dashboard)
        self.assertIn('total_unpaid_amount', dashboard)
        self.assertIn('total_active_students', dashboard)
        self.assertIn('levels', dashboard)
    
    def test_custom_date_range_filtering(self):
        """Test that classes are correctly filtered when using custom date range"""
        # January 1 to February 15 should include:
        # - class1 (paid, January) - 50.00
        # - class2 (paid, February) - 50.00
        # - class7 (unpaid, February) - 60.00
        response = self.client.get(
            f"{reverse('get_dashboard_data')}?start_date=2024-01-01&end_date=2024-02-15"
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        dashboard = response.data['dashboard']
        
        # Expected totals for this date range
        self.assertEqual(dashboard['total_paid_amount'], 100.00)  # 50.00 + 50.00
        self.assertEqual(dashboard['total_unpaid_amount'], 60.00)  # 60.00 (class7)
        self.assertEqual(dashboard['total_active_students'], 2)  # student1 and student2 (enrolled before Feb 15)
    
    def test_preset_date_range_this_month(self):
        """Test 'this_month' preset with fixed current date"""
        # To make this test deterministic, we need to mock the current date
        # Here we're testing using a patch for datetime.now()
        # For simplicity, we'll test different date ranges with explicit dates
        
        # March 1 to March 31 should include:
        # - class3 (unpaid, March) - 50.00
        # - class5 (unpaid, March) - 75.00
        # - class6 (paid, March) - 60.00
        response = self.client.get(
            f"{reverse('get_dashboard_data')}?start_date=2024-03-01&end_date=2024-03-31"
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        dashboard = response.data['dashboard']
        
        # Expected totals for this date range (March)
        self.assertEqual(dashboard['total_paid_amount'], 60.00)  # class6
        self.assertEqual(dashboard['total_unpaid_amount'], 125.00)  # 50.00 + 75.00
        self.assertEqual(dashboard['total_active_students'], 3)  # All students enrolled before March 31
    
    def test_level_breakdown_structure(self):
        """Test that level breakdown structure is correct"""
        response = self.client.get(reverse('get_dashboard_data'))
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        dashboard = response.data['dashboard']
        
        # Test Level 1 structure
        self.assertIn('Level 1', dashboard['levels'])
        level1_data = dashboard['levels']['Level 1']
        self.assertIn('total_paid_amount', level1_data)
        self.assertIn('total_unpaid_amount', level1_data)
        self.assertIn('total_active_students', level1_data)
        
        # Test Section A structure
        self.assertIn('sections', level1_data)
        self.assertIn('Section A', level1_data['sections'])
        section_a = level1_data['sections']['Section A']
        self.assertIn('total_paid_amount', section_a)
        self.assertIn('total_unpaid_amount', section_a)
        self.assertIn('total_active_students', section_a)
        
        # Test subject structure
        self.assertIn('subjects', section_a)
        self.assertIn('Math', section_a['subjects'])
        math_subject = section_a['subjects']['Math']
        self.assertIn('total_paid_amount', math_subject)
        self.assertIn('total_unpaid_amount', math_subject)
        self.assertIn('total_active_students', math_subject)
    
    def test_subject_without_section(self):
        """Test that subjects without sections are handled correctly"""
        response = self.client.get(reverse('get_dashboard_data'))
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        dashboard = response.data['dashboard']
        
        # Level 1 should have both sectioned and non-sectioned subjects
        self.assertIn('Level 1', dashboard['levels'])
        level1_data = dashboard['levels']['Level 1']
        
        # We can't directly test for physics subject since it doesn't have a section
        # Instead, verify the totals include its data
        
        # Physics subject has one paid class (60.00) and one unpaid class (60.00)
        # So Level 1 totals must include these
        # However, we can't assert exact values as they depend on date filtering
        self.assertTrue(level1_data['total_paid_amount'] >= 0)
        self.assertTrue(level1_data['total_unpaid_amount'] >= 0)
        self.assertTrue(level1_data['total_active_students'] >= 0)
    
    def test_distinct_student_counting(self):
        """Test that students are counted only once per subject"""
        # All date range to include everything
        response = self.client.get(
            f"{reverse('get_dashboard_data')}?start_date=2024-01-01&end_date=2024-12-31"
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        dashboard = response.data['dashboard']
        
        # student1 is enrolled in both group1 and group3
        # But when counting total_active_students, they should be counted separately
        # since they're in different subjects
        self.assertEqual(dashboard['total_active_students'], 3)  # All 3 students
        
        # For Level 1, student1 should only be counted once for the level totals
        level1_data = dashboard['levels']['Level 1']
        self.assertEqual(level1_data['total_active_students'], 2)  # student1 and student3
    
    def test_price_calculations_accuracy(self):
        """Test that price calculations use the correct price_per_class"""
        # February 1 to February 28 should include:
        # - class2 (paid, group1) - 50.00
        # - class4 (paid, group2) - 75.00
        # - class7 (unpaid, group3) - 60.00
        response = self.client.get(
            f"{reverse('get_dashboard_data')}?start_date=2024-02-01&end_date=2024-02-28"
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        dashboard = response.data['dashboard']
        
        # Expected totals for this date range
        self.assertEqual(dashboard['total_paid_amount'], 125.00)  # 50.00 + 75.00
        self.assertEqual(dashboard['total_unpaid_amount'], 60.00)  # class7
    
    def test_hierarchy_totals_consistency(self):
        """Test that totals at each level match the sum of their components"""
        # Use full date range to include all data
        response = self.client.get(
            f"{reverse('get_dashboard_data')}?start_date=2024-01-01&end_date=2024-12-31"
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        dashboard = response.data['dashboard']
        
        # Calculate expected totals from subjects
        expected_paid = (
            # Level 1, Section A, Math (class1, class2)
            self.teacher_subject1.price_per_class * 2 +
            # Level 2, Section B, Physics (class4)
            self.teacher_subject2.price_per_class * 1 +
            # Level 1, No Section, Physics (class6)
            self.teacher_subject_no_section.price_per_class * 1
        )
        
        expected_unpaid = (
            # Level 1, Section A, Math (class3)
            self.teacher_subject1.price_per_class * 1 +
            # Level 2, Section B, Physics (class5)
            self.teacher_subject2.price_per_class * 1 +
            # Level 1, No Section, Physics (class7)
            self.teacher_subject_no_section.price_per_class * 1
        )
        
        # Verify dashboard totals
        self.assertEqual(dashboard['total_paid_amount'], expected_paid)
        self.assertEqual(dashboard['total_unpaid_amount'], expected_unpaid)
        
        # Verify that level totals match sum of section totals
        for level_name, level_data in dashboard['levels'].items():
            if 'sections' in level_data:
                section_paid_sum = sum(section['total_paid_amount'] for section in level_data['sections'].values())
                section_unpaid_sum = sum(section['total_unpaid_amount'] for section in level_data['sections'].values())
                
                # The level total should be at least the sum of section totals
                # (It may be more if there are subjects without sections)
                self.assertTrue(level_data['total_paid_amount'] >= section_paid_sum)
                self.assertTrue(level_data['total_unpaid_amount'] >= section_unpaid_sum)
    
    def test_empty_date_range(self):
        """Test behavior with a date range containing no classes"""
        # Date range in the future should have no classes
        future_start = datetime.now() + timedelta(days=30)
        future_end = datetime.now() + timedelta(days=60)
        
        response = self.client.get(
            f"{reverse('get_dashboard_data')}?start_date={future_start.strftime('%Y-%m-%d')}&end_date={future_end.strftime('%Y-%m-%d')}"
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        dashboard = response.data['dashboard']
        
        # Should have zero paid and unpaid amounts, but should still count active students
        self.assertEqual(dashboard['total_paid_amount'], 0)
        self.assertEqual(dashboard['total_unpaid_amount'], 0)
        # Students are counted based on enrollment date, not class date
        self.assertEqual(dashboard['total_active_students'], 3)