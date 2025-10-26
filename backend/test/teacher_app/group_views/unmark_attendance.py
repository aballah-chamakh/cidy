from account.models import User 
from teacher.models import Teacher,TeacherEnrollment, TeacherSubject,Level, Subject,Group, GroupEnrollment, Class
from student.models import Student
from teacher_app.TeacherClient import TeacherClient
import requests
import json
import  datetime


class TestUnMarkAttendance : 

    def set_up(self):
        
        Student.objects.all().delete()
        User.objects.all().delete()
        User.objects.create_superuser("chamakhabdallah8@gmail.com","58671414", "cidy1234")

        # Create a teacher 
        user  = User.objects.create_user("teacher10@gmail.com", "44558866", "iloveuu")
        self.teacher = Teacher.objects.create(user=user,fullname="teacher10",gender="M")

        bac_tech = Level.objects.get(name="Quatrième année secondaire",section="Technique")
        math_subject = Subject.objects.get(name="Mathématiques")

        teacher_subject = TeacherSubject.objects.create(teacher=self.teacher,level=bac_tech,subject=math_subject,price_per_class=20)
        self.group = Group.objects.create(teacher=self.teacher,name="Groupe A",teacher_subject=teacher_subject,week_day="Monday",start_time="10:00",end_time="12:00")    
        self.price_per_class = teacher_subject.price_per_class
        self.number_of_attended_classes_foreach_student = 10
        self.student_ids = []
        self.student_kpis = {}
        # Create a student and enroll him to the group
        for i in range(3):
            student = Student.objects.create(
                fullname=f"student{i+1}",
                phone_number=f"0000000{i+1}",
                level = bac_tech,
                gender="M"
            )
            self.student_ids.append(student.id)
            group_enrollment = GroupEnrollment.objects.create(student=student,group=self.group)
            teacher_enrollment = TeacherEnrollment.objects.create(teacher=self.teacher,student=student)
            for i in range(self.number_of_attended_classes_foreach_student) : 
                attendance_date = datetime.date.today()
                attendance_start_time = datetime.time(i + 8, 0)
                attendance_end_time = datetime.time(i + 9, 0)
                Class.objects.create(
                    group_enrollment=group_enrollment,
                    attendance_date = attendance_date,
                    attendance_start_time = attendance_start_time,
                    attendance_end_time = attendance_end_time,
                    status = 'attended_and_the_payment_due' if i < 8 else 'attended_and_the_payment_not_due'
                )

            group_enrollment.attended_non_paid_classes = self.number_of_attended_classes_foreach_student
            unpaid_amount = 8 * self.price_per_class  # first 8 classes are due payment
            group_enrollment.unpaid_amount = unpaid_amount
            teacher_enrollment.unpaid_amount = unpaid_amount
            self.group.total_unpaid = unpaid_amount * 3

            self.student_kpis[f"{student.id}"] = {'group_enrollment_unpaid_amount':group_enrollment.unpaid_amount,'teacher_enrollment_unpaid_amount':teacher_enrollment.unpaid_amount,
                                                  'group_enrollment_attended_non_paid_classes':group_enrollment.attended_non_paid_classes}


            group_enrollment.save()
            teacher_enrollment.save()
            self.group.save()

        self.teacher_client = TeacherClient("teacher10@gmail.com", "iloveuu")

    def send_unmark_attendance_request(self, number_of_classes, student_ids=None):
        # Example variables (replace them with your actual values)
        backend_url = f"{self.teacher_client.BACKEND_BASE_URL}/api/teacher/groups/{self.group.id}/students/unmark_attendance/"

        # Prepare the headers
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.teacher_client.access_token}",
        }

        # Prepare the payload
        payload = {
            "student_ids": self.student_ids if not student_ids else student_ids,
            "number_of_classes": number_of_classes
        }

        # Send the PUT request
        response = requests.put(backend_url, headers=headers, data=json.dumps(payload))
        return response

    def test_unmarking_non_due_payment_classes(self):
        print("\tTEST UNMARKING 2 NON DUE PAYMENT ATTENDED CLASSES")

        number_of_non_due_payment_classes = 2  # unmark the non due payment classes
        response = self.send_unmark_attendance_request(number_of_non_due_payment_classes)

        # ensure that the response of the request is as expected 
        assert response.status_code == 200, f"expected 200 but got {response.status_code} when unmarking attendance for non due payment classes"
        data = response.json()
        assert data['students_unmarked_completely_count'] == len(self.student_ids), f"the number of students that their non due payment classes unmarked completely is incorrect (expecteded {len(self.student_ids)}, got {data['students_unmarked_completely_count']})"
        assert len(data['students_without_enough_classes_to_unmark_their_attendance'])  == 0, f"the number of students that don't have enough attended classes is incorrect (expecteded 0, got {len(data['students_without_enough_classes_to_unmark_their_attendance'])})"
        expected_due_payment_classes_count = 8  # after unmarking non due payment classes, 8 due payment classes should remain for each student
        for student_id in self.student_ids : 
            student = Student.objects.get(id=student_id)
            new_group_enrollment = GroupEnrollment.objects.get(student=student,group=self.group)
            new_teacher_enrollment = TeacherEnrollment.objects.get(teacher=self.teacher,student=student)
            
            # ensure that the unpaid amount of the group enrollment and techer enrollment are correct
            assert new_group_enrollment.unpaid_amount == expected_due_payment_classes_count * self.price_per_class,f"the group enrollment unpaid amount of the student {student.fullname} is incorrect (expected : 0, got:{new_group_enrollment.unpaid_amount})"
            assert new_teacher_enrollment.unpaid_amount ==  expected_due_payment_classes_count * self.price_per_class ,f"the teacher enrollment unpaid amount of the student {student.fullname} is incorrect (expected : 0, got:{new_teacher_enrollment.unpaid_amount})"
            
            # ensure that the number of attended non paid classes is correct 
            assert new_group_enrollment.attended_non_paid_classes == expected_due_payment_classes_count,f"the group enrollment attended non paid classes of the student {student.fullname} is incorrect (expected : {expected_due_payment_classes_count}, got:{new_group_enrollment.attended_non_paid_classes})"

            # ensure that the number of attended due payment classes  and the number of attended non due payment classes are correct
            student_classes = Class.objects.filter(group_enrollment=new_group_enrollment)
            attented_due_payment_classes_count = student_classes.filter(status='attended_and_the_payment_due').count()
            assert attented_due_payment_classes_count == expected_due_payment_classes_count ,f"the attended due payment classes of the student {student.fullname} is incorrect (expected : {expected_due_payment_classes_count}, got:{attented_due_payment_classes_count})"
            attented_non_due_payment_classes_count = student_classes.filter(status='attended_and_the_payment_not_due').count()
            assert attented_non_due_payment_classes_count == 0 ,f"the attended non due payment classes of the student {student.fullname} is incorrect (expected : 0, got:{attented_non_due_payment_classes_count})"

        # ensure that the total unpaid of the group is correct 
        new_group = Group.objects.first()
        expected_group_total_unpaid = expected_due_payment_classes_count * self.price_per_class * len(self.student_ids)
        assert new_group.total_unpaid == expected_group_total_unpaid,f"the total unpaid of the group is incorrect (expecteded : {expected_group_total_unpaid}, got:{new_group.total_unpaid})"

        print("\tTHE TEST of UNMARKING 2 NON DUE PAYMENT ATTENDED CLASSES PASSED SUCCESSFULLY\n")

    # unmark 2 of the due payment classes for the last 2 students
    def test_unmarking_due_payment_classes(self):
        print("\tTEST UNMARKING 2 DUE PAYMENT ATTENDED CLASSES")
        response = self.send_unmark_attendance_request(2,student_ids=self.student_ids[1:])  # unmark due payment classes for only one student

        # ensure that the response of the request is as expected 
        assert response.status_code == 200, f"expected 200 but got {response.status_code} when unmarking attendance for due payment classes"
        data = response.json()
        assert data['students_unmarked_completely_count'] == len(self.student_ids[1:]), f"the number of students that their  due payment classes unmarked completely is incorrect (expecteded {len(self.student_ids[1:])}, got {data['students_unmarked_completely_count']})"
        assert len(data['students_without_enough_classes_to_unmark_their_attendance'])  == 0, f"the number of students that don't have enough attended classes is incorrect (expecteded 0, got {len(data['students_without_enough_classes_to_unmark_their_attendance'])})"
        expected_due_payment_classes_count = 4 
        expected_non_due_payment_classes_count = 2  
        for student_id in self.student_ids[1:] : 
            student = Student.objects.get(id=student_id)
            new_group_enrollment = GroupEnrollment.objects.get(student=student,group=self.group)
            new_teacher_enrollment = TeacherEnrollment.objects.get(teacher=self.teacher,student=student)
            
            # ensure that the unpaid amount of the group enrollment and techer enrollment are correct
            expected_unpaid_amount = expected_due_payment_classes_count * self.price_per_class
            assert new_group_enrollment.unpaid_amount == expected_unpaid_amount,f"the group enrollment unpaid amount of the student {student.fullname} is incorrect (expected : {expected_unpaid_amount}, got:{new_group_enrollment.unpaid_amount})"
            assert new_teacher_enrollment.unpaid_amount ==  expected_unpaid_amount ,f"the teacher enrollment unpaid amount of the student {student.fullname} is incorrect (expected : {expected_unpaid_amount}, got:{new_teacher_enrollment.unpaid_amount})"

            # ensure that the number of attended non paid classes is correct
            assert new_group_enrollment.attended_non_paid_classes == expected_due_payment_classes_count + expected_non_due_payment_classes_count,f"the group enrollment attended non paid classes of the student {student.fullname} is incorrect (expected : {expected_due_payment_classes_count + expected_non_due_payment_classes_count}, got:{new_group_enrollment.attended_non_paid_classes})"

            # ensure that the number of attended due payment classes  and the number of attended non due payment classes are correct
            student_classes = Class.objects.filter(group_enrollment=new_group_enrollment)
            attented_due_payment_classes_count = student_classes.filter(status='attended_and_the_payment_due').count()
            assert attented_due_payment_classes_count == expected_due_payment_classes_count ,f"the attended due payment classes of the student {student.fullname} is incorrect (expected : {expected_due_payment_classes_count}, got:{attented_due_payment_classes_count})"
            attented_non_due_payment_classes_count = student_classes.filter(status='attended_and_the_payment_not_due').count()
            assert attented_non_due_payment_classes_count == expected_non_due_payment_classes_count ,f"the attended non due payment classes of the student {student.fullname} is incorrect (expected : {expected_non_due_payment_classes_count}, got:{attented_non_due_payment_classes_count})"

        # ensure that the total unpaid of the group is correct 
        new_group = Group.objects.first()
        expected_group_total_unpaid = expected_due_payment_classes_count * self.price_per_class * len(self.student_ids[1:]) + 8 * self.price_per_class  # first student still has 8 due payment classes
        assert new_group.total_unpaid == expected_group_total_unpaid,f"the total unpaid of the group is incorrect (expecteded : {expected_group_total_unpaid}, got:{new_group.total_unpaid})"
        print("\tTHE TEST of UNMARKING 2 DUE PAYMENT ATTENDED CLASSES PASSED SUCCESSFULLY`\n")
        
    def test_unmarking_more_than_the_existing_attended_classes(self):
        print("\tTEST UNMARKING MORE THAN THE EXISTING ATTENDED CLASSES")
        # now we have two student with 6 attended classes and one with 8 classes 
        # and we will test by unmarking 8 classes to get one completely unmarked 
        # and the other two not completly unmarked 
        number_of_classes_to_unmark = 8 
        response = self.send_unmark_attendance_request(number_of_classes_to_unmark)

        # ensure that the response of the request is as expected 
        assert response.status_code == 200, f"expected 200 but got {response.status_code} when unmarking more the existing attended classes"
        data = response.json()
        assert data['students_unmarked_completely_count'] == 1, f"the number of students that their attended classes unmarked completely is incorrect (expecteded 1, got {data['students_unmarked_completely_count']})"
        assert len(data['students_without_enough_classes_to_unmark_their_attendance'])  == 2, f"the number of students that don't have enough attended classes is incorrect (expecteded 2, got {len(data['students_without_enough_classes_to_unmark_their_attendance'])})"
        
        # note i reverse the student ids to match the order in which they appear in the response
        for idx, student_id in enumerate(self.student_ids[1:][::-1]) :
            student = Student.objects.get(id=student_id)
            
            assert data['students_without_enough_classes_to_unmark_their_attendance'][idx]  == {
                'id' : student.id,
                'image' : student.image.url,  
                'fullname': student.fullname,
                'missing_number_of_classes_to_unmark' : 2
            },f"the data of the student {student.fullname} is incorrect in the students_without_enough_classes_to_unmark_their_attendance list"
        
        expected_attended_classes_count = 0
        for student_id in self.student_ids : 
            student = Student.objects.get(id=student_id)
            new_group_enrollment = GroupEnrollment.objects.get(student=student,group=self.group)
            new_teacher_enrollment = TeacherEnrollment.objects.get(teacher=self.teacher,student=student)
            
            # ensure that the unpaid amount of the group enrollment and techer enrollment are correct
            expected_unpaid_amount = expected_attended_classes_count * self.price_per_class
            assert new_group_enrollment.unpaid_amount == expected_unpaid_amount,f"the group enrollment unpaid amount of the student {student.fullname} is incorrect (expected : {expected_unpaid_amount}, got:{new_group_enrollment.unpaid_amount})"
            assert new_teacher_enrollment.unpaid_amount ==  expected_unpaid_amount ,f"the teacher enrollment unpaid amount of the student {student.fullname} is incorrect (expected : {expected_unpaid_amount}, got:{new_teacher_enrollment.unpaid_amount})"

            # ensure that the number of attended non paid classes is correct
            assert new_group_enrollment.attended_non_paid_classes == expected_attended_classes_count,f"the group enrollment attended non paid classes of the student {student.fullname} is incorrect (expected : {expected_attended_classes_count}, got:{new_group_enrollment.attended_non_paid_classes})"

            # ensure that the number of attended due payment classes  and the number of attended non due payment classes are correct
            student_classes = Class.objects.filter(group_enrollment=new_group_enrollment)
            attented_due_payment_classes_count = student_classes.filter(status='attended_and_the_payment_due').count()
            assert attented_due_payment_classes_count == expected_attended_classes_count ,f"the attended due payment classes of the student {student.fullname} is incorrect (expected : {expected_attended_classes_count}, got:{attented_due_payment_classes_count})"
            attented_non_due_payment_classes_count = student_classes.filter(status='attended_and_the_payment_not_due').count()
            assert attented_non_due_payment_classes_count == expected_attended_classes_count ,f"the attended non due payment classes of the student {student.fullname} is incorrect (expected : {expected_attended_classes_count}, got:{attented_non_due_payment_classes_count})"

        # ensure that the total unpaid of the group is correct 
        new_group = Group.objects.first()
        expected_group_total_unpaid = expected_attended_classes_count * self.price_per_class * len(self.student_ids) 
        assert new_group.total_unpaid == expected_group_total_unpaid,f"the total unpaid of the group is incorrect (expecteded : {expected_group_total_unpaid}, got:{new_group.total_unpaid})"

        print("\tTHE TEST OF UNMARKING MORE THAN THE EXISTING ATTENDED CLASSES PASSED SUCCESSFULLY.\n")

    def test(self):
        print("START TESTTING THE UNMARK ATTENDANCE VIEW \n")

        self.test_unmarking_non_due_payment_classes()
        self.test_unmarking_due_payment_classes()
        self.test_unmarking_more_than_the_existing_attended_classes()
 
        print("\n THE TEST OF THE UNMARKING ATTENDANCE VIEW PASSES SUCCESSFULLY")
        



