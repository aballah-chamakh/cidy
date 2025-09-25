import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "cidy.settings")
django.setup()

from teacher.models import Subject, Level, Section
from teacher.models import Teacher, Group, TeacherSubject, Level, Section, Subject, GroupEnrollment, Class
from student.models import Student
from account.models import User
from datetime import datetime
from datetime import datetime, date
from datetime import datetime, time

# ADD DATA TO TEST THE GET DASHBOARD DATA VIEW
# Use the existing teacher with the email "teacher10@gmail.com"

Student.objects.all().delete()
Group.objects.all().delete()
Level.objects.all().delete()
User.objects.filter(email__in=["student70@gmail.com", "student60@gmail.com", "student50@gmail.com"]).delete()


teacher = Teacher.objects.get(user__email="teacher10@gmail.com")
# Create some students

# Get existing levels and subjects
primary_first_level = Level.objects.create(name="Première année primaire")
bac_level = Level.objects.create(name="Quatrième année secondaire")
technology_section = Section.objects.create(name="Technique", level=bac_level)
bac_math_subject = Subject.objects.create(level=bac_level,section=technology_section,name="Mathématiques")
primary_first_math_subject = Subject.objects.create(level=primary_first_level,name="Mathématiques")

# Create some test users and students
user1 = User.objects.create_user(email="student70@gmail.com", password="password123",phone_number="12345678")
user2 = User.objects.create_user(email="student60@gmail.com", password="password123",phone_number="87654321")
user3 = User.objects.create_user(email="student50@gmail.com", password="password123",phone_number="11223344")

student1 = Student.objects.create(
    user=user1,
    fullname="Ahmed Ben Ali",
    phone_number="12345678",
    gender="M",
    level=bac_level,
    section=technology_section
)

student2 = Student.objects.create(
    user=user2,
    fullname="Fatma Trabelsi",
    phone_number="87654321",
    gender="F",
    level=primary_first_level
)

student3 = Student.objects.create(
    user=user3,
    fullname="Mohamed Sassi",
    phone_number="11223344",
    gender="M",
    level=bac_level,
    section=technology_section
)

# Get teacher subjects for this teacher
bac_level_teacher_subject = TeacherSubject.objects.create(teacher=teacher,
                                                level=bac_level,
                                                section=technology_section,
                                                subject=bac_math_subject,
                                                price_per_class=20)
primary_first_level_teacher_subject = TeacherSubject.objects.create(teacher=teacher,
                                                level=primary_first_level,
                                                section=None,
                                                subject=primary_first_math_subject,
                                                price_per_class=15)

# Get the groups
bac_group = Group.objects.create(teacher=teacher, 
                              name="Groupe de mathématiques - Bac - Technique", 
                              teacher_subject=bac_level_teacher_subject,
                              week_day="Monday",
                              start_time="10:00",
                              end_time="12:00")
primary_group = Group.objects.create(teacher=teacher, 
                              name="Groupe de mathématiques - Première année - Primaire", 
                              teacher_subject=primary_first_level_teacher_subject,
                              week_day="Tuesday",
                              start_time="09:00",
                              end_time="11:00")
# Create group enrollments
enrollment1 = GroupEnrollment.objects.create(
    student=student1,
    group=bac_group,
    date=date(2024, 1, 15)
)

enrollment2 = GroupEnrollment.objects.create(
    student=student2,
    group=primary_group,
    date=date(2024, 1, 10)
)

enrollment3 = GroupEnrollment.objects.create(
    student=student3,
    group=bac_group,
    date=date(2024, 1, 20)
)

# Create some classes with different statuses

# Classes for student1 in bac group (some paid, some unpaid)
Class.objects.create(
    group_enrollment=enrollment1,
    status='attended_and_paid',
    attendance_date=date(2024, 2, 5),
    attendance_start_time=time(10, 0),
    attendance_end_time=time(12, 0),
    last_status_date=datetime(2024, 2, 5, 14, 0)
)

Class.objects.create(
    group_enrollment=enrollment1,
    status='attended_and_paid',
    attendance_date=date(2024, 2, 12),
    attendance_start_time=time(10, 0),
    attendance_end_time=time(12, 0),
    last_status_date=datetime(2024, 2, 12, 14, 0)
)

Class.objects.create(
    group_enrollment=enrollment1,
    status='attended_and_the_payment_due',
    attendance_date=date(2024, 2, 19),
    attendance_start_time=time(10, 0),
    attendance_end_time=time(12, 0),
    last_status_date=datetime(2024, 2, 19, 14, 0)
)

# Classes for student2 in primary group
Class.objects.create(
    group_enrollment=enrollment2,
    status='attended_and_paid',
    attendance_date=date(2024, 2, 6),
    attendance_start_time=time(9, 0),
    attendance_end_time=time(11, 0),
    last_status_date=datetime(2024, 2, 6, 12, 0)
)

Class.objects.create(
    group_enrollment=enrollment2,
    status='attended_and_the_payment_due',
    attendance_date=date(2024, 2, 13),
    attendance_start_time=time(9, 0),
    attendance_end_time=time(11, 0),
    last_status_date=datetime(2024, 2, 13, 12, 0)
)

# Classes for student3 in bac group
Class.objects.create(
    group_enrollment=enrollment3,
    status='attended_and_paid',
    attendance_date=date(2024, 2, 5),
    attendance_start_time=time(10, 0),
    attendance_end_time=time(12, 0),
    last_status_date=datetime(2024, 2, 5, 14, 0)
)

Class.objects.create(
    group_enrollment=enrollment3,
    status='attended_and_the_payment_due',
    attendance_date=date(2024, 2, 12),
    attendance_start_time=time(10, 0),
    attendance_end_time=time(12, 0),
    last_status_date=datetime(2024, 2, 12, 14, 0)
)

print("Test data created successfully!")
print(f"Created {Student.objects.count()} students")
print(f"Created {GroupEnrollment.objects.count()} group enrollments")
print(f"Created {Class.objects.count()} classes")



quit()
# ADD TEACHER SUBJECTS TO A PATICULAR TEACHER
from teacher.models import Teacher, TeacherSubject,Group,Level, Section, Subject
teacher = Teacher.objects.get(user__email="teacher10@gmail.com")

# add teacher subjects for teacher10
first_primary_level = Level.objects.get(name="Première année primaire")
bac_level = Level.objects.get(name="Quatrième année secondaire")
technology_section = Section.objects.get(name="Technique", level=bac_level)
math_subject = Subject.objects.get(name="Mathématiques", level=bac_level, section=technology_section)
bac_level_teacher_subject = TeacherSubject.objects.create(teacher=teacher,
                                                level=bac_level,
                                                section=technology_section,
                                                subject=math_subject,
                                                price_per_class=20)
first_primary_level_teacher_subject = TeacherSubject.objects.create(teacher=teacher,
                                                level=first_primary_level,
                                                section=None,
                                                subject=Subject.objects.get(name="Mathématiques", level=first_primary_level),
                                                price_per_class=15)

# Create groups for teacher10
group1 = Group.objects.create(teacher=teacher, 
                              name="Groupe de mathématiques - Bac - Technique", 
                              teacher_subject=bac_level_teacher_subject,
                              week_day="Monday",
                              start_time="10:00",
                              end_time="12:00")
group2 = Group.objects.create(teacher=teacher, 
                              name="Groupe de mathématiques - Première année - Primaire", 
                              teacher_subject=first_primary_level_teacher_subject,
                              week_day="Tuesday",
                              start_time="09:00",
                              end_time="11:00")

quit()
# Setup the sections, levels and subjects


Level.objects.all().delete()

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

for level_name, level_data in levels_sections_subjects.items():
    print("adding level", level_name)
    level = Level.objects.create(name=level_name)
    if 'sections' in level_data:
        for section_name, section_data in level_data['sections'].items():
            print("    adding section", section_name)
            section = Section.objects.create(name=section_name, level=level)
            for subject_name in section_data['subjects'] :
                print("        adding subject", subject_name)
                subject = Subject.objects.create(name=subject_name, level=level, section=section)
    elif 'subjects' in level_data:
        for subject_name in level_data['subjects']:
            print("    adding subject", subject_name)
            subject = Subject.objects.create(name=subject_name, level=level)