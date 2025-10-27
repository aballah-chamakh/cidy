from account.models import User 
from teacher.models import Teacher,TeacherEnrollment, TeacherSubject,Level, Subject,Group, GroupEnrollment, Class
from student.models import Student
from teacher_app.TeacherClient import TeacherClient
import requests
import json
import  datetime


class TestMarkAbsence : 

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
        for i in range(5):
            student = Student.objects.create(
                fullname=f"student{i+1}",
                phone_number=f"0000000{i+1}",
                level = bac_tech,
                gender="M"
            )
            group_enrollment = GroupEnrollment.objects.create(student=student,group=group)
            TeacherEnrollment.objects.create(teacher=teacher,student=student)
    
        self.teacher_client = TeacherClient("teacher10@gmail.com", "iloveuu")

    def send_mark_absence_request(self, group_id, student_ids, absence_date, absence_start_time, absence_end_time):
        # Example variables (replace them with your actual values)
        backend_url = f"{self.teacher_client.BACKEND_BASE_URL}/api/teacher/groups/{group_id}/students/mark_absence/"

        # Prepare the headers
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.teacher_client.access_token}",
        }

        # Prepare the payload
        payload = {
            "student_ids": list(student_ids),
            "date": absence_date.strftime("%d/%m/%Y"),
            "start_time": absence_start_time.strftime("%H:%M"),
            "end_time": absence_end_time.strftime("%H:%M"),
        }

        # Send the PUT request
        response = requests.put(backend_url, headers=headers, data=json.dumps(payload))
        return response

    def test_marking_absence_without_schedule_conflict(self):
        print("\tSTARTING THE TEST OF MARKING ABSENCE WITHOUT SCHEDULE CONFLICT : ")
        group = Group.objects.first()
        student_ids = group.students.order_by('id').values_list('id', flat=True)[:3]
        for i in range(3):
            group = Group.objects.first()
            absence_date = datetime.date.today()
            absence_start_time = datetime.time(i + 8, 0)
            absence_end_time = datetime.time(i + 9, 0)

            response = self.send_mark_absence_request(
                group.id,
                student_ids,
                absence_date,
                absence_start_time,
                absence_end_time
            )

            assert response.status_code == 200, f"expect 200 but got {response.status_code} for the {i+1} mark absence"
            print(f"\t\tAbsence marked successfully for the {i+1} time.")
            # ensure that the response data is correct
            data = response.json()
            assert data['students_marked_count'] == len(student_ids), f"the number of students marked absent is incorrect (expected {len(student_ids)}, got {data['students_marked_count']})"
            assert data['students_with_overlapping_classes'] == [], "the students with overlapping classes is incorrect, expected [], got {data['students_with_overlapping_classes']}"
            
            # ensure for the 3 students that  an absence class was created for them 
            for student_id in student_ids:
                student = Student.objects.get(id=student_id)
                group_enrollment = GroupEnrollment.objects.get(group=group, student=student)
                absent_classes = Class.objects.filter(
                    group_enrollment=group_enrollment,
                    status = 'absent',
                )
                absent_classes_count = absent_classes.count()
                assert absent_classes.count() == i + 1, f"the number of absent classes for the student {student.fullname} is incorrect (expected {i + 1}, got {absent_classes_count})"

        print("\tTHE TEST OF MARKING ABSENCE WITHOUT SCHEDULE CONFLICT PASSED SUCCESSFULLY.\n")

    def test_marking_absence_with_schedule_conflict(self):
        print("\tSTARTING THE TEST OF MARKING ABSENCE WITH SCHEDULE CONFLICT : ")
        group = Group.objects.first()
        students = group.students.all().order_by('id')
        student_ids = [student.id for student in students]


        #mark the absence with a schedule conflict for the 3 first students
        attendance_date = datetime.date.today()
        attendance_start_time = datetime.time(8, 0)
        attendance_end_time = datetime.time(9, 0)

        response = self.send_mark_absence_request(
            group.id,
            student_ids,
            attendance_date,
            attendance_start_time,
            attendance_end_time
        )

        assert response.status_code == 200, "expected to get 200 OK status code"

        data = response.json()
        # ensure the response data is correct
        assert data['students_marked_count'] == 2, f"expected 2 students to be marked absent but got {data['students_marked_count']}"
        expected_overlapping_students = [
            {
                "id" : student.id,
                "image" : student.image.url,
                "fullname": student.fullname
            } for student in students[:3]
        ]
        assert data['students_with_overlapping_classes'] == expected_overlapping_students.reverse(), f"the expected overlapping students list is incorrect, expected : {expected_overlapping_students}, got : {data['students_with_overlapping_classes']}"
        
        ## ensure that rows in the db are correct
        for idx, student in enumerate(students, start=1):
            group_enrollment = GroupEnrollment.objects.get(group=group, student=student)
            absent_classes = Class.objects.filter(
                group_enrollment=group_enrollment,
                status = 'absent',
            )
            absent_classes_count = absent_classes.count()
            if idx <=3 :
                assert absent_classes.count() == 3, f"the number of absent classes for the student {student.fullname} is incorrect (expected 3, got {absent_classes_count})"
            else :
                assert absent_classes.count() == 1, f"the number of absent classes for the student {student.fullname} is incorrect (expected 1, got {absent_classes_count})"

        print("\tTHE TEST OF MARKING ABSENCE WITH SCHEDULE CONFLICT PASSED SUCCESSFULLY.\n")

    def test(self):
        print("START TESTTING THE MARK ABSENCE VIEW \n")

        self.test_marking_absence_without_schedule_conflict()
        self.test_marking_absence_with_schedule_conflict()

        print("\nTHE TEST OF THE MARKING ABSENCE VIEW PASSES SUCCESSFULLY\n")

    
