import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "cidy.settings")
django.setup()

from teacher.models import Level,Subject 

Level.objects.all().delete()
Subject.objects.all().delete()

levels_sections_subjects = {
    "Première année primaire" : {
        "subjects" : [
            "Éveil scientifique",
            "Mathématiques",
            "Arabe",
            "Lecture",
            "Dessin",
            "Musique",
            "Éducation physique",
            "Éducation technologique",
            "Éducation islamique",
            "Sport"
        ]
    },
    "Deuxième année primaire" : {
        "subjects" : [
            "Éveil scientifique",
            "Mathématiques",
            "Arabe",
            "Lecture",
            "Dessin",
            "Musique",
            "Éducation physique",
            "Éducation technologique",
            "Éducation islamique",
            "Sport"
        ]
    },
    "Troisième année primaire" : {
        "subjects" : [
            "Éveil scientifique",
            "Mathématiques",
            "Arabe",
            "Français",
            "Dessin",
            "Musique",
            "Éducation technologique",
            "Éducation infomatique",
            "Éducation physique",
            "Éducation islamique",
            "Lecture",
            "Sport"
        ]
    },
    "Quatrième année primaire" : {
        "subjects" : [
            "Éveil scientifique",
            "Mathématiques",
            "Arabe",
            "Français",
            "Dessin",
            "Musique",
            "Éducation technologique",
            "Éducation infomatique",
            "Éducation physique",
            "Éducation islamique",
            "Lecture",
            "Sport"
        ]
    },
    "Cinquième année primaire" : {
        "subjects" :  [
            "Éveil scientifique",
            "Mathématiques",
            "Arabe",
            "Français",
            "Dessin",
            "Musique",
            "Éducation technologique",
            "Éducation infomatique",
            "Éducation physique",
            "Histoire et géographie",
            "Éducation civique",
            "Éducation islamique",
            "Sport"
        ]
    },
    "Sixième année primaire" : {
        "subjects" : [
            "Anglais",
            "Éducation infomatique",
            "Éducation technologique",
            "Éducation physique",
            "Éducation islamique",
            "Histoire et géographie",
            "Éducation civique",
            "Mathématiques",
            "Éveil scientifique",
            "Français",
            "Arabe",
            "Sport"
        ]
    },
    "Septième année de base" : {
        "subjects" : [
            "Arabe",
            "Mathématiques",
            "Sciences de la vie et de la Terre",
            "Physique",
            "Histoire et géographie",
            "Éducation islamique",
            "Éducation technologique",
            "Anglais",
            "Français"
        ]
    },
    "Huitième année de base" : {
        "subjects" : [
            "Arabe",
            "Mathématiques",
            "Sciences de la vie et de la Terre",
            "Physique",
            "Histoire et géographie",
            "Éducation islamique",
            "Éducation technologique",
            "Anglais",
            "Français"
        ]
    },
    "Neuvième année de base" : {
        "subjects" : [
            "Arabe",
            "Mathématiques",
            "Sciences de la vie et de la Terre",
            "Physique",
            "Histoire et géographie",
            "Éducation islamique",
            "Éducation technologique",
            "Anglais",
            "Français"
        ]
    },
    "Première année secondaire" : {
        "sections" : {
            "Commun" : {
                "subjects" : [
                    "Arabe",
                    "Histoire et géographie",
                    "La pensée islamique",
                    "Éducation civique",
                    "Français",
                    "Anglais",
                    "Mathématiques",
                    "Physique",
                    "Sciences de la vie et de la Terre",
                    "Technologie"
                ]
            },
            "Sport" : {
                "subjects" : [
                    "Arabe",
                    "Mathématiques",
                    "Sciences biologiques"
                ]
            }

        }
    },
    "Deuxième année secondaire" : {
        "sections" : {
            "Lettre" : {
                "subjects" : [
                    "Arabe",
                    "Français",
                    "Anglais",
                    "Histoire et géographie",
                    "La pensée islamique",
                    "Éducation civique",
                    "Mathématiques",
                    "Sciences de la vie et de la Terre"
                ]
            },
            "Science" : {
                "subjects" : [
                    "Arabe",
                    "Français",
                    "Anglais",
                    "Histoire et géographie",
                    "Éducation civique",
                    "La pensée islamique",
                    "Mathématiques",
                    "Physique",
                    "Sciences de la vie et de la Terre",
                    "Technologie",
                    "Informatique"
                ]
            },
            "Economie" : {
                "subjects" : [
                    "Arabe",
                    "Français",
                    "Anglais",
                    "Histoire et géographie",
                    "Éducation civique",
                    "La pensée islamique",
                    "Mathématiques",
                    "Gestion",
                    "Economie",
                    "Informatique"
                ]
            },
           "Informatique" : {
                "subjects" : [
                    "Arabe",
                    "Français",
                    "Anglais",
                    "Histoire et géographie",
                    "Éducation civique",
                    "La pensée islamique",
                    "Mathématiques",
                    "Physique",
                    "Technologie",
                    "Informatique"
                ]
            },
            "Sport" : {
                "subjects" : [
                    "Arabe",
                    "Mathématiques",
                    "Sciences biologiques"
                ]
            }
        }
    },
    "Troisième année secondaire" : {
        "sections" : {
            "Lettre" : {
                "subjects" : [
                    "Arabe",
                    "Français",
                    "Anglais",
                    "Histoire et géographie",
                    "Éducation civique",
                    "La pensée islamique",
                    "Philosophie",
                    "Mathématiques",
                    "Informatique",
                    "Sciences de la vie et de la Terre",
                    "Italien",
                    "Allemand",
                    "Espagnol",
                    "Russe",
                    "Chinois"
                ]
            },
            "Economie" : {
                "subjects" : [
                    "Arabe",
                    "Français",
                    "Anglais",
                    "Histoire et géographie",
                    "Philosophie",
                    "Mathématiques",
                    "Gestion",
                    "Economie",
                    "Informatique",
                    "Italien",
                    "Allemand",
                    "Espagnol",
                    "Russe",
                    "Chinois"
                ]
            },
            "Mathématiques" : {
                "subjects" : [
                    "Arabe",
                    "Français",
                    "Anglais",
                    "Histoire et géographie",
                    "La pensée islamique",
                    "Philosophie",
                    "Mathématiques",
                    "Sciences de la vie et de la Terre",
                    "Physique",
                    "Informatique",
                    "Italien",
                    "Allemand",
                    "Espagnol",
                    "Russe",
                    "Chinois"
                ]
            },
            "Science experimentale" : {
                "subjects" : [
                    "Arabe",
                    "Français",
                    "Anglais",
                    "Histoire et géographie",
                    "La pensée islamique",
                    "Philosophie",
                    "Mathématiques",
                    "Sciences de la vie et de la Terre",
                    "Physique",
                    "Informatique",
                    "Italien",
                    "Allemand",
                    "Espagnol",
                    "Russe",
                    "Chinois"
                ]
            },
           "Technique" : {
               "subjects" : [
                   "Arabe",
                   "Français",
                   "Anglais",
                   "Histoire et géographie",
                   "Philosophie",
                   "Mathématiques",
                   "Physique",
                   "Mécanique",
                   "Electrique",
                   "Informatique"
               ]
           },
           "Informatique" : {
                "subjects" : [
                    "Arabe",
                    "Français",
                    "Anglais",
                    "Histoire et géographie",
                    "Philosophie",
                    "Mathématiques",
                    "Physique",
                    "Algorithmique et Programmation",
                    "Technologies de l'information et de la communication",
                    "Italien",
                    "Allemand",
                    "Espagnol",
                    "Russe",
                    "Chinois"
                ]
            },
            "Sport" : {
                "subjects" : [
                    "Arabe",
                    "Mathématiques",
                    "Sciences biologiques"
                ]
            }
        }
    },
    "Quatrième année secondaire" : {
        "sections" : {
            "Lettre" : {
                "subjects" : [
                    "Arabe",
                    "Français",
                    "Anglais",
                    "Histoire et géographie",
                    "La pensée islamique",
                    "Philosophie",
                    "Mathématiques",
                    "Informatique",
                    "Sciences de la vie et de la Terre",
                    "Italien",
                    "Allemand",
                    "Espagnol",
                    "Russe",
                    "Chinois"
                ]
            },
            "Economie" : {
                "subjects" : [
                    "Arabe",
                    "Français",
                    "Anglais",
                    "Histoire et géographie",
                    "Philosophie",
                    "Mathématiques",
                    "Economie",
                    "Gestion",
                    "Informatique",
                    "Italien",
                    "Allemand",
                    "Espagnol",
                    "Russe",
                    "Chinois"
                ]
            },
            "Mathématiques" : {
                "subjects" : [
                    "Arabe",
                    "Français",
                    "Anglais",
                    "Philosophie",
                    "Mathématiques",
                    "Physique",
                    "Sciences de la vie et de la Terre",
                    "Informatique",
                    "Italien",
                    "Allemand",
                    "Espagnol",
                    "Russe",
                    "Chinois"
                ]
            },
            "Science experimentale" : {
                "subjects" : [
                    "Arabe",
                    "Français",
                    "Anglais",
                    "Histoire et géographie",
                    "Philosophie",
                    "Mathématiques",
                    "Physique",
                    "Sciences de la vie et de la Terre",
                    "Informatique",
                    "Italien",
                    "Allemand",
                    "Espagnol",
                    "Russe",
                    "Chinois"
                ]
            },
           "Technique" : { 
               "subjects" : [
                   "Arabe",
                   "Français",
                   "Anglais",
                   "Philosophie",
                   "Mathématiques",
                   "Physique",
                   "Mécanique",
                   "Electrique",
                   "Informatique"
               ]
           },
           "Informatique" : {
                "subjects" : [
                    "Arabe",
                    "Français",
                    "Anglais",
                    "Philosophie",
                    "Mathématiques",
                    "Physique",
                    "Algorithmique et Programmation",
                    "Technologies de l'information et de la communication",
                    "Italien",
                    "Allemand",
                    "Espagnol",
                    "Russe",
                    "Chinois"
                ]
            },
            "Sport" : {
                "subjects" : [
                    "Arabe",
                    "Mathématiques",
                    "Sciences biologiques"
                ]
            }
        }
    }
}
order = 1 
for level_name, level_data in levels_sections_subjects.items():
    if "sections" in level_data:
        for section_name, section_data in level_data["sections"].items():
            level= Level.objects.create(name=level_name, section=section_name, order=order)
            for subject_name in section_data["subjects"]:
                subject,created = Subject.objects.get_or_create(name=subject_name)
                level.subjects.add(subject)
    else : 
        level = Level.objects.create(name=level_name, order=order)
        for subject_name in level_data["subjects"] :
            subject,created = Subject.objects.get_or_create(name=subject_name)
            level.subjects.add(subject)
    order += 1


import datetime
from account.models import User 
from teacher.models import Teacher,TeacherEnrollment, TeacherSubject,Level, Subject,Group, GroupEnrollment, Class
from student.models import Student

class TestDateRangeFilter:

    # Data summary : 
    # 1 teacher
    # 9 teacher subjects
    # for each teacher subject : 2 groups 
    # for each teacher subject  : 12 students created
    # for each group : 6 group enrollments (students), each 3 in a different time range 
    # for each group enrollment : 12 classes, 2 paid and 2 unpaid in each time range
    # time ranges : 
    #    - this week (1 Oct 2025)
    #    - this month (1 Oct 2025)
    #    - this year (10 and 14 Aug 2025)

    THIS_WEEK_DATES = [datetime.datetime(2025, 11, 12), datetime.datetime(2025, 11, 13)]
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
                        #self.create_classes_for_a_group_enrollment_in_different_status_and_date_ranges(group_enrollement)


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
                        #self.create_classes_for_a_group_enrollment_in_different_status_and_date_ranges(group_enrollement)
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

TestDateRangeFilter().set_up()