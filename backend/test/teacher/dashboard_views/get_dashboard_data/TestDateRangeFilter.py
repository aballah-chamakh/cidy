from account.models import User 
from teacher.models import Teacher, TeacherSubject,Level, Section, Subject,Group

class TestDateRangeFilter:

    def set_up(self):
        # Create a teacher 
        user  = User.objects.create_user("teacher10@gmail.com", "44558866", "iloveuu")
        teacher = Teacher.objects.create(user=user,fullname="teacher10",geneder="M")

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

        # add related records to each teacher subject
        for teacher_subject in teacher_subjects:
            # add 2 groups for each teacher subject
            for group_name in ["A", "B"]:
                group = Group.objects.create(
                                    teacher=teacher,
                                    teacher_subject=teacher_subject,
                                    week_day="Saturday",
                                    start_time="18:00",
                                    end_time="20:00",
                                    name=f"{teacher_subject.level.name} {teacher_subject.section.name if teacher_subject.section else ''} {teacher_subject.subject.name} ({group_name})")


        # 

    def test():
        pass
    