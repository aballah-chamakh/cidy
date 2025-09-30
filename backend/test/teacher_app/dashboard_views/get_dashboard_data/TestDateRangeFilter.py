import datetime
from account.models import User 
from teacher.models import Teacher, TeacherSubject,Level, Section, Subject,Group, GroupEnrollment, Class
from student.models import Student

class TestDateRangeFilter:


    def set_up(self):
        # Create a teacher 
        user  = User.objects.create_user("teacher10@gmail.com", "44558866", "iloveuu")
        teacher = Teacher.objects.create(user=user,fullname="teacher10",gender="M")

        # Add the levels, sections and subjects
        bac_level = Level.objects.create(name="Quatrième année secondaire")
        tech_section = Section.objects.create(name="Technique")
        info_section = Section.objects.create(name="Informatique")

        basic_8th = Level.objects.create(name="Huitième année de base")
        basic_7th = Level.objects.create(name="Septième année de base")

        primary_1st = Level.objects.create(name="Première année primaire")
        primary_6th = Level.objects.create(name="Sixième année primaire")

        math_subject = Subject.objects.create(name="Mathématiques")
        physics_subject = Subject.objects.create(name="Physique")
        science_subject = Subject.objects.create(name="Éveil scientifique")

        # add the teacher subjects 
        teacher_subjects = []
        # bac technique  : math, physics
        teacher_subjects.append(TeacherSubject.objects.create(teacher=teacher,level=bac_level,section=tech_section,subject=math_subject,price_per_class=20))
        teacher_subjects.append(TeacherSubject.objects.create(teacher=teacher,level=bac_level,section=tech_section,subject=physics_subject,price_per_class=25))
        # bac info : math
        teacher_subjects.append(TeacherSubject.objects.create(teacher=teacher,level=bac_level,section=info_section,subject=math_subject,price_per_class=20))

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
        for teacher_subject in teacher_subjects:

            # create 6 student for each unique combination of level and section 
            ## if they don't exit
            if teacher_subject.section:
                students = Student.objects.filter(level=teacher_subject.level,section=teacher_subject.section)
            else:
                students = Student.objects.filter(level=teacher_subject.level,section__isnull=True)
            
            if not students.exists():
                students = []
                for i in range(6):
                    phone_number = f"000000{student_cnt}" if student_cnt >= 10 else f"0000000{student_cnt}"
                    student = Student.objects.create(
                        user=User.objects.create_user(f"student{student_cnt}@gmail.com", phone_number, "password"),
                        fullname = f"student{student_cnt}",
                        phone_number=phone_number,
                        gender="M",
                        level=teacher_subject.level,
                        section=teacher_subject.section
                    )
                    student_cnt += 1
                    students.append(student)

            # add 2 groups for each teacher subject
            for group_name in ["A", "B"]:
                group = Group.objects.create( 
                                    teacher=teacher,
                                    teacher_subject=teacher_subject,
                                    week_day="Saturday",
                                    start_time="18:00",
                                    end_time="20:00",
                                    name=f"{teacher_subject.level.name} {teacher_subject.section.name if teacher_subject.section else ''} {teacher_subject.subject.name} ({group_name})")
                
                # enroll the 6 students in this group in different date ranges
                for i, student in enumerate(students):
                    print(f"student_id : {student.id} -- group id : {group.id}")
                    # date range for this week  : 29 and 30 sept 2025
                    if i < 2 : 
                        group_enrollement = GroupEnrollment.objects.create(group=group,student=student,date=datetime.date(2025, 9, 29))
                        # create classes for this enrollment in different statuses and date ranges 
                        self.create_classes_for_a_group_enrollment_in_different_status_and_date_ranges(group_enrollement)


                    # date range for this month : 15 and 16 sept 2025
                    elif i < 4 :
                        group_enrollement = GroupEnrollment.objects.create(group=group,student=student,date=datetime.date(2025, 9, 15))
                        self.create_classes_for_a_group_enrollment_in_different_status_and_date_ranges(group_enrollement)
                    # date range for this year : 10 and 14 aug 2025
                    else:
                        group_enrollement = GroupEnrollment.objects.create(group=group,student=student,date=datetime.date(2025, 8, 10))
                        self.create_classes_for_a_group_enrollment_in_different_status_and_date_ranges(group_enrollement)

    def create_classes_for_a_group_enrollment_in_different_status_and_date_ranges(self,group_enrollement):
        # create classes for this enrollment in different statuses and date ranges 
        for j in range(12):
            # create 2 paid classes and 2 unpaid classes in this week : 29 and 30 sept 2025
            if j < 4 :
                # create 2 paid classes
                if j < 2 :
                    Class.objects.create(
                        group_enrollment=group_enrollement,
                        status='attended_and_paid',
                        attendance_date=datetime.date(2025, 9, 29)  # within this week
                    )
                else : 
                    Class.objects.create(
                        group_enrollment=group_enrollement,
                        status='attended_and_the_payment_due',
                        attendance_date=datetime.date(2025, 9, 30)  # within this week
                    )
            elif j < 8 :
                # create 2 paid classes and 2 unpaid classes in this month : 15 and 16 sept 2025
                if j < 6 :
                    Class.objects.create(
                        group_enrollment=group_enrollement,
                        status='attended_and_paid',
                        attendance_date=datetime.date(2025, 9, 15)  # within this month
                    )
                else : 
                    Class.objects.create(
                        group_enrollment=group_enrollement,
                        status='attended_and_the_payment_due',
                        attendance_date=datetime.date(2025, 9, 16)  # within this month
                    )
            else:
                # create 2 paid classes and 2 unpaid classes in this year : 10 and 14 aug 2025
                if j < 10 :
                    Class.objects.create(
                        group_enrollment=group_enrollement,
                        status='attended_and_paid',
                        attendance_date=datetime.date(2025, 8, 10)  # within this year
                    )
                else : 
                    Class.objects.create(
                        group_enrollment=group_enrollement,
                        status='attended_and_the_payment_due',
                        attendance_date=datetime.date(2025, 8, 14)  # within this year
                    )
    def test():
        pass
    

