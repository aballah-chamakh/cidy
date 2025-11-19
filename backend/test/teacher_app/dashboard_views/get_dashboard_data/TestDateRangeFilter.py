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
    # for each teacher subject  : 12 students created
    # for each group : 12 group enrollments (students), each 4 in a different time range 
    # for each group enrollment : 12 classes, 2 paid and 2 unpaid in each time range
    # time ranges : 
    #    - this week (1 Oct 2025)
    #    - this month (1 Oct 2025)
    #    - this year (10 and 14 Aug 2025)

    THIS_WEEK_DATES = [datetime.datetime(2025, 11, 17), datetime.datetime(2025, 11, 18)]
    THIS_MONTH_DATES = [datetime.datetime(2025, 11, 5), datetime.datetime(2025, 11, 6)]
    THIS_YEAR_DATES = [datetime.datetime(2025, 8, 10), datetime.datetime(2025, 8, 14)]

    def set_up(self):
        Student.objects.all().delete()
        User.objects.all().delete()
        User.objects.create_superuser("chamakhabdallah8@gmail.com","58671414", "cidy1234")

        # Create a teacher 
        user  = User.objects.create_user("teacher10@gmail.com", "44558866", "iloveuu")
        teacher = Teacher.objects.create(user=user,fullname="teacher10",gender="M")

        # create levels 
        bac_tech = Level.objects.get(name="Quatrième année secondaire",section="Technique")
        bac_info = Level.objects.get(name="Quatrième année secondaire",section="Informatique")

        basic_8th = Level.objects.get(name="Huitième année de base")
        basic_7th = Level.objects.get(name="Septième année de base")

        primary_1st = Level.objects.get(name="Première année primaire")
        primary_6th = Level.objects.get(name="Sixième année primaire")

        # create subjects 
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

            students = Student.objects.filter(level=teacher_subject.level).order_by('id') #[:6]
            
            if not students.exists():
                students = []
                for i in range(12):
                    phone_number = f"000000{student_cnt}" if student_cnt >= 10 else f"0000000{student_cnt}"
                    student = Student.objects.create(
                        fullname = f"student{student_cnt}",
                        phone_number=phone_number,
                        gender="M",
                        level=teacher_subject.level
                    )
                    TeacherEnrollment.objects.create(teacher=teacher,student=student,
                                                     paid_amount= student_cnt * 2 * 100,
                                                     unpaid_amount= student_cnt * 100)
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
                                    total_paid= index * 2 * 100,
                                    total_unpaid= index * 100 )
                
                # enroll the 6 students in this group in different date ranges
                for i, student in enumerate(students):


                    # date range for this week  
                    if i < 4 : 
                        if i < 2 : 
                            group_enrollement = GroupEnrollment.objects.create(group=group,student=student 
                                                                            ,date=TestDateRangeFilter.THIS_WEEK_DATES[0].date(),
                                                                            paid_amount=i*2*100,
                                                                            unpaid_amount=i*100
                                                                            )
                        else :
                            group_enrollement = GroupEnrollment.objects.create(group=group,student=student,
                                                                             date=TestDateRangeFilter.THIS_WEEK_DATES[1].date(),
                                                                             paid_amount=i*2*100,
                                                                             unpaid_amount=i*100)
                        # create classes for this enrollment in different statuses and date ranges 
                        self.create_classes_for_a_group_enrollment_in_different_status_and_date_ranges(group_enrollement,end_range=4)


                    # date range for this month 
                    elif i < 8 :
                        if i < 6 : 
                            group_enrollement = GroupEnrollment.objects.create(group=group,student=student,
                                                                               date=TestDateRangeFilter.THIS_MONTH_DATES[0].date(),
                                                                         paid_amount=i*2*100,
                                                                         unpaid_amount=i*100)
                        else : 
                            group_enrollement = GroupEnrollment.objects.create(group=group,student=student,
                                                                               date=TestDateRangeFilter.THIS_MONTH_DATES[1].date(),
                                                                         paid_amount=i*2*100,
                                                                         unpaid_amount=i*100)
                        self.create_classes_for_a_group_enrollment_in_different_status_and_date_ranges(group_enrollement,end_range=8)
                    # date range for this year 
                    else:
                        if i < 10 :
                            group_enrollement = GroupEnrollment.objects.create(group=group,student=student,
                                                                                date=TestDateRangeFilter.THIS_YEAR_DATES[0].date(),
                                                                         paid_amount=i*2*100,
                                                                         unpaid_amount=i*100)
                        else :
                            group_enrollement = GroupEnrollment.objects.create(group=group,student=student,
                                                                               date=TestDateRangeFilter.THIS_YEAR_DATES[1].date(),
                                                                         paid_amount=i*2*100,
                                                                         unpaid_amount=i*100)
                            
                        self.create_classes_for_a_group_enrollment_in_different_status_and_date_ranges(group_enrollement)

    def create_classes_for_a_group_enrollment_in_different_status_and_date_ranges(self,group_enrollement,end_range=12):
        #note : i did add start range because the student enrollment can't have classes in date ranges before his enrollment date

        # create classes for this enrollment in different statuses and date ranges 
        for j in range(end_range):
            # create 2 paid classes and 2 unpaid classes in this week : 1 Oct 2025
            if j < 4 :
                # create 2 paid classes
                if j < 2 :
                    Class.objects.create(
                        group_enrollment=group_enrollement,
                        status='attended_and_paid',
                        paid_at=TestDateRangeFilter.THIS_WEEK_DATES[0]  # within this week
                    )
                else : 
                    Class.objects.create(
                        group_enrollment=group_enrollement,
                        status='attended_and_the_payment_due',
                        attendance_date=TestDateRangeFilter.THIS_WEEK_DATES[1]  # within this week
                    )
            elif j < 8 :
                # create 2 paid classes and 2 unpaid classes in this month : 1 Oct 2025
                if j < 6 :
                    Class.objects.create(
                        group_enrollment=group_enrollement,
                        status='attended_and_paid',
                        paid_at=TestDateRangeFilter.THIS_MONTH_DATES[0]  # within this month
                    )
                else : 
                    Class.objects.create(
                        group_enrollment=group_enrollement,
                        status='attended_and_the_payment_due',
                        attendance_date=TestDateRangeFilter.THIS_MONTH_DATES[1]  # within this month
                    )
            else:
                # create 2 paid classes and 2 unpaid classes in this year : 10 Aug and 14 Aug 2025
                if j < 10 :
                    Class.objects.create(
                        group_enrollment=group_enrollement,
                        status='attended_and_paid',
                        paid_at=TestDateRangeFilter.THIS_YEAR_DATES[0]  # within this year
                    )
                else : 
                    Class.objects.create(
                        group_enrollment=group_enrollement,
                        status='attended_and_the_payment_due',
                        attendance_date=TestDateRangeFilter.THIS_YEAR_DATES[1]  # within this year
                    )
    def test(self):
        print("START TESTING DATE RANGE FILTER WITH DIFFERENT DATE RANGES :")
        teacher_client = TeacherClient("teacher10@gmail.com","iloveuu")

        # test with no filters 
        dashboard_data = teacher_client.get_dashboard_data()
        expected_dashboard_data = {"has_levels":True,"dashboard":{'total_paid_amount': 13440.00, 'total_unpaid_amount': 13440.00, 'total_active_students': 72, 'levels': {'Quatrième année secondaire': {'total_paid_amount': 6240.00, 'total_unpaid_amount': 6240.00, 'total_active_students': 24, 'sections': {'Technique': {'total_paid_amount': 4320.00, 'total_unpaid_amount': 4320.00, 'total_active_students': 12, 'subjects': {'Mathématiques': {'total_paid_amount': 1920.00, 'total_unpaid_amount': 1920.00, 'total_active_students': 12}, 'Physique': {'total_paid_amount': 2400.00, 'total_unpaid_amount': 2400.00, 'total_active_students': 12}}}, 'Informatique': {'total_paid_amount': 1920.00, 'total_unpaid_amount': 1920.00, 'total_active_students': 12, 'subjects': {'Mathématiques': {'total_paid_amount': 1920.00, 'total_unpaid_amount': 1920.00, 'total_active_students': 12}}}}}, 'Huitième année de base': {'total_paid_amount': 2880.00, 'total_unpaid_amount': 2880.00, 'total_active_students': 12, 'subjects': {'Mathématiques': {'total_paid_amount': 1440.00, 'total_unpaid_amount': 1440.00, 'total_active_students': 12}, 'Physique': {'total_paid_amount': 1440.00, 'total_unpaid_amount': 1440.00, 'total_active_students': 12}}}, 'Septième année de base': {'total_paid_amount': 1440.00, 'total_unpaid_amount': 1440.00, 'total_active_students': 12, 'subjects': {'Mathématiques': {'total_paid_amount': 1440.00, 'total_unpaid_amount': 1440.00, 'total_active_students': 12}}}, 'Sixième année primaire': {'total_paid_amount': 1920.00, 'total_unpaid_amount': 1920.00, 'total_active_students': 12, 'subjects': {'Mathématiques': {'total_paid_amount': 960.00, 'total_unpaid_amount': 960.00, 'total_active_students': 12}, 'Éveil scientifique': {'total_paid_amount': 960.00, 'total_unpaid_amount': 960.00, 'total_active_students': 12}}}, 'Première année primaire': {'total_paid_amount': 960.00, 'total_unpaid_amount': 960.00, 'total_active_students': 12, 'subjects': {'Mathématiques': {'total_paid_amount': 960.00, 'total_unpaid_amount': 960.00, 'total_active_students': 12}}}}}}
        if dashboard_data == expected_dashboard_data:
            print("    SUCCESSFUL TEST : LOADING DASHBOARD DATA WITH NO FILTERS")
        else : 
            print("    FAILED TEST : LOADING DASHBOARD DATA WITH NO FILTERS")
            print("    RETURNED DASHBOARD DATA:", dashboard_data)
         
        # test this week
        dashboard_data = teacher_client.get_dashboard_data(date_range="this_week")
        expected_dashboard_data = {"has_levels":True,"dashboard":{'total_paid_amount': 6720.00, 'total_unpaid_amount': 6720.00, 'total_active_students': 24, 'levels': {'Quatrième année secondaire': {'total_paid_amount': 3120.00, 'total_unpaid_amount': 3120.00, 'total_active_students': 8, 'sections': {'Technique': {'total_paid_amount': 2160.00, 'total_unpaid_amount': 2160.00, 'total_active_students': 4, 'subjects': {'Mathématiques': {'total_paid_amount': 960.00, 'total_unpaid_amount': 960.00, 'total_active_students': 4}, 'Physique': {'total_paid_amount': 1200.00, 'total_unpaid_amount': 1200.00, 'total_active_students': 4}}}, 'Informatique': {'total_paid_amount': 960.00, 'total_unpaid_amount': 960.00, 'total_active_students': 4, 'subjects': {'Mathématiques': {'total_paid_amount': 960.00, 'total_unpaid_amount': 960.00, 'total_active_students': 4}}}}}, 'Huitième année de base': {'total_paid_amount': 1440.00, 'total_unpaid_amount': 1440.00, 'total_active_students': 4, 'subjects': {'Mathématiques': {'total_paid_amount': 720.00, 'total_unpaid_amount': 720.00, 'total_active_students': 4}, 'Physique': {'total_paid_amount': 720.00, 'total_unpaid_amount': 720.00, 'total_active_students': 4}}}, 'Septième année de base': {'total_paid_amount': 720.00, 'total_unpaid_amount': 720.00, 'total_active_students': 4, 'subjects': {'Mathématiques': {'total_paid_amount': 720.00, 'total_unpaid_amount': 720.00, 'total_active_students': 4}}}, 'Sixième année primaire': {'total_paid_amount': 960.00, 'total_unpaid_amount': 960.00, 'total_active_students': 4, 'subjects': {'Mathématiques': {'total_paid_amount': 480.00, 'total_unpaid_amount': 480.00, 'total_active_students': 4}, 'Éveil scientifique': {'total_paid_amount': 480.00, 'total_unpaid_amount': 480.00, 'total_active_students': 4}}}, 'Première année primaire': {'total_paid_amount': 480.00, 'total_unpaid_amount': 480.00, 'total_active_students': 4, 'subjects': {'Mathématiques': {'total_paid_amount': 480.00, 'total_unpaid_amount': 480.00, 'total_active_students': 4}}}}}}
        
        if dashboard_data == expected_dashboard_data :
            print("    SUCCESSFUL TEST : LOADING DASHBOARD DATA WITH date_range=this_week")
        else : 
            print("    FAILED TEST : LOADING DASHBOARD DATA WITH date_range=this_week")
            print("    RETURNED DASHBOARD DATA:", dashboard_data) 

        # test this month
        dashboard_data = teacher_client.get_dashboard_data(date_range="this_month")
        expected_dashboard_data = {"has_levels":True,"dashboard":{'total_paid_amount': 11200.00, 'total_unpaid_amount': 11200.00, 'total_active_students': 48, 'levels': {'Quatrième année secondaire': {'total_paid_amount': 5200.00, 'total_unpaid_amount': 5200.00, 'total_active_students': 16, 'sections': {'Technique': {'total_paid_amount': 3600.00, 'total_unpaid_amount': 3600.00, 'total_active_students': 8, 'subjects': {'Mathématiques': {'total_paid_amount': 1600.00, 'total_unpaid_amount': 1600.00, 'total_active_students': 8}, 'Physique': {'total_paid_amount': 2000.00, 'total_unpaid_amount': 2000.00, 'total_active_students': 8}}}, 'Informatique': {'total_paid_amount': 1600.00, 'total_unpaid_amount': 1600.00, 'total_active_students': 8, 'subjects': {'Mathématiques': {'total_paid_amount': 1600.00, 'total_unpaid_amount': 1600.00, 'total_active_students': 8}}}}}, 'Huitième année de base': {'total_paid_amount': 2400.00, 'total_unpaid_amount': 2400.00, 'total_active_students': 8, 'subjects': {'Mathématiques': {'total_paid_amount': 1200.00, 'total_unpaid_amount': 1200.00, 'total_active_students': 8}, 'Physique': {'total_paid_amount': 1200.00, 'total_unpaid_amount': 1200.00, 'total_active_students': 8}}}, 'Septième année de base': {'total_paid_amount': 1200.00, 'total_unpaid_amount': 1200.00, 'total_active_students': 8, 'subjects': {'Mathématiques': {'total_paid_amount': 1200.00, 'total_unpaid_amount': 1200.00, 'total_active_students': 8}}}, 'Sixième année primaire': {'total_paid_amount': 1600.00, 'total_unpaid_amount': 1600.00, 'total_active_students': 8, 'subjects': {'Mathématiques': {'total_paid_amount': 800.00, 'total_unpaid_amount': 800.00, 'total_active_students': 8}, 'Éveil scientifique': {'total_paid_amount': 800.00, 'total_unpaid_amount': 800.00, 'total_active_students': 8}}}, 'Première année primaire': {'total_paid_amount': 800.00, 'total_unpaid_amount': 800.00, 'total_active_students': 8, 'subjects': {'Mathématiques': {'total_paid_amount': 800.00, 'total_unpaid_amount': 800.00, 'total_active_students': 8}}}}}}

        if dashboard_data == expected_dashboard_data :
            print("    SUCCESSFUL TEST : LOADING DASHBOARD DATA WITH date_range=this_month")
        else : 
            print("    FAILED TEST : LOADING DASHBOARD DATA WITH date_range=this_month")
            print("    RETURNED DASHBOARD DATA:", dashboard_data) 

        # test this year
        dashboard_data = teacher_client.get_dashboard_data(date_range="this_year")
        expected_dashboard_data = {"has_levels":True,"dashboard":{'total_paid_amount': 13440.00, 'total_unpaid_amount': 13440.00, 'total_active_students': 72, 'levels': {'Quatrième année secondaire': {'total_paid_amount': 6240.00, 'total_unpaid_amount': 6240.00, 'total_active_students': 24, 'sections': {'Technique': {'total_paid_amount': 4320.00, 'total_unpaid_amount': 4320.00, 'total_active_students': 12, 'subjects': {'Mathématiques': {'total_paid_amount': 1920.00, 'total_unpaid_amount': 1920.00, 'total_active_students': 12}, 'Physique': {'total_paid_amount': 2400.00, 'total_unpaid_amount': 2400.00, 'total_active_students': 12}}}, 'Informatique': {'total_paid_amount': 1920.00, 'total_unpaid_amount': 1920.00, 'total_active_students': 12, 'subjects': {'Mathématiques': {'total_paid_amount': 1920.00, 'total_unpaid_amount': 1920.00, 'total_active_students': 12}}}}}, 'Huitième année de base': {'total_paid_amount': 2880.00, 'total_unpaid_amount': 2880.00, 'total_active_students': 12, 'subjects': {'Mathématiques': {'total_paid_amount': 1440.00, 'total_unpaid_amount': 1440.00, 'total_active_students': 12}, 'Physique': {'total_paid_amount': 1440.00, 'total_unpaid_amount': 1440.00, 'total_active_students': 12}}}, 'Septième année de base': {'total_paid_amount': 1440.00, 'total_unpaid_amount': 1440.00, 'total_active_students': 12, 'subjects': {'Mathématiques': {'total_paid_amount': 1440.00, 'total_unpaid_amount': 1440.00, 'total_active_students': 12}}}, 'Sixième année primaire': {'total_paid_amount': 1920.00, 'total_unpaid_amount': 1920.00, 'total_active_students': 12, 'subjects': {'Mathématiques': {'total_paid_amount': 960.00, 'total_unpaid_amount': 960.00, 'total_active_students': 12}, 'Éveil scientifique': {'total_paid_amount': 960.00, 'total_unpaid_amount': 960.00, 'total_active_students': 12}}}, 'Première année primaire': {'total_paid_amount': 960.00, 'total_unpaid_amount': 960.00, 'total_active_students': 12, 'subjects': {'Mathématiques': {'total_paid_amount': 960.00, 'total_unpaid_amount': 960.00, 'total_active_students': 12}}}}}}

        if dashboard_data == expected_dashboard_data :
            print("    SUCCESSFUL TEST : LOADING DASHBOARD DATA WITH date_range=this_year")
        else : 
            print("    FAILED TEST : LOADING DASHBOARD DATA WITH date_range=this_year")
            print("    RETURNED DASHBOARD DATA:", dashboard_data) 

        
        # test in a specific date range
        dashboard_data = teacher_client.get_dashboard_data(start_date="2025-08-10", end_date="2025-08-14")
        expected_dashboard_data = {"has_levels":True,"dashboard":{'total_paid_amount': 2240.00, 'total_unpaid_amount': 2240.00, 'total_active_students': 24, 'levels': {'Quatrième année secondaire': {'total_paid_amount': 1040.00, 'total_unpaid_amount': 1040.00, 'total_active_students': 8, 'sections': {'Technique': {'total_paid_amount': 720.00, 'total_unpaid_amount': 720.00, 'total_active_students': 4, 'subjects': {'Mathématiques': {'total_paid_amount': 320.00, 'total_unpaid_amount': 320.00, 'total_active_students': 4}, 'Physique': {'total_paid_amount': 400.00, 'total_unpaid_amount': 400.00, 'total_active_students': 4}}}, 'Informatique': {'total_paid_amount': 320.00, 'total_unpaid_amount': 320.00, 'total_active_students': 4, 'subjects': {'Mathématiques': {'total_paid_amount': 320.00, 'total_unpaid_amount': 320.00, 'total_active_students': 4}}}}}, 'Huitième année de base': {'total_paid_amount': 480.00, 'total_unpaid_amount': 480.00, 'total_active_students': 4, 'subjects': {'Mathématiques': {'total_paid_amount': 240.00, 'total_unpaid_amount': 240.00, 'total_active_students': 4}, 'Physique': {'total_paid_amount': 240.00, 'total_unpaid_amount': 240.00, 'total_active_students': 4}}}, 'Septième année de base': {'total_paid_amount': 240.00, 'total_unpaid_amount': 240.00, 'total_active_students': 4, 'subjects': {'Mathématiques': {'total_paid_amount': 240.00, 'total_unpaid_amount': 240.00, 'total_active_students': 4}}}, 'Sixième année primaire': {'total_paid_amount': 320.00, 'total_unpaid_amount': 320.00, 'total_active_students': 4, 'subjects': {'Mathématiques': {'total_paid_amount': 160.00, 'total_unpaid_amount': 160.00, 'total_active_students': 4}, 'Éveil scientifique': {'total_paid_amount': 160.00, 'total_unpaid_amount': 160.00, 'total_active_students': 4}}}, 'Première année primaire': {'total_paid_amount': 160.00, 'total_unpaid_amount': 160.00, 'total_active_students': 4, 'subjects': {'Mathématiques': {'total_paid_amount': 160.00, 'total_unpaid_amount': 160.00, 'total_active_students': 4}}}}}}
        if dashboard_data == expected_dashboard_data:
            print("    SUCCESSFUL TEST : LOADING DASHBOARD DATA WITH A SPECIFIC DATE RANGE")
        else:
            print("    FAILED TEST : LOADING DASHBOARD DATA WITH A SPECIFIC DATE RANGE")
            print("    RETURNED DASHBOARD DATA:", dashboard_data)

        

