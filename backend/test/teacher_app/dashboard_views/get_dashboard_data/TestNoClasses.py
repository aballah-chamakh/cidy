import datetime
from account.models import User 
from teacher.models import Teacher, TeacherSubject,Level, Section, Subject,Group, GroupEnrollment, Class
from student.models import Student
from teacher_app.TeacherClient import TeacherClient


class TestNoClasses:

    THIS_WEEK_DATES = [datetime.datetime(2025, 10, 1), datetime.datetime(2025, 10, 1)]
    THIS_MONTH_DATES = [datetime.datetime(2025, 10, 1), datetime.datetime(2025, 10, 1)]
    THIS_YEAR_DATES = [datetime.datetime(2025, 8, 10), datetime.datetime(2025, 8, 14)]

    # Data summary : 
    # 1 teacher
    # 9 teacher subjects
    # for each teacher subject : 2 groups 
    # for each teacher subject with a unique combination of level and section : 6 students created
    # for each group : 6 group enrollments (students), each 2 in a different time range 
    def set_up(self):
        User.objects.all().delete()
        Level.objects.all().delete()
        User.objects.create_superuser("chamakhabdallah8@gmail.com","58671414", "cidy1234")

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
            for group_name in ["A", "B"] :
                group = Group.objects.create( 
                                    teacher=teacher,
                                    teacher_subject=teacher_subject,
                                    week_day="Saturday",
                                    start_time="18:00",
                                    end_time="20:00",
                                    name=f"{teacher_subject.level.name} {teacher_subject.section.name if teacher_subject.section else ''} {teacher_subject.subject.name} ({group_name})")
                
                # enroll the 6 students in this group in different date ranges
                for i, student in enumerate(students):

                    # date range for this week  : 1 Oct 2025
                    if i < 2 : 
                        group_enrollement = GroupEnrollment.objects.create(group=group,student=student,date=TestNoClasses.THIS_WEEK_DATES[0].date())
                    # date range for this month : 1 Oct 2025
                    elif i < 4 :
                        group_enrollement = GroupEnrollment.objects.create(group=group,student=student,date=TestNoClasses.THIS_MONTH_DATES[0].date())
                    # date range for this year : 10 and 14 aug 2025
                    else:
                        group_enrollement = GroupEnrollment.objects.create(group=group,student=student,date=TestNoClasses.THIS_YEAR_DATES[0].date())

    def test(self):
        print("START TESTING LOADING DASHBOARD DATA WITH NO CLASSES :")
        teacher_client = TeacherClient("teacher10@gmail.com","iloveuu")
        teacher_client.authenticate() 
        
        dashboard_data = teacher_client.get_dashboard_data()
        expected_dashboard_data = {'has_levels': True, 'dashboard': {'total_paid_amount': 0.0, 'total_unpaid_amount': 0.0, 'total_active_students': 36, 'levels': {'Quatrième année secondaire': {'total_paid_amount': 0.0, 'total_unpaid_amount': 0.0, 'total_active_students': 12, 'sections': {'Technique': {'total_paid_amount': 0.0, 'total_unpaid_amount': 0.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 0.0, 'total_unpaid_amount': 0.0, 'total_active_students': 6}, 'Physique': {'total_paid_amount': 0.0, 'total_unpaid_amount': 0.0, 'total_active_students': 6}}}, 'Informatique': {'total_paid_amount': 0.0, 'total_unpaid_amount': 0.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 0.0, 'total_unpaid_amount': 0.0, 'total_active_students': 6}}}}}, 'Huitième année de base': {'total_paid_amount': 0.0, 'total_unpaid_amount': 0.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 0.0, 'total_unpaid_amount': 0.0, 'total_active_students': 6}, 'Physique': {'total_paid_amount': 0.0, 'total_unpaid_amount': 0.0, 'total_active_students': 6}}}, 'Septième année de base': {'total_paid_amount': 0.0, 'total_unpaid_amount': 0.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 0.0, 'total_unpaid_amount': 0.0, 'total_active_students': 6}}}, 'Sixième année primaire': {'total_paid_amount': 0.0, 'total_unpaid_amount': 0.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 0.0, 'total_unpaid_amount': 0.0, 'total_active_students': 6}, 'Éveil scientifique': {'total_paid_amount': 0.0, 'total_unpaid_amount': 0.0, 'total_active_students': 6}}}, 'Première année primaire': {'total_paid_amount': 0.0, 'total_unpaid_amount': 0.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 0.0, 'total_unpaid_amount': 0.0, 'total_active_students': 6}}}}}}
        
        if dashboard_data == expected_dashboard_data:
            print("    SUCCESSFUL TEST : LOADING DASHBOARD DATA WITH NO CLASSSES")
        else : 
            print("    FAILED TEST : LOADING DASHBOARD DATA WITH NO CLASSES")
            print("    RETURNED DASHBOARD DATA:", dashboard_data)

    