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
        price_per_class = teacher_subject.price_per_class
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
            self.student_kpis[f"{student.id}"] = {'group_enrollment_unpaid_amount':group_enrollment.unpaid_amount,'teacher_enrollment_unpaid_amount':teacher_enrollment.unpaid_amount}
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
            group_enrollment.unpaid_amount = 8 * price_per_class
            teacher_enrollment.unpaid_amount = 8 * price_per_class
            self.group.total_unpaid = 8 * price_per_class

            self.student_kpis[f"{student.id}"] = {'group_enrollment_unpaid_amount':group_enrollment.unpaid_amount,'teacher_enrollment_unpaid_amount':teacher_enrollment.unpaid_amount,
                                                  'group_enrollment_attended_non_paid_classes':group_enrollment.attended_non_paid_classes}


            group_enrollment.save()
            teacher_enrollment.save()
            self.group.save()

        self.teacher_client = TeacherClient("teacher10@gmail.com", "iloveuu")

    def send_unmark_attendance_request(self, number_of_classes):
        # Example variables (replace them with your actual values)
        backend_url = f"{self.teacher_client.BACKEND_BASE_URL}/api/teacher/groups/{self.group.id}/students/unmark_attendance/"

        # Prepare the headers
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.teacher_client.access_token}",
        }

        # Prepare the payload
        payload = {
            "student_ids": self.student_ids,
            "number_of_classes": number_of_classes
        }

        # Send the PUT request
        response = requests.put(backend_url, headers=headers, data=json.dumps(payload))
        return response

    def test_unmarking_non_due_payment_classes(self):
        print("TEST UNMARKING THE NON DUE PAYMENT ATTENCE CLASSES")

        number_of_non_due_payment_classes = self.number_of_attended_classes_foreach_student % 4  # unmark the non due payment classes
        response = self.send_unmark_attendance_request(number_of_non_due_payment_classes)

        # ensure that the response of the request is as expected 
        assert response.status_code == 200, f"expected 200 but got {response.status_code} when unmarking attendance for non due payment classes"
        data = response.json()
        assert data['students_unmarked_completely_count'] == len(self.student_ids), f"the number of students that their non due payment classes unmarked completely is incorrect (expected {len(self.student_ids)}, got {data['students_unmarked_completely_count']})"
        assert len(data['students_without_enough_classes_to_unmark_their_attendance'])  == 0, f"the number of students that don't have enough attended classes is incorrect (expected 0, got {data['students_without_enough_classes_to_unmark_their_attendance']})"

        for student_id in self.student_ids : 
            student = Student.objects.get(id=student_id)
            new_group_enrollment = GroupEnrollment.objects.get(student=student,group=self.group)
            new_teacher_enrollment = TeacherEnrollment.objects.get(teacher=self.teacher,student=student)
            
            # ensure that the unpaid amount of the group enrollment and techer enrollment are correct
            assert new_group_enrollment.unpaid_amount == self.student_kpis[f'{student.id}']['group_enrollment_unpaid_amount'],f"the group enrollment unpaid amount of the student {student.fullname} is incorrect (expect : 0, got:{new_group_enrollment.unpaid_amount})"
            assert new_teacher_enrollment.unpaid_amount == self.student_kpis[f'{student.id}']['teacher_enrollment_unpaid_amount'],f"the teacher enrollment unpaid amount of the student {student.fullname} is incorrect (expect : 0, got:{new_teacher_enrollment.unpaid_amount})"
            
            # ensure that the number of attended non paid classes is correct 
            assert new_group_enrollment.attended_non_paid_classes == self.student_kpis[f'{student.id}']['group_enrollment_attended_non_paid_classes'] - number_of_non_due_payment_classes,f"the group enrollment attended non paid classes of the student {student.fullname} is incorrect (expect : {self.student_kpis[f'{student.id}']['group_enrollment_attended_non_paid_classes'] - number_of_non_due_payment_classes}, got:{new_group_enrollment.attended_non_paid_classes})"

            # ensure that the number of attended due payment classes  and the number of attended non due payment classes are correct
            student_classes = Class.objects.filter(group_enrollment=new_group_enrollment)
            attented_due_payment_classes_count = student_classes.filter(status='attended_and_the_payment_due')
            assert attented_due_payment_classes_count == self.number_of_attended_classes_foreach_student // 4 * 4 ,f"the attended due payment classes of the student {student.fullname} is incorrect (expect : {self.number_of_attended_classes_foreach_student // 4 * 4}, got:{attented_due_payment_classes_count})"
            attented_non_due_payment_classes_count = student_classes.filter(status='attended_and_the_payment_not_due')
            assert attented_non_due_payment_classes_count == (self.number_of_attended_classes_foreach_student % 4) - number_of_non_due_payment_classes ,f"the attended non due payment classes of the student {student.fullname} is incorrect (expect : {(self.number_of_attended_classes_foreach_student % 4) - number_of_non_due_payment_classes}, got:{attented_non_due_payment_classes_count})"

        # ensure that the total unpaid of the group is correct 
        new_group = Group.objects.first()
        assert new_group.total_unpaid == self.group.total_unpaid,f"the total unpaid of the group is incorrect (expected : 0, got:{new_group.total_unpaid})"

        print("THE TEST UNMARKING THE NON DUE PAYMENT ATTENDANCE CLASSES PASSED SUCCESSFULLY")


    def test_unmarking_due_payment_classes(self):
        pass

    def test_unmarking_more_than_the_existing_attended_classes(self):
        pass

    def test(self):
        print("START TESTTING THE UNMARK ATTENDANCE VIEW")

        self.test_unmarking_non_due_payment_classes()
 
        print("THE TEST OF THE UNMARKING ATTENDANCE VIEW PASSES SUCCESSFULLY")
        



