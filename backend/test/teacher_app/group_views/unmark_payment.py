from account.models import User 
from teacher.models import Teacher,TeacherEnrollment, TeacherSubject,Level, Subject,Group, GroupEnrollment, Class
from student.models import Student
from teacher_app.TeacherClient import TeacherClient
import requests
import json
import  datetime


class TestUnMarkPayment : 

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
            # create 14 attended classes for each student (8 due payment and 6 not due payment)
            for i in range(14):
                # create the first 10 classes as paid 
                if i <= 9 :
                    Class.objects.create(
                        group_enrollment=group_enrollment,
                        attendance_date=datetime.date.today(),
                        attendance_start_time=datetime.time(8 + i, 0),
                        attendance_end_time=datetime.time(9 + i, 0),
                        status='attended_and_paid'
                    )
                # create the next 2 classes as attended_and_the_payment_not_due
                elif i <= 11 :
                    Class.objects.create(
                        group_enrollment=group_enrollment,
                        attendance_date=datetime.date.today(),
                        attendance_start_time=datetime.time(8 + i, 0),
                        attendance_end_time=datetime.time(9 + i, 0),
                        status='attended_and_the_payment_not_due'
                    )
                # create the last 2 classes as paid
                else : 
                    Class.objects.create(
                        group_enrollment=group_enrollment,
                        attendance_date=datetime.date.today(),
                        attendance_start_time=datetime.time(8 + i, 0),
                        attendance_end_time=datetime.time(9 + i, 0),
                        status='attended_and_paid'
                    )
                
            paid_amount = 12 * teacher_subject.price_per_class
            group_enrollment.paid_amount = paid_amount
            group_enrollment.attended_non_paid_classes = 2 
            group_enrollment.save()
            teacher_enrollment.paid_amount = paid_amount
            teacher_enrollment.save()
        group.total_unpaid = 3 * paid_amount
        group.save()
        
        self.teacher_client = TeacherClient("teacher10@gmail.com", "iloveuu")

    def send_unmark_payment_request(self, group_id, student_ids,number_of_classes):
        backend_url = f"{self.teacher_client.BACKEND_BASE_URL}/api/teacher/groups/{group_id}/students/unmark_payment/"

        # Prepare the headers
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.teacher_client.access_token}",
        }

        # Prepare the payload
        payload = {
            "student_ids": list(student_ids),
            "number_of_classes" : number_of_classes,
        }

        # Send the PUT request
        response = requests.put(backend_url, headers=headers, data=json.dumps(payload))
        return response

    def test_unmarking_payment_without_missing_classes(self):
        # DB content : 3 students with 10 paid classes each 
        # test : unmark payment 5 times, each time for 2 classes     

        print("\tSTARTING THE TEST OF UNMARKING PAYMENT WITHOUT HAVING MISSING PAID CLASSES : ")
        group = Group.objects.first()
        student_ids = group.students.values_list('id', flat=True)
        price_per_class = group.teacher_subject.price_per_class
        for i in range(6):
            number_of_classes = 2

            response = self.send_unmark_payment_request(
                group.id,
                student_ids,
                number_of_classes
            )

            # ensure the response is correct
            assert response.status_code == 200, f"the status code of the {i+1} mark payment is incorrect, expected 200 but got {response.status_code}"
            data = response.json()
            assert data['students_unmarked_completely_count'] == len(student_ids), f"the number of students unmarked completely is incorrect for the {i+1} unmark payment (expected {len(student_ids)}, got {data['students_unmarked_completely_count']})"
            assert data['students_without_enough_paid_classes_to_unmark'] == [], f"the list of students without enough classes to unmark their payment is incorrect for the {i+1} unmark payment (expected [], got {data['students_without_enough_paid_classes_to_unmark']})"

            # ensure that the rows of the db are correct
            print(f"\t\tPayment marked successfully for the {i+1} time.")
            expected_unmarked_classes_count = (i + 1) * number_of_classes + 2 
            expected_non_due_payment_classes_count = expected_unmarked_classes_count  % 4   # every 4 attended classes, 4 become due payment classes
            expected_due_payment_classes_count = expected_unmarked_classes_count - expected_non_due_payment_classes_count   # every 4 attended classes, 4 become due payment classes
            expected_classes_marked_as_paid_count = 14 - expected_unmarked_classes_count
            expected_unpaid_amount = expected_due_payment_classes_count * price_per_class
            expected_paid_mount = expected_classes_marked_as_paid_count * price_per_class
            
            for student_id in student_ids:
                
                student = Student.objects.get(id=student_id)
                print(f"\t\tChecking the student {student.fullname} after the {i+1} mark payment:")
                group_enrollment = GroupEnrollment.objects.get(group=group, student=student)
                teacher_enrollment = TeacherEnrollment.objects.get(teacher=group.teacher, student=student)

                # check the attended_non_paid_classes in the group enrollment
                assert group_enrollment.attended_non_paid_classes == expected_unmarked_classes_count, f"in the {i+1} unmark payment, the attended_non_paid_classes of the group_enrollment of the student {student.fullname} is incorrect (expected {expected_unmarked_classes_count}, got {group_enrollment.attended_non_paid_classes})"
                
                # check the unpaid amount in the group enrollment and teacher enrollment
                assert group_enrollment.unpaid_amount == expected_unpaid_amount, f"in the {i+1} unmark payment, the unpaid amount of the group_enrollment of the student {student.fullname} is incorrect (expected {expected_unpaid_amount}, got {group_enrollment.unpaid_amount})"
                assert teacher_enrollment.unpaid_amount == expected_unpaid_amount, f"in the {i+1} unmark payment, the unpaid amount of the teacher_enrollment of the student {student.fullname} is incorrect (expected {expected_unpaid_amount}, got {teacher_enrollment.unpaid_amount})"

                # check the paid amount in the group enrollment and teacher enrollment
                assert group_enrollment.paid_amount == expected_paid_mount, f"in the {i+1} unmark payment, the paid amount of the group_enrollment of the student {student.fullname} is incorrect (expected {expected_paid_mount}, got {group_enrollment.paid_amount})"
                assert teacher_enrollment.paid_amount == expected_paid_mount, f"in the {i+1} unmark payment, the paid amount of the teacher_enrollment of the student {student.fullname} is incorrect (expected {expected_paid_mount}, got {teacher_enrollment.paid_amount})"
                
                group_enrollment_classes = Class.objects.filter(group_enrollment=group_enrollment,status__in=['attended_and_paid','attended_and_the_payment_due', 'attended_and_the_payment_not_due']).order_by('attendance_date','attendance_start_time','id')
                
                # check the number of paid, due payment and non due payment classes is correct 
                assert group_enrollment_classes.filter(status='attended_and_paid').count() == expected_classes_marked_as_paid_count, f"in the {i+1} unmark payment, the number of paid classes for the student {student.fullname} is incorrect (expected {expected_classes_marked_as_paid_count}, got {group_enrollment_classes.filter(status='attended_and_paid').count()})"
                assert group_enrollment_classes.filter(status='attended_and_the_payment_due').count() == expected_due_payment_classes_count, f"in the {i+1} unmark payment, the number of due payment classes for the student {student.fullname} is incorrect (expected {expected_due_payment_classes_count}, got {group_enrollment_classes.filter(status='attended_and_the_payment_due').count()})"
                assert group_enrollment_classes.filter(status='attended_and_the_payment_not_due').count() == expected_non_due_payment_classes_count, f"in the {i+1} unmark payment, the number of non due payment classes for the student {student.fullname} is incorrect (expected {expected_non_due_payment_classes_count}, got {group_enrollment_classes.filter(status='attended_and_the_payment_not_due').count()})"
                
                # check if the orders of paid, due payment and non due payment classes is correct 
                for idx, klass in enumerate( group_enrollment_classes, start=1):
                    print(f"{idx} - {klass.status}")
                    if idx <= expected_classes_marked_as_paid_count :
                        assert klass.status == 'attended_and_paid', f"in the {i+1} unmark payment, The status of the class at index {idx} for the student {student.fullname} is incorrect (expected 'attended_and_paid', got {klass.status})"
                    elif idx <= (expected_classes_marked_as_paid_count + expected_due_payment_classes_count):
                        assert klass.status == 'attended_and_the_payment_due', f"in the {i+1} unmark payment, The status of the class at index {idx} for the student {student.fullname} is incorrect (expected 'attended_and_the_payment_due', got {klass.status})"
                    else:
                        assert klass.status == 'attended_and_the_payment_not_due', f"in the {i+1} unmark payment, The status of the class at index {idx} for the student {student.fullname} is incorrect (expected 'attended_and_the_payment_not_due', got {klass.status})"

            # check the total unpaid of the group
            group.refresh_from_db()
            group.total_unpaid == expected_unpaid_amount * len(student_ids) ,f"in the {i+1} unmark payment, the total unpaid of the group is incorrect (expecteded : {expected_unpaid_amount * len(student_ids)}, got:{group.total_unpaid})"
            group.total_paid == expected_paid_mount * len(student_ids) ,f"in the {i+1} unmark payment, the total paid of the group is incorrect (expecteded : {expected_paid_mount * len(student_ids)}, got:{group.total_paid})"   
        print("\tTHE TEST OF MARKING PAYMENT WITHOUT MISSING CLASSES PASSED SUCCESSFULLY.\n")
    
    def test_unmarking_payment_with_missing_classes(self):
        # DB content : 
        #  - first student has the first 10 classes as paid, the next 2 classes as not due payment and the last 2 classes as paid
        #  - the other 2 students have the first 3 classes as paid, the next 2 classes as not due payment and the last 2 classes as paid
        # test : unmark payment for 12 classes for all students
        print("\tSTARTING THE TEST OF UNMARKING PAYMENT WITH MISSING CLASSES")
        students = Student.objects.all().order_by('id')
        first_student = students.first()
        group = Group.objects.first()
        for student in students:
            group_enrollment = GroupEnrollment.objects.get(student=student,group=group)
            teacher_enrollment = TeacherEnrollment.objects.get(student=student,teacher=group.teacher)
            attended_classes = Class.objects.filter(group_enrollment=group_enrollment).order_by('attendance_date','attendance_start_time','id')
            if student.id == first_student.id :
                for K_idx, klass in enumerate(attended_classes, start=1):
                    if K_idx <= 10:
                        klass.status = 'attended_and_paid'
                    elif K_idx <= 12 :
                        klass.status = 'attended_and_the_payment_not_due'
                    else : 
                        klass.status = 'attended_and_paid'
                    klass.save()
                paid_amount = 12 * group.teacher_subject.price_per_class
                group_enrollment.paid_amount = paid_amount
                teacher_enrollment.paid_amount = paid_amount
            else : 
                for K_idx, klass in enumerate(attended_classes, start=1):
                    if K_idx <= 3 :
                        klass.status = 'attended_and_paid'
                        klass.save()
                    elif K_idx <= 5 :
                        klass.status = 'attended_and_the_payment_not_due'
                        klass.save()
                    elif K_idx <= 7 :
                        klass.status = 'attended_and_paid'
                        klass.save()
                    else : 
                        klass.delete()
                paid_amount = 5 * group.teacher_subject.price_per_class
                group_enrollment.paid_amount = paid_amount
                teacher_enrollment.paid_amount = paid_amount


            group_enrollment.attended_non_paid_classes = 2
            group_enrollment.unpaid_amount = 0  
            teacher_enrollment.unpaid_amount = 0
                    
            group_enrollment.save()
            teacher_enrollment.save()
        group.total_paid = 2 * 5 * group.teacher_subject.price_per_class + 12 * group.teacher_subject.price_per_class
        group.total_unpaid = 0
        group.save()

        number_of_classes = 12
        student_ids = [student.id for student in students]
        response = self.send_unmark_payment_request(
            group.id,
            student_ids,
            number_of_classes
        )
    
        # ensure the response is correct
        assert response.status_code == 200, f"the status code of the unmark payment with missing classes is incorrect, expected 200 but got {response.status_code}"
        data = response.json()
        assert data['students_unmarked_completely_count'] == 1, f"the number of students unmarked completely is incorrect for the unmark payment with missing classes (expected 1, got {data['students_marked_completely_count']})"
        assert len(data['students_without_enough_paid_classes_to_unmark']) == 2, f"the list of students without enough classes to unmark their payment is incorrect for the unmark payment with missing classes (expected 2, got {len(data['students_without_enough_paid_classes_to_unmark'])})"
        expected_students_without_enough_classes_to_unmark_their_payment = [
            {
                'id': student.id,
                'image' : student.image.url,
                'fullname': student.fullname,
                'missing_number_of_classes': 7
            } for student in students[1:][::-1]
        ]
        assert data['students_without_enough_paid_classes_to_unmark'] == expected_students_without_enough_classes_to_unmark_their_payment, f"the list of students without enough classes to mark their payment is incorrect for the mark payment with missing classes (expected {expected_students_without_enough_classes_to_unmark_their_payment}, got {data['students_without_enough_paid_classes_to_unmark']})"
        
        # ensure that the rows of the db are correct 
        for idx, student in enumerate(students, start=1) : 
            group_enrollment = GroupEnrollment.objects.get(student=student,group=group)
            teacher_enrollment = TeacherEnrollment.objects.get(student=student,teacher=group.teacher)
            student_classes = Class.objects.filter(group_enrollment=group_enrollment,status__in=['attended_and_paid','attended_and_the_payment_due','attended_and_the_payment_not_due']).order_by('attendance_date','attendance_start_time','id')
            paid_classes_count = student_classes.filter(status='attended_and_paid').count()
            due_payment_classes_count = student_classes.filter(status='attended_and_the_payment_due').count()
            non_due_payment_classes_count = student_classes.filter(status='attended_and_the_payment_not_due').count()
            
            if student.id == first_student.id :
                expected_unpaid_amount  = 12 * group.teacher_subject.price_per_class
                assert teacher_enrollment.unpaid_amount == expected_unpaid_amount, f"the unpaid_amount of the teacher enrollment of the student {student.fullname} is incorrect (expected {expected_unpaid_amount}, got {teacher_enrollment.unpaid_amount})"
                assert group_enrollment.unpaid_amount == expected_unpaid_amount, f"the unpaid_amount of the group enrollment of the student {student.fullname} is incorrect (expected {expected_unpaid_amount}, got {group_enrollment.unpaid_amount})"
                assert group_enrollment.attended_non_paid_classes == 14, f"the attended_non_paid_classes of the group enrollment of the student {student.fullname} is incorrect (expected 14, got {group_enrollment.attended_non_paid_classes})"
                assert due_payment_classes_count == 12, f"the due payment classes count of the group enrollment of the student {student.fullname} is incorrect (expected 12, got {due_payment_classes_count})"
                assert non_due_payment_classes_count == 2, f"the non due payment classes count of the group enrollment of the student {student.fullname} is incorrect (expected 2, got {non_due_payment_classes_count})"
            else : 
                expected_unpaid_amount = 4 * group.teacher_subject.price_per_class
                assert teacher_enrollment.unpaid_amount == expected_unpaid_amount, f"the unpaid_amount of the teacher enrollment of the student {student.fullname} is incorrect (expected {expected_unpaid_amount}, got {teacher_enrollment.unpaid_amount})"
                assert group_enrollment.unpaid_amount == expected_unpaid_amount, f"the unpaid_amount of the group enrollment of the student {student.fullname} is incorrect (expected {expected_unpaid_amount}, got {group_enrollment.unpaid_amount})"
                assert group_enrollment.attended_non_paid_classes == 7, f"the attended_non_paid_classes of the group enrollment of the student {student.fullname} is incorrect (expected 7, got {group_enrollment.attended_non_paid_classes})"
                assert due_payment_classes_count == 4, f"the due payment classes count of the group enrollment of the student {student.fullname} is incorrect (expected 4, got {due_payment_classes_count})"
                assert non_due_payment_classes_count == 3, f"the non due payment classes count of the group enrollment of the student {student.fullname} is incorrect (expected 3, got {non_due_payment_classes_count})"

            assert paid_classes_count == 0, f"the paid classes count of the group enrollment of the student {student.fullname} is incorrect (expected 0, got {paid_classes_count})"
            assert group_enrollment.paid_amount == 0, f"the unpaid_amount of the group enrollment of the student {student.fullname} is incorrect (expected 0, got {group_enrollment.unpaid_amount})"
            assert teacher_enrollment.paid_amount == 0, f"the unpaid_amount of the teacher enrollment of the student {student.fullname} is incorrect (expected 0, got {teacher_enrollment.unpaid_amount})"
            

            # check if the orders of paid, due payment and non due payment classes is correct 
            for idx, klass in enumerate( student_classes, start=1):
                if idx <= (12 if student.id == first_student.id else 4):
                    assert klass.status == 'attended_and_the_payment_due', f"The status of the class at index {idx} for the student {student.fullname} is incorrect (expected 'attended_and_the_payment_due', got {klass.status})"
                else:
                    assert klass.status == 'attended_and_the_payment_not_due', f"The status of the class at index {idx} for the student {student.fullname} is incorrect (expected 'attended_and_the_payment_not_due', got {klass.status})"

        group.refresh_from_db()
        expected_total_unpaid = 2 * 4 * group.teacher_subject.price_per_class + 12 * group.teacher_subject.price_per_class
        assert group.total_unpaid == expected_total_unpaid, f"the total_unpaid of the group is incorrect (expected {expected_total_unpaid} , got {group.total_unpaid})"
        assert group.total_paid == 0, f"the total_paid of the group is incorrect (expected 0, got {group.total_paid})"
        print("\tSTARTING THE TEST OF MARKING PAYMENT WITH MISSING CLASSES")


            
        

    def test(self):
        print("START TESTTING THE UNMARK PAYMENT VIEW \n")

        self.test_unmarking_payment_without_missing_classes()
        self.test_unmarking_payment_with_missing_classes()

        print("\nTHE TEST OF THE UNMARK PAYMENT VIEW PASSED SUCCESSFULLY\n")

    
