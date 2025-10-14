import datetime
from account.models import User 
from teacher.models import Teacher,TeacherEnrollment, TeacherSubject,Level, Subject,Group, GroupEnrollment, Class
from student.models import Student
from teacher_app.TeacherClient import TeacherClient

class TestDateRangeFilter:

    # Data summary : 
    # 1 teacher
    # 9 teacher subjects
    # for each teacher subject : 2 groups 
    # for each teacher subject with a unique combination of level and section : 6 students created
    # for each group : 6 group enrollments (students), each 2 in a different time range 
    # for each group enrollment : 12 classes, 2 paid and 2 unpaid in each time range
    # time ranges : 
    #    - this week (1 Oct 2025)
    #    - this month (1 Oct 2025)
    #    - this year (10 and 14 Aug 2025)

    THIS_WEEK_DATES = [datetime.datetime(2025, 10, 1), datetime.datetime(2025, 10, 1)]
    THIS_MONTH_DATES = [datetime.datetime(2025, 10, 1), datetime.datetime(2025, 10, 1)]
    THIS_YEAR_DATES = [datetime.datetime(2025, 8, 10), datetime.datetime(2025, 8, 14)]

    def set_up(self):
        Student.objects.all().delete()
        User.objects.all().delete()
        User.objects.create_superuser("chamakhabdallah8@gmail.com","58671414", "cidy1234")

        # Create a teacher 
        user  = User.objects.create_user("teacher10@gmail.com", "44558866", "iloveuu")
        teacher = Teacher.objects.create(user=user,fullname="teacher10",gender="M")

        # Add the levels, sections and subjects
        bac_tech = Level.objects.get(name="Quatrième année secondaire",section="Technique")
        bac_info = Level.objects.get(name="Quatrième année secondaire",section="Informatique")

        basic_8th = Level.objects.get(name="Huitième année de base")
        basic_7th = Level.objects.get(name="Septième année de base")

        primary_1st = Level.objects.get(name="Première année primaire")
        primary_6th = Level.objects.get(name="Sixième année primaire")

        math_subject = Subject.objects.get(name="Mathématiques")
        physics_subject = Subject.objects.get(name="Physique")
        science_subject = Subject.objects.get(name="Éveil scientifique")

        # add the teacher subjects 
        teacher_subjects = []
        # bac technique  : math, physics
        teacher_subjects.append(TeacherSubject.objects.create(teacher=teacher,level=bac_tech,subject=math_subject,price_per_class=20))
        teacher_subjects.append(TeacherSubject.objects.create(teacher=teacher,level=bac_tech,subject=physics_subject,price_per_class=25))
        # bac info : math
        teacher_subjects.append(TeacherSubject.objects.create(teacher=teacher,level=bac_info,subject=math_subject,price_per_class=20))

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
        for index, teacher_subject in enumerate(teacher_subjects, start=1):

            # create 6 student for each level  
            ## if they don't exit

            students = Student.objects.filter(level=teacher_subject.level)#[:6]
            
            if not students.exists():
                students = []
                for i in range(12):
                    phone_number = f"000000{student_cnt}" if student_cnt >= 10 else f"0000000{student_cnt}"
                    student = Student.objects.create(
                        user=User.objects.create_user(f"student{student_cnt}@gmail.com", phone_number, "password"),
                        fullname = f"student{student_cnt}",
                        phone_number=phone_number,
                        gender="M",
                        level=teacher_subject.level
                    )
                    TeacherEnrollment.objects.create(teacher=teacher,student=student)
                    student_cnt += 1
                    #if i < 6:  # only keep 6 students per level
                    students.append(student)
                print(f"Created {len(students)} students for level {teacher_subject.level}")
            else:
                print(f"Found existing {students.count()} students for level {teacher_subject.level}")
            # add 2 groups for each teacher subject
            for group_name in ["A", "B"]:
                group = Group.objects.create( 
                                    teacher=teacher,
                                    teacher_subject=teacher_subject,
                                    week_day="Monday" if group_name == "A" else "Tuesday",
                                    start_time="18:00" if group_name == "A" else "20:00",
                                    end_time="20:00" if group_name == "A" else "22:00",
                                    name=f"Groupe {group_name}",
                                    total_paid= index * 100,
                                    total_unpaid= index * 100 )
                
                # enroll the 6 students in this group in different date ranges
                for i, student in enumerate(students):
                    # date range for this week  : 1 Oct 2025
                    if i < 2 : 
                        group_enrollement = GroupEnrollment.objects.create(group=group,student=student,date=TestDateRangeFilter.THIS_WEEK_DATES[0].date())
                        # create classes for this enrollment in different statuses and date ranges 
                        self.create_classes_for_a_group_enrollment_in_different_status_and_date_ranges(group_enrollement)


                    # date range for this month : 1 Oct 2025
                    elif i < 4 :
                        group_enrollement = GroupEnrollment.objects.create(group=group,student=student,date=TestDateRangeFilter.THIS_MONTH_DATES[0].date())
                        self.create_classes_for_a_group_enrollment_in_different_status_and_date_ranges(group_enrollement)
                    # date range for this year : 10 and 14 aug 2025
                    else:
                        group_enrollement = GroupEnrollment.objects.create(group=group,student=student,date=TestDateRangeFilter.THIS_YEAR_DATES[0].date())
                        self.create_classes_for_a_group_enrollment_in_different_status_and_date_ranges(group_enrollement)

    def create_classes_for_a_group_enrollment_in_different_status_and_date_ranges(self,group_enrollement):


        # create classes for this enrollment in different statuses and date ranges 
        for j in range(12):
            # create 2 paid classes and 2 unpaid classes in this week : 1 Oct 2025
            if j < 4 :
                # create 2 paid classes
                if j < 2 :
                    Class.objects.create(
                        group_enrollment=group_enrollement,
                        status='attended_and_paid',
                        last_status_datetime=TestDateRangeFilter.THIS_WEEK_DATES[0]  # within this week
                    )
                else : 
                    Class.objects.create(
                        group_enrollment=group_enrollement,
                        status='attended_and_the_payment_due',
                        last_status_datetime=TestDateRangeFilter.THIS_WEEK_DATES[0]  # within this week
                    )
            elif j < 8 :
                # create 2 paid classes and 2 unpaid classes in this month : 1 Oct 2025
                if j < 6 :
                    Class.objects.create(
                        group_enrollment=group_enrollement,
                        status='attended_and_paid',
                        last_status_datetime=TestDateRangeFilter.THIS_MONTH_DATES[0]  # within this month
                    )
                else : 
                    Class.objects.create(
                        group_enrollment=group_enrollement,
                        status='attended_and_the_payment_due',
                        last_status_datetime=TestDateRangeFilter.THIS_MONTH_DATES[0]  # within this month
                    )
            else:
                # create 2 paid classes and 2 unpaid classes in this year : 10 Aug and 14 Aug 2025
                if j < 10 :
                    Class.objects.create(
                        group_enrollment=group_enrollement,
                        status='attended_and_paid',
                        last_status_datetime=TestDateRangeFilter.THIS_YEAR_DATES[0]  # within this year
                    )
                else : 
                    Class.objects.create(
                        group_enrollment=group_enrollement,
                        status='attended_and_the_payment_due',
                        last_status_datetime=TestDateRangeFilter.THIS_YEAR_DATES[1]  # within this year
                    )
    def test(self):
        print("START TESTING DATE RANGE FILTER WITH DIFFERENT DATE RANGES :")
        teacher_client = TeacherClient("teacher10@gmail.com","iloveuu")
        teacher_client.authenticate()

        # test with no filters 
        dashboard_data = teacher_client.get_dashboard_data()
        expected_dashboard_data = {'has_levels': True, 'dashboard': {'total_paid_amount': 10080.0, 'total_unpaid_amount': 10080.0, 'total_active_students': 36, 'levels': {'Quatrième année secondaire': {'total_paid_amount': 4680.0, 'total_unpaid_amount': 4680.0, 'total_active_students': 12, 'sections': {'Technique': {'total_paid_amount': 3240.0, 'total_unpaid_amount': 3240.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 1440.0, 'total_unpaid_amount': 1440.0, 'total_active_students': 6}, 'Physique': {'total_paid_amount': 1800.0, 'total_unpaid_amount': 1800.0, 'total_active_students': 6}}}, 'Informatique': {'total_paid_amount': 1440.0, 'total_unpaid_amount': 1440.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 1440.0, 'total_unpaid_amount': 1440.0, 'total_active_students': 6}}}}}, 'Huitième année de base': {'total_paid_amount': 2160.0, 'total_unpaid_amount': 2160.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 1080.0, 'total_unpaid_amount': 1080.0, 'total_active_students': 6}, 'Physique': {'total_paid_amount': 1080.0, 'total_unpaid_amount': 1080.0, 'total_active_students': 6}}}, 'Septième année de base': {'total_paid_amount': 1080.0, 'total_unpaid_amount': 1080.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 1080.0, 'total_unpaid_amount': 1080.0, 'total_active_students': 6}}}, 'Sixième année primaire': {'total_paid_amount': 1440.0, 'total_unpaid_amount': 1440.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 720.0, 'total_unpaid_amount': 720.0, 'total_active_students': 6}, 'Éveil scientifique': {'total_paid_amount': 720.0, 'total_unpaid_amount': 720.0, 'total_active_students': 6}}}, 'Première année primaire': {'total_paid_amount': 720.0, 'total_unpaid_amount': 720.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 720.0, 'total_unpaid_amount': 720.0, 'total_active_students': 6}}}}}}
        if dashboard_data == expected_dashboard_data:
            print("    SUCCESSFUL TEST : LOADING DASHBOARD DATA WITH NO FILTERS")
        else : 
            print("    FAILED TEST : LOADING DASHBOARD DATA WITH NO FILTERS")
            print("    RETURNED DASHBOARD DATA:", dashboard_data)
         
        # test this week
        dashboard_data = teacher_client.get_dashboard_data(date_range="this_week")
        expected_dashboard_data = {'has_levels': True, 'dashboard': {'total_paid_amount': 6720.0, 'total_unpaid_amount': 6720.0, 'total_active_students': 36, 'levels': {'Quatrième année secondaire': {'total_paid_amount': 3120.0, 'total_unpaid_amount': 3120.0, 'total_active_students': 12, 'sections': {'Technique': {'total_paid_amount': 2160.0, 'total_unpaid_amount': 2160.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 960.0, 'total_unpaid_amount': 960.0, 'total_active_students': 6}, 'Physique': {'total_paid_amount': 1200.0, 'total_unpaid_amount': 1200.0, 'total_active_students': 6}}}, 'Informatique': {'total_paid_amount': 960.0, 'total_unpaid_amount': 960.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 960.0, 'total_unpaid_amount': 960.0, 'total_active_students': 6}}}}}, 'Huitième année de base': {'total_paid_amount': 1440.0, 'total_unpaid_amount': 1440.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 720.0, 'total_unpaid_amount': 720.0, 'total_active_students': 6}, 'Physique': {'total_paid_amount': 720.0, 'total_unpaid_amount': 720.0, 'total_active_students': 6}}}, 'Septième année de base': {'total_paid_amount': 720.0, 'total_unpaid_amount': 720.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 720.0, 'total_unpaid_amount': 720.0, 'total_active_students': 6}}}, 'Sixième année primaire': {'total_paid_amount': 960.0, 'total_unpaid_amount': 960.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 480.0, 'total_unpaid_amount': 480.0, 'total_active_students': 6}, 'Éveil scientifique': {'total_paid_amount': 480.0, 'total_unpaid_amount': 480.0, 'total_active_students': 6}}}, 'Première année primaire': {'total_paid_amount': 480.0, 'total_unpaid_amount': 480.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 480.0, 'total_unpaid_amount': 480.0, 'total_active_students': 6}}}}}}
        if dashboard_data == expected_dashboard_data :
            print("    SUCCESSFUL TEST : LOADING DASHBOARD DATA WITH date_range=this_week")
        else : 
            print("    FAILED TEST : LOADING DASHBOARD DATA WITH date_range=this_week")
            print("    RETURNED DASHBOARD DATA:", dashboard_data) 

        # test this month
        dashboard_data = teacher_client.get_dashboard_data(date_range="this_month")
        expected_dashboard_data = {'has_levels': True, 'dashboard': {'total_paid_amount': 6720.0, 'total_unpaid_amount': 6720.0, 'total_active_students': 36, 'levels': {'Quatrième année secondaire': {'total_paid_amount': 3120.0, 'total_unpaid_amount': 3120.0, 'total_active_students': 12, 'sections': {'Technique': {'total_paid_amount': 2160.0, 'total_unpaid_amount': 2160.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 960.0, 'total_unpaid_amount': 960.0, 'total_active_students': 6}, 'Physique': {'total_paid_amount': 1200.0, 'total_unpaid_amount': 1200.0, 'total_active_students': 6}}}, 'Informatique': {'total_paid_amount': 960.0, 'total_unpaid_amount': 960.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 960.0, 'total_unpaid_amount': 960.0, 'total_active_students': 6}}}}}, 'Huitième année de base': {'total_paid_amount': 1440.0, 'total_unpaid_amount': 1440.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 720.0, 'total_unpaid_amount': 720.0, 'total_active_students': 6}, 'Physique': {'total_paid_amount': 720.0, 'total_unpaid_amount': 720.0, 'total_active_students': 6}}}, 'Septième année de base': {'total_paid_amount': 720.0, 'total_unpaid_amount': 720.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 720.0, 'total_unpaid_amount': 720.0, 'total_active_students': 6}}}, 'Sixième année primaire': {'total_paid_amount': 960.0, 'total_unpaid_amount': 960.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 480.0, 'total_unpaid_amount': 480.0, 'total_active_students': 6}, 'Éveil scientifique': {'total_paid_amount': 480.0, 'total_unpaid_amount': 480.0, 'total_active_students': 6}}}, 'Première année primaire': {'total_paid_amount': 480.0, 'total_unpaid_amount': 480.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 480.0, 'total_unpaid_amount': 480.0, 'total_active_students': 6}}}}}}
        if dashboard_data == expected_dashboard_data :
            print("    SUCCESSFUL TEST : LOADING DASHBOARD DATA WITH date_range=this_month")
        else : 
            print("    FAILED TEST : LOADING DASHBOARD DATA WITH date_range=this_month")
            print("    RETURNED DASHBOARD DATA:", dashboard_data) 

        # test this year
        dashboard_data = teacher_client.get_dashboard_data(date_range="this_year")
        expected_dashboard_data = {'has_levels': True, 'dashboard': {'total_paid_amount': 10080.0, 'total_unpaid_amount': 10080.0, 'total_active_students': 36, 'levels': {'Quatrième année secondaire': {'total_paid_amount': 4680.0, 'total_unpaid_amount': 4680.0, 'total_active_students': 12, 'sections': {'Technique': {'total_paid_amount': 3240.0, 'total_unpaid_amount': 3240.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 1440.0, 'total_unpaid_amount': 1440.0, 'total_active_students': 6}, 'Physique': {'total_paid_amount': 1800.0, 'total_unpaid_amount': 1800.0, 'total_active_students': 6}}}, 'Informatique': {'total_paid_amount': 1440.0, 'total_unpaid_amount': 1440.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 1440.0, 'total_unpaid_amount': 1440.0, 'total_active_students': 6}}}}}, 'Huitième année de base': {'total_paid_amount': 2160.0, 'total_unpaid_amount': 2160.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 1080.0, 'total_unpaid_amount': 1080.0, 'total_active_students': 6}, 'Physique': {'total_paid_amount': 1080.0, 'total_unpaid_amount': 1080.0, 'total_active_students': 6}}}, 'Septième année de base': {'total_paid_amount': 1080.0, 'total_unpaid_amount': 1080.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 1080.0, 'total_unpaid_amount': 1080.0, 'total_active_students': 6}}}, 'Sixième année primaire': {'total_paid_amount': 1440.0, 'total_unpaid_amount': 1440.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 720.0, 'total_unpaid_amount': 720.0, 'total_active_students': 6}, 'Éveil scientifique': {'total_paid_amount': 720.0, 'total_unpaid_amount': 720.0, 'total_active_students': 6}}}, 'Première année primaire': {'total_paid_amount': 720.0, 'total_unpaid_amount': 720.0, 'total_active_students': 6, 'subjects': {'Mathématiques': {'total_paid_amount': 720.0, 'total_unpaid_amount': 720.0, 'total_active_students': 6}}}}}}
        if dashboard_data == expected_dashboard_data :
            print("    SUCCESSFUL TEST : LOADING DASHBOARD DATA WITH date_range=this_year")
        else : 
            print("    FAILED TEST : LOADING DASHBOARD DATA WITH date_range=this_year")
            print("    RETURNED DASHBOARD DATA:", dashboard_data) 

        
        # test in a specific date range
        dashboard_data = teacher_client.get_dashboard_data(start_date="2025-08-10", end_date="2025-08-14")
        expected_dashboard_data = {'has_levels': True, 'dashboard': {'total_paid_amount': 1120.0, 'total_unpaid_amount': 1120.0, 'total_active_students': 12, 'levels': {'Quatrième année secondaire': {'total_paid_amount': 520.0, 'total_unpaid_amount': 520.0, 'total_active_students': 4, 'sections': {'Technique': {'total_paid_amount': 360.0, 'total_unpaid_amount': 360.0, 'total_active_students': 2, 'subjects': {'Mathématiques': {'total_paid_amount': 160.0, 'total_unpaid_amount': 160.0, 'total_active_students': 2}, 'Physique': {'total_paid_amount': 200.0, 'total_unpaid_amount': 200.0, 'total_active_students': 2}}}, 'Informatique': {'total_paid_amount': 160.0, 'total_unpaid_amount': 160.0, 'total_active_students': 2, 'subjects': {'Mathématiques': {'total_paid_amount': 160.0, 'total_unpaid_amount': 160.0, 'total_active_students': 2}}}}}, 'Huitième année de base': {'total_paid_amount': 240.0, 'total_unpaid_amount': 240.0, 'total_active_students': 2, 'subjects': {'Mathématiques': {'total_paid_amount': 120.0, 'total_unpaid_amount': 120.0, 'total_active_students': 2}, 'Physique': {'total_paid_amount': 120.0, 'total_unpaid_amount': 120.0, 'total_active_students': 2}}}, 'Septième année de base': {'total_paid_amount': 120.0, 'total_unpaid_amount': 120.0, 'total_active_students': 2, 'subjects': {'Mathématiques': {'total_paid_amount': 120.0, 'total_unpaid_amount': 120.0, 'total_active_students': 2}}}, 'Sixième année primaire': {'total_paid_amount': 160.0, 'total_unpaid_amount': 160.0, 'total_active_students': 2, 'subjects': {'Mathématiques': {'total_paid_amount': 80.0, 'total_unpaid_amount': 80.0, 'total_active_students': 2}, 'Éveil scientifique': {'total_paid_amount': 80.0, 'total_unpaid_amount': 80.0, 'total_active_students': 2}}}, 'Première année primaire': {'total_paid_amount': 80.0, 'total_unpaid_amount': 80.0, 'total_active_students': 2, 'subjects': {'Mathématiques': {'total_paid_amount': 80.0, 'total_unpaid_amount': 80.0, 'total_active_students': 2}}}}}}
        if dashboard_data == expected_dashboard_data:
            print("    SUCCESSFUL TEST : LOADING DASHBOARD DATA WITH A SPECIFIC DATE RANGE")
        else:
            print("    FAILED TEST : LOADING DASHBOARD DATA WITH A SPECIFIC DATE RANGE")
            print("    RETURNED DASHBOARD DATA:", dashboard_data)

        