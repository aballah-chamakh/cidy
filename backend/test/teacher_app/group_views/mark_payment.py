from account.models import User 
from teacher.models import Teacher,TeacherEnrollment, TeacherSubject,Level, Subject,Group, GroupEnrollment, Class
from student.models import Student
from teacher_app.TeacherClient import TeacherClient
import requests
import json
import  datetime


class TestMarkPayment : 

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
            teacher_enrollment = TeacherEnrollment.objects.create(teacher=teacher,student=student)
            # create 10 attended classes for each student (8 due payment and 2 not due payment)
            for i in range(10):
                Class.objects.create(
                    group_enrollment=group_enrollment,
                    attendance_date=datetime.date.today(),
                    attendance_start_time=datetime.time(8 + i, 0),
                    attendance_end_time=datetime.time(9 + i, 0),
                    status='attended_and_the_payment_due' if i < 8 else 'attended_and_the_payment_not_due'
                )
            group_enrollment.attended_non_paid_classes = 10
            group_enrollment.unpaid_amount =  8 * teacher_subject.price_per_class
            group_enrollment.save()
            teacher_enrollment.unpaid_amount = 8 * teacher_subject.price_per_class
            teacher_enrollment.save()
        group.total_unpaid = 3 * 8 * teacher_subject.price_per_class
        group.save()
        
        self.teacher_client = TeacherClient("teacher10@gmail.com", "iloveuu")

    def send_mark_payment_request(self, group_id, student_ids, payment_datetime,number_of_classes):
        backend_url = f"{self.teacher_client.BACKEND_BASE_URL}/api/teacher/groups/{group_id}/students/mark_payment/"

        # Prepare the headers
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.teacher_client.access_token}",
        }

        # Prepare the payload
        payload = {
            "student_ids": list(student_ids),
            "number_of_classes" : number_of_classes,
            "payment_datetime": payment_datetime.strftime("%H:%M:%S-%d/%m/%Y"),
        }

        # Send the PUT request
        response = requests.put(backend_url, headers=headers, data=json.dumps(payload))
        return response

    def test_marking_payment_without_missing_classes(self):
        # DB content : 3 students with no attended classes yet        

        print("\tSTARTING THE TEST OF MARKING PAYMENT WITHOUT MISSING CLASSES CONFLICT : ")
        group = Group.objects.first()
        student_ids = group.students.values_list('id', flat=True)
        price_per_class = group.teacher_subject.price_per_class
        for i in range(5):
            group = Group.objects.first()
            payment_datetime = datetime.datetime.now()
            number_of_classes = 2

            response = self.send_mark_payment_request(
                group.id,
                student_ids,
                payment_datetime,
                number_of_classes
            )

            # ensure the response is correct
            assert response.status_code == 200, f"the status code of the {i+1} mark payment is incorrect, expected 200 but got {response.status_code}"
            data = response.json()
            assert data['students_marked_completely_count'] == len(student_ids), f"the number of students marked completely is incorrect for the {i+1} mark payment (expected {len(student_ids)}, got {data['students_marked_completely_count']})"
            assert data['students_without_enough_classes_to_mark_their_payment'] == [], f"the list of students without enough classes to mark their payment is incorrect for the {i+1} mark payment (expected [], got {data['students_without_enough_classes_to_mark_their_payment']})"

            print(f"\t\tPayment marked successfully for the {i+1} time.")
            expected_classes_marked_as_paid_count = (i + 1) * number_of_classes
            expected_attended_non_paid_classes = 10 - expected_classes_marked_as_paid_count
            expected_non_due_payment_classes_count = expected_attended_non_paid_classes % 4   # every 4 attended classes, 4 become due payment classes
            expected_due_payment_classes_count = expected_attended_non_paid_classes - expected_non_due_payment_classes_count   # every 4 attended classes, 4 become due payment classes

            expected_unpaid_amount = expected_due_payment_classes_count * price_per_class
            
            
            for student_id in student_ids:
                
                student = Student.objects.get(id=student_id)
                print(f"\t\tChecking the student {student.fullname} after the {i+1} mark payment:")
                group_enrollment = GroupEnrollment.objects.get(group=group, student=student)
                
                # check the attended_non_paid_classes in the group enrollment
                assert group_enrollment.attended_non_paid_classes == expected_attended_non_paid_classes, f"in the {i+1} mark payment, the attended_non_paid_classes of the group_enrollment of the student {student.fullname} is incorrect (expected {expected_attended_non_paid_classes}, got {group_enrollment.attended_non_paid_classes})"
                
                # check the unpaid amount in the group enrollment and teacher enrollment
                assert group_enrollment.unpaid_amount == expected_unpaid_amount, f"in the {i+1} mark payment, the unpaid amount of the group_enrollment of the student {student.fullname} is incorrect (expected {expected_unpaid_amount}, got {group_enrollment.unpaid_amount})"
                teacher_enrollment = TeacherEnrollment.objects.get(teacher=group.teacher, student=student)
                assert teacher_enrollment.unpaid_amount == expected_unpaid_amount, f"in the {i+1} mark payment, the unpaid amount of the teacher_enrollment of the student {student.fullname} is incorrect (expected {expected_unpaid_amount}, got {teacher_enrollment.unpaid_amount})"
                
                # check the number of due payment classes and non due payment classes
                group_enrollment_classes = Class.objects.filter(group_enrollment=group_enrollment,status__in=['attended_and_paid','attended_and_the_payment_due', 'attended_and_the_payment_not_due']).order_by('attendance_date','attendance_start_time','id')
                for idx, klass in enumerate( group_enrollment_classes, start=1):
                    if idx <= expected_classes_marked_as_paid_count :
                        assert klass.status == 'attended_and_paid', f"in the {i+1} mark payment, The status of the class at index {idx} for the student {student.fullname} is incorrect (expected 'attended_and_paid', got {klass.status})"
                    elif idx <= (expected_classes_marked_as_paid_count + expected_due_payment_classes_count):
                        assert klass.status == 'attended_and_the_payment_due', f"in the {i+1} mark payment, The status of the class at index {idx} for the student {student.fullname} is incorrect (expected 'attended_and_the_payment_due', got {klass.status})"
                    else:
                        assert klass.status == 'attended_and_the_payment_not_due', f"in the {i+1} mark payment, The status of the class at index {idx} for the student {student.fullname} is incorrect (expected 'attended_and_the_payment_not_due', got {klass.status})"

            # check the total unpaid of the group
            group.total_unpaid == expected_unpaid_amount * len(student_ids) ,f"in the {i+1} mark payment, the total unpaid of the group is incorrect (expecteded : {expected_unpaid_amount * len(student_ids)}, got:{group.total_unpaid})"
        print("\tTHE TEST OF MARKING PAYMENT WITHOUT MISSING CLASSES PASSED SUCCESSFULLY.\n")
    
    def test_marking_payment_with_missing_classes(self):
        # DB content : 
        #  - first student has 16 attended classes (all due payment)
        #  - the other 2 students have 6 attended classes (4 due payment and 2 not due payment)

        print("\tSTARTING THE TEST OF MARKING PAYMENT WITH MISSING CLASSES")
        students = Student.objects.all().order_by('id')
        first_student = students.first()
        group = Group.objects.first()
        for student in students:
            group_enrollment = GroupEnrollment.objects.get(student=student,group=group)
            teacher_enrollment = TeacherEnrollment.objects.get(student=student,teacher=group.teacher)
            attended_classes = Class.objects.filter(group_enrollment=group_enrollment).order_by('attendance_date','attendance_start_time','id')
            for idx, klass in enumerate(attended_classes, start=1):
                if student.id == first_student.id : 
                    if idx <= 8:
                        klass.status = 'attended_and_the_payment_due'
                        klass.save()
                    else:
                        klass.status = 'attended_and_the_payment_not_due'
                        klass.save()
                else:
                    if idx <= 4:
                        klass.status = 'attended_and_the_payment_due'
                        klass.save()
                    elif idx <= 6:
                        klass.status = 'attended_and_the_payment_not_due'
                        klass.save()
                    else : 
                        klass.delete()

            group_enrollment.attended_non_paid_classes = 6 if student.id != first_student.id else 10
            group_enrollment.unpaid_amount = 4 * group.teacher_subject.price_per_class if student.id != first_student.id else 8 * group.teacher_subject.price_per_class
            teacher_enrollment.unpaid_amount = 4 * group.teacher_subject.price_per_class if student.id != first_student.id else 8 * group.teacher_subject.price_per_class
            group_enrollment.save()
            teacher_enrollment.save()
        group.total_unpaid = len(students[1:]) * 4 * group.teacher_subject.price_per_class + 8 * group.teacher_subject.price_per_class
        group.save()

        payment_datetime = datetime.datetime.now()
        number_of_classes = 10
        student_ids = [student.id for student in students]
        response = self.send_mark_payment_request(
            group.id,
            student_ids,
            payment_datetime,
            number_of_classes
        )
    
        # ensure the response is correct
        assert response.status_code == 200, f"the status code of the mark payment with missing classes is incorrect, expected 200 but got {response.status_code}"
        data = response.json()
        assert data['students_marked_completely_count'] == 1, f"the number of students marked completely is incorrect for the mark payment with missing classes (expected 1, got {data['students_marked_completely_count']})"
        assert len(data['students_without_enough_classes_to_mark_their_payment']) == 2, f"the list of students without enough classes to mark their payment is incorrect for the mark payment with missing classes (expected 2, got {len(data['students_without_enough_classes_to_mark_their_payment'])})"
        expected_students_without_enough_classes_to_mark_their_payment = [
            {
                'id': student.id,
                'image' : student.image.url,
                'fullname': student.fullname,
                'missing_number_of_classes': 4
            } for student in students[1:][::-1]
        ]
        assert data['students_without_enough_classes_to_mark_their_payment'] == expected_students_without_enough_classes_to_mark_their_payment, f"the list of students without enough classes to mark their payment is incorrect for the mark payment with missing classes (expected {expected_students_without_enough_classes_to_mark_their_payment}, got {data['students_without_enough_classes_to_mark_their_payment']})"
        

        

        print("\tSTARTING THE TEST OF MARKING PAYMENT WITH MISSING CLASSES")



            
        

    def test(self):
        print("START TESTTING THE MARK PAYMENT VIEW \n")

        self.test_marking_payment_without_missing_classes()
        self.test_marking_payment_with_missing_classes()

        print("\nTHE TEST OF THE MARK PAYMENT VIEW PASSED SUCCESSFULLY\n")

    
