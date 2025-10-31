from account.models import User 
from teacher.models import Teacher,TeacherEnrollment, TeacherSubject,Level, Subject,Group, GroupEnrollment, Class
from student.models import Student
from teacher_app.TeacherClient import TeacherClient
import requests
import json
import  datetime


class TestMarkAttendanceAndPayment : 

    def set_up(self):
        Student.objects.all().delete()
        User.objects.all().delete()
        User.objects.create_superuser("chamakhabdallah8@gmail.com","58671414", "cidy1234")

        # Create a teacher 
        user  = User.objects.create_user("teacher10@gmail.com", "44558866", "iloveuu")
        teacher = Teacher.objects.create(user=user,fullname="teacher10",gender="M")

        bac_tech = Level.objects.get(name="Quatrième année secondaire",section="Technique")
        math_subject = Subject.objects.get(name="Mathématiques")

        teacher_subject = TeacherSubject.objects.create(teacher=teacher,level=bac_tech,subject=math_subject,price_per_class=20)
        group = Group.objects.create(teacher=teacher,name="Groupe A",teacher_subject=teacher_subject,week_day="Monday",start_time="10:00",end_time="12:00")    

        # Create 3 students and enroll them to the group
        for i in range(4):
            student = Student.objects.create(
                fullname=f"student{i+1}",
                phone_number=f"0000000{i+1}",
                level = bac_tech,
                gender="M"
            )
            group_enrollment = GroupEnrollment.objects.create(student=student,group=group)
            teacher_enrollment =  TeacherEnrollment.objects.create(teacher=teacher,student=student)

            # create 4 attended, due payment classes for each student 
            for i in range(4):
                Class.objects.create(
                    group_enrollment=group_enrollment,
                    attendance_date=datetime.date.today(),
                    attendance_start_time=datetime.time(8 + i, 0),
                    attendance_end_time=datetime.time(9 + i, 0),
                    status='attended_and_the_payment_due' 
                )
            group_enrollment.attended_non_paid_classes = 4
            group_enrollment.unpaid_amount =  4 * teacher_subject.price_per_class
            group_enrollment.save()
            teacher_enrollment.unpaid_amount = 4 * teacher_subject.price_per_class
            teacher_enrollment.save()

        group.total_unpaid = 4 * 4 * teacher_subject.price_per_class
        group.save()
    
        self.teacher_client = TeacherClient("teacher10@gmail.com", "iloveuu")

    def send_mark_attendance_and_payment_request(self, group_id, student_ids, attendance_date, attendance_start_time, attendance_end_time, payment_datetime):
        backend_url = f"{self.teacher_client.BACKEND_BASE_URL}/api/teacher/groups/{group_id}/students/mark_attendance_and_payment/"

        # Prepare the headers
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.teacher_client.access_token}",
        }

        # Prepare the payload
        payload = {
            "student_ids": list(student_ids),
            "date": attendance_date.strftime("%d/%m/%Y"),
            "start_time": attendance_start_time.strftime("%H:%M"),
            "end_time": attendance_end_time.strftime("%H:%M"),
            "payment_datetime": payment_datetime.strftime("%H:%M:%S-%d/%m/%Y"),
        }

        # Send the PUT request
        response = requests.put(backend_url, headers=headers, data=json.dumps(payload))
        return response


    def test_mark_attendance_and_payment_without_schedule_conflict(self):
        print("\tSTARTING THE TEST OF MARKING ATTENDANCE AND PAYMENT WITHOUT SCHEDULE CONFLICT : ")
        group = Group.objects.first()
        students = group.students.all().order_by('id')
        student_ids = [student.id for student in students[:3]]  # Select first 3 students
        price_per_class = group.teacher_subject.price_per_class
        attendance_date = datetime.date.today()
        attendance_start_time = datetime.time(20, 0)
        attendance_end_time = datetime.time(21, 0)
        payment_datetime = datetime.datetime.now()
        response = self.send_mark_attendance_and_payment_request(
            group.id,
            student_ids,
            attendance_date,
            attendance_start_time,
            attendance_end_time,
            payment_datetime
        )
        assert response.status_code == 200, f"the status code of the mark attendance and payment is incorrect, expected 200 but got {response.status_code}"
        response_data = response.json()
        assert response_data['students_marked_count'] == 3, f"the number of students marked is incorrect (expected 3, got {response_data['students_marked_count']})"
        assert len(response_data['students_with_overlapping_classes']) == 0, f"the number of students with overlapping classes is incorrect (expected [], got {response_data['students_with_overlapping_classes']})"

        # Verify that each student's attended_non_paid_classes decreased by 1 and unpaid_amount decreased
        for student in students[:3]:
            group_enrollment = GroupEnrollment.objects.get(student=student, group=group)
            assert group_enrollment.attended_non_paid_classes == 4, f"the attended_non_paid_classes of the group_enrollment of the student {student.fullname} is incorrect (expected 4, got {group_enrollment.attended_non_paid_classes})"
            assert group_enrollment.unpaid_amount == 4 * price_per_class, f"the unpaid_amount of the group_enrollment of the student {student.fullname} is incorrect (expected {4 * price_per_class}, got {group_enrollment.unpaid_amount})"  # price_per_class is 20
            assert group_enrollment.paid_amount ==  price_per_class, f"the paid_amount of the group_enrollment of the student {student.fullname} is incorrect (expected {price_per_class}, got {group_enrollment.paid_amount})"

            teacher_enrollment = TeacherEnrollment.objects.get(teacher=group.teacher, student=student)
            assert teacher_enrollment.unpaid_amount == 4 * price_per_class, f"the unpaid_amount of the teacher_enrollment of the student {student.fullname} is incorrect (expected {4 * price_per_class}, got {teacher_enrollment.unpaid_amount})"
            assert teacher_enrollment.paid_amount == price_per_class, f"the paid_amount of the teacher_enrollment of the student {student.fullname} is incorrect (expected {price_per_class}, got {teacher_enrollment.paid_amount})"

        # Verify that the group's total_unpaid decreased accordingly
        group.refresh_from_db()
        expected_group_total_unpaid = 4 * 4 * price_per_class
        assert group.total_unpaid == expected_group_total_unpaid, f"the total_unpaid of the group {group.id} is incorrect (expected {expected_group_total_unpaid}, got {group.total_unpaid})"
        print("\tTHE TEST OF MARKING ATTENDANCE AND PAYMENT WITHOUT SCHEDULE CONFLICT PASSED SUCCESSFULLY.")

    def test_mark_attendance_and_payment_with_schedule_conflict(self):
        print("\tSTARTING THE TEST OF MARKING ATTENDANCE AND PAYMENT WITH SCHEDULE CONFLICT : ")
        group = Group.objects.first()
        students = group.students.all().order_by('id')
        student_ids = [student.id for student in students]  # Select first 3 students
        attendance_date = datetime.date.today()
        attendance_start_time = datetime.time(20, 30)  # This time overlaps with the group's schedule (10:00 - 12:00)
        attendance_end_time = datetime.time(21, 30)
        payment_datetime = datetime.datetime.now()
        response = self.send_mark_attendance_and_payment_request(
            group.id,
            student_ids,
            attendance_date,
            attendance_start_time,
            attendance_end_time,
            payment_datetime
        )

        # ensure that the response is correct
        assert response.status_code == 200, f"the status code of the mark attendance and payment is incorrect, expected 200 but got {response.status_code}"
        response_data = response.json()
        assert response_data['students_marked_count'] == 1, f"the number of students marked is incorrect (expected 1, got {response_data['students_marked_count']})"
        assert len(response_data['students_with_overlapping_classes']) == 3, f"the number of students with overlapping classes is incorrect (expected 3, got {len(response_data['students_with_overlapping_classes'])})"
        expected_students_with_overlapping_classes = [
            {
                'id' : student.id,
                'image' : student.image.url,
                'fullname' : student.fullname 
            }
            for student in students[:3][::-1]
        ]
        assert response_data['students_with_overlapping_classes'] == expected_students_with_overlapping_classes,f"the list of students with overlapping classes is incorrect (expected : {expected_students_with_overlapping_classes}, got : {response_data['students_with_overlapping_classes']})"

        # ensure that the db rows are correct 
        price_per_class = group.teacher_subject.price_per_class
        for student in students:
            group_enrollment = GroupEnrollment.objects.get(student=student, group=group)

            assert group_enrollment.attended_non_paid_classes == 4, f"the attended_non_paid_classes of the group_enrollment of the student {student.fullname} is incorrect (expected 4, got {group_enrollment.attended_non_paid_classes})"
            assert group_enrollment.unpaid_amount == 4 * group.teacher_subject.price_per_class, f"the unpaid_amount of the group_enrollment of the student {student.fullname} is incorrect (expected {4 * group.teacher_subject.price_per_class}, got {group_enrollment.unpaid_amount})"  # price_per_class is 20
            assert group_enrollment.paid_amount == price_per_class, f"the paid_amount of the group_enrollment of the student {student.fullname} is incorrect (expected 0, got {group_enrollment.paid_amount})"

            teacher_enrollment = TeacherEnrollment.objects.get(teacher=group.teacher, student=student)
            assert teacher_enrollment.unpaid_amount == 4 * group.teacher_subject.price_per_class, f"the unpaid_amount of the teacher_enrollment of the student {student.fullname} is incorrect (expected {4 * group.teacher_subject.price_per_class}, got {teacher_enrollment.unpaid_amount})"
            assert teacher_enrollment.paid_amount == price_per_class, f"the paid_amount of the teacher_enrollment of the student {student.fullname} is incorrect (expected 0, got {teacher_enrollment.paid_amount})"
        
        group.refresh_from_db()
        group.total_paid == 4 * price_per_class,f"the total paid of the group is incorrect, (expected {4 * price_per_class} got {group.total_paid})"
        print("\tTHE TEST OF MARKING ATTENDANCE AND PAYMENT WITH SCHEDULE CONFLICT PASSED SUCCESSFULLY.")

    def test(self):
        print("STARTING THE TEST OF THE MARK ATTENDANCE AND PAYMENT VIEW\n")
        self.test_mark_attendance_and_payment_without_schedule_conflict()
        self.test_mark_attendance_and_payment_with_schedule_conflict()
        print("\nTHE TEST OF THE MARK ATTENDANCE AND PAYMENT VIEW PASSED SUCCESSFULLY.\n")