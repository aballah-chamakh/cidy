from account.models import User 
from teacher.models import Teacher,TeacherEnrollment, TeacherSubject,Level, Subject,Group, GroupEnrollment, Class
from student.models import Student
from teacher_app.TeacherClient import TeacherClient
import requests
import json
import  datetime


class TestUnMarkAbsence : 

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
        self.group = Group.objects.create(teacher=teacher,name="Groupe A",teacher_subject=teacher_subject,week_day="Monday",start_time="10:00",end_time="12:00")    

        # Create 5 students and enroll them to the group
        # the first two students will have 10 absent classes each
        # the other students will have 5 absent classes each
        for i in range(5):
            
            student = Student.objects.create(
                fullname=f"student{i+1}",
                phone_number=f"0000000{i+1}",
                level = bac_tech,
                gender="M"
            )
            group_enrollment = GroupEnrollment.objects.create(student=student,group=self.group)
            TeacherEnrollment.objects.create(teacher=teacher,student=student)
            if i < 2 :
                # create 10 absent classes for the first two students
                for j in range(10):
                    Class.objects.create(
                        group_enrollment=group_enrollment,
                        absence_date = datetime.date.today() - datetime.timedelta(days=j),
                        absence_start_time = datetime.time(8+j,0),
                        absence_end_time = datetime.time(9+j,0),
                        status = 'absent'
                    )
            else : 
                # create 5 absent classes for the other students
                for j in range(5):
                    Class.objects.create(
                        group_enrollment=group_enrollment,
                        absence_date = datetime.date.today() - datetime.timedelta(days=j),
                        absence_start_time = datetime.time(8+j,0),
                        absence_end_time = datetime.time(9+j,0),
                        status = 'absent'
                    )
    
        self.teacher_client = TeacherClient("teacher10@gmail.com", "iloveuu")

    def send_unmark_absence_request(self, number_of_classes, student_ids):
        backend_url = f"{self.teacher_client.BACKEND_BASE_URL}/api/teacher/groups/{self.group.id}/students/unmark_absence/"

        # Prepare the headers
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.teacher_client.access_token}",
        }

        # Prepare the payload
        payload = {
            "student_ids": student_ids,
            "number_of_classes": number_of_classes
        }

        # Send the PUT request
        response = requests.put(backend_url, headers=headers, data=json.dumps(payload))
        return response

    def test_unmarking_absence_without_an_overflow(self):
        # DB content : 5 students,the first two students have 10 absent classes each, the other students have 5 absent classes each
        print("\tSTARTING THE TEST OF UNMARKING ABSENCE WITHOUT AN OVERFLOW : ")
        students = Student.objects.all().order_by('id')
        student_ids = [ student.id for student in students ]
        

        # ensure that the response is correct
        response = self.send_unmark_absence_request(5,student_ids)
        assert response.status_code == 200, f"expect 200 but got {response.status_code} for unmark absence"
        print(f"\t\tAbsence unmarked successfully.")
        data = response.json()
        assert data['students_unmarked_completely_count'] == len(student_ids), f"the number of students unmarked absent is incorrect (expected {len(student_ids)}, got {data['students_unmarked_count']})"
        assert data['students_without_enough_absent_classes_to_unmark'] == [], f"the list of students without enough absent classes to unmark is incorrect (expected [], got {data['students_without_enough_absent_classes_to_unmark']})"
        
        # ensure that the rows of the db are correct
        group = Group.objects.first()
        for idx,student in enumerate(students) :
            group_enrollment = GroupEnrollment.objects.get(student=student,group=group)
            absent_classes = Class.objects.filter(group_enrollment=group_enrollment,status='absent')
            absent_classe_count = absent_classes.count()
            if idx < 2 :
                # first two students should have 5 absent classes left
                assert absent_classe_count == 5, f"the number of absent classes for student {student.fullname} is incorrect (expected 5, got {absent_classe_count})"
            else :
                # other students should have 0 absent classes left
                assert absent_classe_count == 0, f"the number of absent classes for student {student.fullname} is incorrect (expected 0, got {absent_classe_count})"
        print("\tTHE TEST OF UNMARKING ABSENCE WITHOUT AN OVERFLOW PASSED SUCCESSFULLY.\n")

    def test_unmarking_absence_with_an_overflow(self):
        # DB content : 5 students, the first two students have 5 absent classes each, the other students have 0 absent classes each
        print("\tSTARTING THE TEST OF UNMARKING ABSENCE WITH AN OVERFLOW : ")
        students = Student.objects.all().order_by('id')
        student_ids = [ student.id for student in students ]
        

        # ensure that the response is correct
        response = self.send_unmark_absence_request(5,student_ids)
        assert response.status_code == 200, f"expect 200 but got {response.status_code} for unmark absence"
        print(f"\t\tAbsence unmarked successfully.")
        data = response.json()
        assert data['students_unmarked_completely_count'] == 2, f"the number of students unmarked absent is incorrect (expected 2, got {data['students_unmarked_completely_count']})"
        assert data['students_without_enough_absent_classes_to_unmark'] == [
            {
             'id': student.id,
             'image': student.image.url,
             'fullname': student.fullname,
             'missing_number_of_classes' : 5
            }
            for student in students[2:][::-1]
        ], f"the list of students without enough absent classes to unmark is incorrect (expected [], got {data['students_without_enough_absent_classes_to_unmark']})"
        
        # ensure that the rows of the db are correct
        group = Group.objects.first()
        for idx,student in enumerate(students) :
            group_enrollment = GroupEnrollment.objects.get(student=student,group=group)
            absent_classes = Class.objects.filter(group_enrollment=group_enrollment,status='absent')
            absent_classe_count = absent_classes.count()
            assert absent_classe_count == 0, f"the number of absent classes for student {student.fullname} is incorrect (expected 0, got {absent_classe_count})"
        print("\tTHE TEST OF UNMARKING ABSENCE WITH AN OVERFLOW PASSED SUCCESSFULLY.\n")


    def test(self):
        print("START TESTTING THE UNMARK ABSENCE VIEW \n")

        self.test_unmarking_absence_without_an_overflow()
        self.test_unmarking_absence_with_an_overflow()

        print("\nTHE TEST OF THE UNMARK ABSENCE VIEW PASSED SUCCESSFULLY\n")

    
