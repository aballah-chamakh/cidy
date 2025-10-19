"""

THE CASES TO TEST IN MARK PAYMENT : 

- THE MAIN PARAMETERS : 
    - attended non paid classes 
    - number of classes to mark as paid
- THE CASES :
    1. attended non paid classes == 0 number of classes to mark as paid = 2  : 
        - checks : 
            - the attend and non paid classes didn't descrease 
            - we create 2 classes to mark them as paid 
            - the paid amount increases and the unpaid amount doesn't decrease

    2. 0 < attended non paid classes < 4 and number of classes to mark as paid < attended non paid classes :
        - checks :
            - the attended non paid classes decrease by the number of classes marked as paid
            - we mark as paid thes oldest {number of classes to mark as paid} attended non paid classes
            - we will not create new classes 
            - the paid amount increases and the unpaid amount doesn't decrease

    3. 0 < attended non paid classes < 4 and  number of classes to mark as paid > attended non paid classes :
        - checks : 
            - the attended non paid classes become 0
            - we will use all the attended non paid classes to mark as paid
            - we will create new classes to mark as paid for the remaining number of classes to mark as paid
            - the paid amount increases and the unpaid amount doesn't decrease

    4. attended non paid classes = 7 and the number of classes to mark as paid = 2 
        - checks : 
            - we mark as paid thes oldest 2 attended non paid classes
            - decrease the attended non paid classes by  2 
            - decrease the unpaid amount by the price of 2 classes
            - increase the paid amount by the price of 2 classes
            - don't touch the rest of the attended and non paid classes 

    5. attended non paid classes = 7 and the number of classes to mark as paid = 4 
            - checks : 
                - we mark as paid the oldest 4 attended non paid classes
                - decrease the attended non paid classes by 4
                - reset the unpaid amount to 0 
                - increase the paid amount by the price of 4 classes
                - for the rest of attended and non paid classes mark them as paid not due

    6. attended non paid classes = 7 and the number of classes to mark as paid = 10
            - checks : 
                - we mark as paid all of the attended classes 
                - set the attended non paid classes = 0
                - create 3 new classes and marked them as paid
                - reset the unpaid amount to 0
                - increase the paid amount by the price of 10 classes
    


"""



import datetime
import requests, json
from account.models import User 
from teacher.models import Teacher,TeacherEnrollment, TeacherSubject,Level, Subject,Group, GroupEnrollment, Class
from student.models import Student
from teacher_app.TeacherClient import TeacherClient

class TestMarkPayment():

    # Data summary : 
    # 1 teacher
    # 9 teacher subjects
    # for each teacher subject : 2 groups 
    # for each teacher subject with a unique combination of level and section : 6 students created
    # for each group : 6 group enrollments (students), each 2 in a different time range 
    # for each group enrollment : 12 classes, 2 paid and 2 unpaid in each time range
    # time ranges : 
    #    - this week (1 Oct 2025)
    #    - this month (1 Oct 2025)
    #    - this year (10 and 14 Aug 2025)

    THIS_WEEK_DATES = [datetime.datetime(2025, 10, 1), datetime.datetime(2025, 10, 1)]
    THIS_MONTH_DATES = [datetime.datetime(2025, 10, 1), datetime.datetime(2025, 10, 1)]
    THIS_YEAR_DATES = [datetime.datetime(2025, 8, 10), datetime.datetime(2025, 8, 14)]


    def __init__(self):
        self.teacher_client = TeacherClient("teacher10@gmail.com", "iloveuu")




    def set_up(self):
        Student.objects.all().delete()
        User.objects.all().delete()
        User.objects.create_superuser("chamakhabdallah8@gmail.com","58671414", "cidy1234")

        # Create a teacher 
        user  = User.objects.create_user("teacher10@gmail.com", "44558866", "iloveuu")
        teacher = Teacher.objects.create(user=user,fullname="teacher10",gender="M")

        # Add the levels, sections and subjects
        bac_tech = Level.objects.get(name="Quatrième année secondaire",section="Technique")
        bac_info = Level.objects.get(name="Quatrième année secondaire",section="Informatique")

        basic_8th = Level.objects.get(name="Huitième année de base")
        basic_7th = Level.objects.get(name="Septième année de base")

        primary_1st = Level.objects.get(name="Première année primaire")
        primary_6th = Level.objects.get(name="Sixième année primaire")

        math_subject = Subject.objects.get(name="Mathématiques")
        physics_subject = Subject.objects.get(name="Physique")
        science_subject = Subject.objects.get(name="Éveil scientifique")

        # add the teacher subjects 
        teacher_subjects = []
        # bac technique  : math, physics
        teacher_subjects.append(TeacherSubject.objects.create(teacher=teacher,level=bac_tech,subject=math_subject,price_per_class=20))
        teacher_subjects.append(TeacherSubject.objects.create(teacher=teacher,level=bac_tech,subject=physics_subject,price_per_class=25))
        # bac info : math
        teacher_subjects.append(TeacherSubject.objects.create(teacher=teacher,level=bac_info,subject=math_subject,price_per_class=20))

        # basic 8th : math, physics
        teacher_subjects.append(TeacherSubject.objects.create(teacher=teacher,level=basic_8th,subject=math_subject,price_per_class=15))
        teacher_subjects.append(TeacherSubject.objects.create(teacher=teacher,level=basic_8th,subject=physics_subject,price_per_class=15))

        # basic 7th : math
        teacher_subjects.append(TeacherSubject.objects.create(teacher=teacher,level=basic_7th,subject=math_subject,price_per_class=15))

        # primary 6th : math, science
        teacher_subjects.append(TeacherSubject.objects.create(teacher=teacher,level=primary_6th,subject=math_subject,price_per_class=10))
        teacher_subjects.append(TeacherSubject.objects.create(teacher=teacher,level=primary_6th,subject=science_subject,price_per_class=10))

        # primary 1st : math
        teacher_subjects.append(TeacherSubject.objects.create(teacher=teacher,level=primary_1st,subject=math_subject,price_per_class=10))

        student_cnt = 1 
        # add related records to each teacher subject
        for index, teacher_subject in enumerate(teacher_subjects, start=1):

            # create 6 student for each level  
            ## if they don't exit
            students = Student.objects.filter(level=teacher_subject.level)#[:6]
            
            if not students.exists():
                students = []
                for i in range(12):
                    phone_number = f"000000{student_cnt}" if student_cnt >= 10 else f"0000000{student_cnt}"
                    student = Student.objects.create(
                        user=User.objects.create_user(f"student{student_cnt}@gmail.com", phone_number, "password"),
                        fullname = f"student{student_cnt}",
                        phone_number=phone_number,
                        gender="M",
                        level=teacher_subject.level
                    )
                    TeacherEnrollment.objects.create(teacher=teacher,student=student)
                    student_cnt += 1
                    #if i < 6:  # only keep 6 students per level
                    students.append(student)
                print(f"Created {len(students)} students for level {teacher_subject.level}")
            else:
                print(f"Found existing {students.count()} students for level {teacher_subject.level}")
            # add 2 groups for each teacher subject
            for group_name in ["A", "B"]:
                group = Group.objects.create( 
                                    teacher=teacher,
                                    teacher_subject=teacher_subject,
                                    week_day="Monday" if group_name == "A" else "Tuesday",
                                    start_time="18:00" if group_name == "A" else "20:00",
                                    end_time="20:00" if group_name == "A" else "22:00",
                                    name=f"Groupe {group_name}",
                                    total_paid= index * 100,
                                    total_unpaid= index * 100 )
                
                # enroll the 6 students in this group in different date ranges
                for i, student in enumerate(students):
                    # date range for this week  : 1 Oct 2025
                    if i < 2 : 
                        group_enrollement = GroupEnrollment.objects.create(group=group,student=student,date=TestMarkPayment.THIS_WEEK_DATES[0].date())
                        # create classes for this enrollment in different statuses and date ranges 
                        #self.create_classes_for_a_group_enrollment_in_different_status_and_date_ranges(group_enrollement)


                    # date range for this month : 1 Oct 2025
                    elif i < 4 :
                        group_enrollement = GroupEnrollment.objects.create(group=group,student=student,date=TestMarkPayment.THIS_MONTH_DATES[0].date())
                        #self.create_classes_for_a_group_enrollment_in_different_status_and_date_ranges(group_enrollement)
                    # date range for this year : 10 and 14 aug 2025
                    else:
                        group_enrollement = GroupEnrollment.objects.create(group=group,student=student,date=TestMarkPayment.THIS_YEAR_DATES[0].date())

    def mark_payment(self,group_id, student_ids, number_of_classes, payment_datetime):
        url = f"{self.teacher_client.BACKEND_BASE_URL}/api/teacher/groups/{group_id}/students/mark_payment/"

        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.teacher_client.access_token}",
        }

        payload = {
            "student_ids": list(student_ids),
            "number_of_classes": number_of_classes,
            "payment_datetime": payment_datetime,
        }

        requests.put(url, headers=headers, data=json.dumps(payload))
    
    def mark_attendance(self, group_id, student_ids):
        # Build the URL
        url = f"{self.teacher_client.BACKEND_BASE_URL}/api/teacher/groups/{group_id}/students/mark_attendance/"

        # Prepare headers
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.teacher_client.access_token}",
        }

        # Prepare payload
        payload = {
            "student_ids": list(student_ids),
            "date": f"15/08/2025",
            "start_time": f"18:00",
            "end_time": f"20:00",
        }

        requests.put(url, headers=headers, data=json.dumps(payload))
    
    def case_1(self):
        """
            - case : attended non paid classes == 0 number of classes to mark as paid = 2  : 
            - checks : 
                - the attend and non paid classes didn't descrease 
                - we create 2 classes to mark them as paid 
                - the paid amount increases and the unpaid amount doesn't decrease
        """
        print("Running TestMarkPayment.case_1")

        level = Level.objects.get(name="Quatrième année secondaire",section="Technique")

        student11 = Student.objects.get(fullname="student11", level=level)
        student12 = Student.objects.get(fullname="student12", level=level)
        student_ids = [student11.id, student12.id]
        
        teacher = Teacher.objects.get(user_email="teacher10@gmail.com")
        
        payment_datetime = datetime.datetime.now().strftime("%H:%M:%S-%d/%m/%Y")
        number_of_classes = 2

        self.mark_payment(group.id, student_ids, number_of_classes, payment_datetime)

        # Refresh the group enrollments from the database
        group = Group.objects.get(name="Groupe A", teacher_subject__level=level, teacher_subject__subject__name="Mathématiques")
        group_enrollment_11 = GroupEnrollment.objects.get(student=student11, group=group)
        teacher_enrollment_11 = TeacherEnrollment.objects.get(teacher=teacher, student=student11)
        group_enrollment_12 = GroupEnrollment.objects.get(student=student12, group=group)
        teacher_enrollment_12 = TeacherEnrollment.objects.get(teacher=teacher, student=student12)

        # Check that the attend and non paid classes didn't decrease
        assert group_enrollment_11.attended_non_paid_classes == 0, "Attended non paid classes should remain 0 for student 11"
        assert group_enrollment_12.attended_non_paid_classes == 0, "Attended non paid classes should remain 0 for student 12"

        # Check that the paid amount increased correctly and the unpaid amount didn't change
        assert group_enrollment_11.paid_amount == number_of_classes * group.teacher_subject.price_per_class, "the paid amount of group enrollment of the student 11 should increase correctly"
        assert group_enrollment_11.unpaid_amount == group_enrollment_11.unpaid_amount, "the unpaid amount of group enrollment of the student 11 should not change"
        assert teacher_enrollment_11.paid_amount == number_of_classes * group.teacher_subject.price_per_class, "the paid amount of teacher enrollment of the student 11 should increase correctly"
        assert teacher_enrollment_11.unpaid_amount == teacher_enrollment_11.unpaid_amount, "the unpaid amount of teacher enrollment of the student 11 should not change"
        assert group_enrollment_12.paid_amount == number_of_classes * group.teacher_subject.price_per_class, "the paid amount of group enrollment of the student 12 should increase correctly"
        assert group_enrollment_12.unpaid_amount == group_enrollment_12.unpaid_amount, "the unpaid amount of group enrollment of the student 12 should not change"
        assert teacher_enrollment_12.paid_amount == number_of_classes * group.teacher_subject.price_per_class, "the paid amount of teacher enrollment of the student 12 should increase correctly"
        assert teacher_enrollment_12.unpaid_amount == teacher_enrollment_12.unpaid_amount, "the unpaid amount of teacher enrollment of the student 12 should not change"
        
        # Check that 2 new classes were created and marked as paid
        assert Class.objects.filter(group_enrollment=group_enrollment_11, status='paid').count() == 2, "There should be 2 new classes marked as paid for student 11"
        assert Class.objects.filter(group_enrollment=group_enrollment_12, status='paid').count() == 2, "There should be 2 new classes marked as paid for student 12"

        print("TestMarkPayment.case_1 passed successfully.")

    def case_2(self):
        """
            - case 2 :  0 < attended non paid classes < 4 and number of classes to mark as paid < attended non paid classes :
            - checks :
                - the attended non paid classes decrease by the number of classes marked as paid
                - we mark as paid thes oldest {number of classes to mark as paid} attended non paid classes
                - we will not create new classes 
                - the paid amount increases and the unpaid amount doesn't decrease
        """

        print("Running TestMarkPayment.case_2")

        attended_non_paid_classes = 3
        number_of_classes_to_mark_as_paid = 2

        
        level = Level.objects.get(name="Quatrième année secondaire",section="Technique")
        student11 = Student.objects.get(fullname="student11", level=level)
        student12 = Student.objects.get(fullname="student12", level=level)
        student_ids = [student11.id, student12.id]
        teacher = Teacher.objects.get(user_email="teacher10@example.com")
        group = Group.objects.get(name="Groupe A",teacher=teacher, teacher_subject__level=level, teacher_subject__subject__name="Mathématiques")

        # create 3 attended non paid classes for student 11 and student 12
        for i in range(attended_non_paid_classes):
            self.mark_attendance(group.id, [student11.id, student12.id])
        
        old_group_enrollment_11 = GroupEnrollment.objects.get(student=student11, group=group)
        old_classes_11 = Class.objects.filter(group_enrollment=old_group_enrollment_11, status__in=['attended_and_the_payment_due', 'attended_and_not_paid']).order_by('attendance_date', 'attendance_start_time')
        old_teacher_enrollment_11 = TeacherEnrollment.objects.get(teacher=teacher, student=student11)
       
        old_group_enrollment_12 = GroupEnrollment.objects.get(student=student12, group=group)
        old_classes_12 = Class.objects.filter(group_enrollment=old_group_enrollment_12, status__in=['attended_and_the_payment_due', 'attended_and_not_paid']).order_by('attendance_date', 'attendance_start_time')
        old_teacher_enrollment_12 = TeacherEnrollment.objects.get(teacher=teacher, student=student12)
        
        student_ids = [student11.id, student12.id]
        payment_datetime = datetime.datetime.now().strftime("%H:%M:%S-%d/%m/%Y")
        
        self.mark_payment(group.id, student_ids, number_of_classes_to_mark_as_paid, payment_datetime)

        # Refresh the group enrollments from the database
        group_enrollment_11 = GroupEnrollment.objects.get(student=student11, group=group)
        teacher_enrollment_11 = TeacherEnrollment.objects.get(teacher=teacher, student=student11)

        group_enrollment_12 = GroupEnrollment.objects.get(student=student12, group=group)
        teacher_enrollment_12 = TeacherEnrollment.objects.get(teacher=teacher, student=student12)
        # Check that the attended non paid classes decreased correctly
        assert group_enrollment_11.attended_non_paid_classes == old_group_enrollment_11.attended_non_paid_classes - number_of_classes_to_mark_as_paid, "Attended non paid classes should decrease correctly for student 11"
        assert group_enrollment_12.attended_non_paid_classes == old_group_enrollment_12.attended_non_paid_classes - number_of_classes_to_mark_as_paid, "Attended non paid classes should decrease correctly for student 12" 

        # Check that the paid and unpaid amounts are correct
        assert group_enrollment_11.paid_amount == old_group_enrollment_11.paid_amount + number_of_classes_to_mark_as_paid * group.teacher_subject.price_per_class, "Paid amount should increase correctly for student 11"
        assert group_enrollment_11.unpaid_amount == old_group_enrollment_11.unpaid_amount, "Unpaid amount should not change for student 11"
        assert teacher_enrollment_11.paid_amount == old_teacher_enrollment_11.paid_amount + number_of_classes_to_mark_as_paid * group.price_per_class, "Paid amount should increase correctly for student 11"
        assert teacher_enrollment_11.unpaid_amount == old_teacher_enrollment_11.unpaid_amount, "Unpaid amount should not decrease for student 11"
        
        assert group_enrollment_12.paid_amount == old_group_enrollment_12.paid_amount + number_of_classes_to_mark_as_paid * group.teacher_subject.price_per_class, "Paid amount should increase correctly for student 12"
        assert group_enrollment_12.unpaid_amount == old_group_enrollment_12.unpaid_amount, "Unpaid amount should not change for student 12"
        assert teacher_enrollment_12.paid_amount == old_teacher_enrollment_12.paid_amount + number_of_classes_to_mark_as_paid * group.teacher_subject.price_per_class, "Paid amount should increase correctly for student 12"
        assert teacher_enrollment_12.unpaid_amount == old_teacher_enrollment_12.unpaid_amount, "Unpaid amount should not decrease for student 12"

        print("TestMarkPayment.case_2 passed successfully.")







