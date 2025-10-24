from account.models import User 
from teacher.models import Teacher,TeacherEnrollment, TeacherSubject,Level, Subject,Group, GroupEnrollment, Class
from student.models import Student
from teacher_app.TeacherClient import TeacherClient
import requests
import json
from datetime import date, datetime, timedelta


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

        # Create a student and enroll him to the group
        for i in range(3):
            student = Student.objects.create(
                fullname=f"student{i+1}",
                email=f"student{i+1}@example.com",
                level = bac_tech,
                gender="M"
            )
            group_enrollment = GroupEnrollment.objects.create(student=student,group=group)
            TeacherEnrollment.objects.create(teacher=teacher,student=student)
    
        self.teacher_client = TeacherClient("teacher10@gmail.com", "iloveuu")

    def send_mark_attendance_request(self, group_id, student_ids, attendance_date, attendance_start_time, attendance_end_time):
        # Example variables (replace them with your actual values)
        backend_url = f"{self.teacher_client.BACKEND_BASE_URL}/api/teacher/groups/{group_id}/students/mark_attendance/"

        # Prepare the headers
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.teacher_client.access_token}",
        }

        # Prepare the payload
        payload = {
            "student_ids": list(student_ids),
            "date": attendance_date,
            "start_time": attendance_start_time,
            "end_time": attendance_end_time,
        }

        # Send the PUT request
        response = requests.put(backend_url, headers=headers, data=json.dumps(payload))
        return response

    def test_marking_attendance_without_schedule_conflict(self):
        print("START MARKING ATTENDANCE WITHOUT SCHEDULE CONFLICT : ")
        group = Group.objects.first()
        student_ids = group.students.values_list('id', flat=True)
        price_per_class = group.teacher_subject.price_per_class
        for i in range(12):
            attendance_date = date.today()
            attendance_start_time = datetime.time(i + 8, 0)
            attendance_end_time = datetime.time(i + 9, 0)

            response = self.send_mark_attendance_request(
                group.id,
                student_ids,
                attendance_date,
                attendance_start_time,
                attendance_end_time
            )

            assert response.status_code == 200, f"Failed to the {i+1} mark attendance"

            expected_unpaid_amout = (i + 1) // 4 * price_per_class
            for student_id in student_ids:
                student = Student.objects.get(id=student_id)
                group_enrollment = GroupEnrollment.objects.get(group=group, student=student)
                
                assert group_enrollment.attended_non_paid_classes == i + 1, f"the attended_non_paid_classes of the group_enrollment of the student {student.fullname} is incorrect"
                assert group_enrollment.unpaid_amount == expected_unpaid_amout, f"the unpaid amount of the group_enrollment of the student {student.fullname} is incorrect"
                teacher_enrollment = TeacherEnrollment.objects.get(teacher=group.teacher, student=student)
                assert teacher_enrollment.unpaid_amount == expected_unpaid_amout, f"the unpaid amount of the teacher_enrollment of the student {student.fullname} is incorrect"

                latest_class = Class.objects.filter(group_enrollment=group_enrollment).latest('id')
                assert latest_class.attendance_date == attendance_date, "Attendance date mismatch"
                assert latest_class.status == 'attended_and_the_payment_due', "Attendance status mismatch"

