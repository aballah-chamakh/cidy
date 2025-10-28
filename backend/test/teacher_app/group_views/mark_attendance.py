from account.models import User 
from teacher.models import Teacher,TeacherEnrollment, TeacherSubject,Level, Subject,Group, GroupEnrollment, Class
from student.models import Student
from teacher_app.TeacherClient import TeacherClient
import requests
import json
import  datetime


class TestMarkAttendance : 

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
        for i in range(3):
            student = Student.objects.create(
                fullname=f"student{i+1}",
                phone_number=f"0000000{i+1}",
                level = bac_tech,
                gender="M"
            )
            group_enrollment = GroupEnrollment.objects.create(student=student,group=group)
            TeacherEnrollment.objects.create(teacher=teacher,student=student)
    
        self.teacher_client = TeacherClient("teacher10@gmail.com", "iloveuu")

    def send_mark_attendance_request(self, group_id, student_ids, attendance_date, attendance_start_time, attendance_end_time):
        backend_url = f"{self.teacher_client.BACKEND_BASE_URL}/api/teacher/groups/{group_id}/students/mark_attendance/"

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
        }

        # Send the PUT request
        response = requests.put(backend_url, headers=headers, data=json.dumps(payload))
        return response

    def test_marking_attendance_without_schedule_conflict(self):
        # DB content : 3 students with no attended classes yet        

        print("\tSTARTING THE TEST OF MARKING ATTENDANCE WITHOUT SCHEDULE CONFLICT : ")
        group = Group.objects.first()
        student_ids = group.students.values_list('id', flat=True)
        price_per_class = group.teacher_subject.price_per_class
        for i in range(12):
            group = Group.objects.first()
            attendance_date = datetime.date.today()
            attendance_start_time = datetime.time(i + 8, 0)
            attendance_end_time = datetime.time(i + 9, 0)

            response = self.send_mark_attendance_request(
                group.id,
                student_ids,
                attendance_date,
                attendance_start_time,
                attendance_end_time
            )

            # ensure the response is correct
            assert response.status_code == 200, f"the status code of the {i+1} mark attendance is incorrect, expected 200 but got {response.status_code}"
            data = response.json()
            assert data['students_marked_count'] == len(student_ids), f"the number of students marked attendance is incorrect for the {i+1} mark attendance (expected {len(student_ids)}, got {data['students_marked_count']})"
            assert data['students_with_overlapping_classes'] == [], f"the list of students without enough classes to mark is incorrect for the {i+1} mark attendance (expected [], got {data['students_without_enough_classes_to_mark']})"

            print(f"\t\tAttendance marked successfully for the {i+1} time.")
            expected_due_payment_classes_count = (i + 1) // 4 * 4 # every 4 attended classes, 4 become due payment classes
            expected_unpaid_amount = expected_due_payment_classes_count * price_per_class
            for student_id in student_ids:
                student = Student.objects.get(id=student_id)
                group_enrollment = GroupEnrollment.objects.get(group=group, student=student)
                
                # check the attended_non_paid_classes in the group enrollment
                assert group_enrollment.attended_non_paid_classes == i + 1, f"the attended_non_paid_classes of the group_enrollment of the student {student.fullname} is incorrect"
                
                # check the unpaid amount in the group enrollment and teacher enrollment
                assert group_enrollment.unpaid_amount == expected_unpaid_amount, f"the unpaid amount of the group_enrollment of the student {student.fullname} is incorrect (expected {expected_unpaid_amount}, got {group_enrollment.unpaid_amount})"
                teacher_enrollment = TeacherEnrollment.objects.get(teacher=group.teacher, student=student)
                assert teacher_enrollment.unpaid_amount == expected_unpaid_amount, f"the unpaid amount of the teacher_enrollment of the student {student.fullname} is incorrect"
                
                # check the number of due payment classes and non due payment classes
                group_enrollment_classes = Class.objects.filter(group_enrollment=group_enrollment)
                assert group_enrollment_classes.filter(status='attended_and_the_payment_due').count() == expected_due_payment_classes_count, f"The number of due payment classes for the student {student.fullname} is incorrect (expected {expected_due_payment_classes_count}, got {group_enrollment_classes.filter(status='attended_and_the_payment_due').count()})"
                assert group_enrollment_classes.filter(status='attended_and_the_payment_not_due').count() == group_enrollment_classes.count() - expected_due_payment_classes_count, f"The number of non due payment classes for the student {student.fullname} is incorrect (expected {group_enrollment_classes.count() - expected_due_payment_classes_count}, got {group_enrollment_classes.filter(status='attended_and_the_payment_not_due').count()})"

            # check the total unpaid of the group
            group.total_unpaid == expected_unpaid_amount * len(student_ids) ,f"the total unpaid of the group is incorrect (expecteded : {expected_unpaid_amount * len(student_ids)}, got:{group.total_unpaid})"
        print("\tTHE TEST OF MARKING ATTENDANCE WITHOUT SCHEDULE CONFLICT PASSED SUCCESSFULLY.\n")
    
    def test_marking_attendance_with_schedule_conflict(self):
        # DB content : 3 students with 12 attended due payment classes each       
        print("\tSTARTING THE TEST OF MARKING ATTENDANCE WITH SCHEDULE CONFLICT : ")
        group = Group.objects.first()
        students = group.students.all().order_by('id')
        student_ids = [student.id for student in students]

        # delete the classes of the first student
        first_student = students.first()
        student_group_enrollment = GroupEnrollment.objects.get(student=first_student, group=group)
        Class.objects.filter(group_enrollment=student_group_enrollment).delete()

        # First, mark attendance for a specific date and time
        attendance_date = datetime.date.today()
        attendance_start_time = datetime.time(8, 0)
        attendance_end_time = datetime.time(9, 0)

        response = self.send_mark_attendance_request(
            group.id,
            student_ids,
            attendance_date,
            attendance_start_time,
            attendance_end_time
        )

        # ensure the response is correct
        assert response.status_code == 200, "expected to get 200 OK status code"
        data = response.json()
        assert data['students_marked_count'] == 1, "expected to mark attendance for only 1 student"
        expected_students_with_overlapping_classes = [
            {
                "id" : student.id,
                "image" : student.image.url,
                "fullname": student.fullname
            } for student in students.exclude(id=first_student.id)[::-1]
        ]
        assert data['students_with_overlapping_classes'] == expected_students_with_overlapping_classes, f"the list of students with overlapping classes is incorrect (expected {expected_students_with_overlapping_classes}, got {data['students_with_overlapping_classes']})"

        # ensure that the rows of the db are correct
        for student in students[1:] :
            group_enrollment = GroupEnrollment.objects.get(group=group, student=student)
            attended_classes = Class.objects.filter(
                group_enrollment=group_enrollment,
            )
            attended_classes_count = attended_classes.count()
            assert attended_classes_count == 12, f"the number of attended classes for the student {student.fullname} is incorrect (expected 12, got {attended_classes_count})"
        
        print("\tTHE TEST OF MARKING ATTENDANCE WITH SCHEDULE CONFLICT PASSED SUCCESSFULLY.\n")

    def test(self):
        print("START TESTTING THE MARK ATTENDANCE VIEW \n")

        self.test_marking_attendance_without_schedule_conflict()
        self.test_marking_attendance_with_schedule_conflict()

        print("\nTHE TEST OF THE MARK ATTENDANCE VIEW PASSED SUCCESSFULLY\n")

    
