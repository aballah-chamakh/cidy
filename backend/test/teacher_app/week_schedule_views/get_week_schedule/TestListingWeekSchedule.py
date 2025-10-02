import datetime
from account.models import User 
from teacher.models import Teacher, TeacherSubject,Level, Section, Subject,Group

class TestListingWeekSchedule: 
    WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

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

        clear_temporary_schedule_at = datetime.date.today() + datetime.timedelta(days=10)
        clear_temporary_schedule_expired = datetime.date.today()
        for idx,ts in enumerate(teacher_subjects[:7]): 
            group = Group.objects.create( 
                    teacher=teacher,
                    teacher_subject=ts,
                    week_day=TestListingWeekSchedule.WEEKDAYS[idx],
                    start_time="10:00",
                    end_time="12:00",
                    name="Group A") 
            
            group = Group.objects.create( 
                    teacher=teacher,
                    teacher_subject=ts,
                    week_day=TestListingWeekSchedule.WEEKDAYS[idx],
                    start_time="14:00",
                    end_time="16:00",
                    temporary_week_day=TestListingWeekSchedule.WEEKDAYS[idx],
                    temporary_start_time="12:00",
                    temporary_end_time="15:00",
                    clear_temporary_schedule_at = clear_temporary_schedule_expired if idx % 2 == 0 else clear_temporary_schedule_at,
                    name=f"Groupe B")
            
            group = Group.objects.create( 
                    teacher=teacher,
                    teacher_subject=ts,
                    week_day=TestListingWeekSchedule.WEEKDAYS[idx],
                    start_time="20:00",
                    end_time="22:00",
                    name=f"Groupe C")

    def test(self):
        pass 