import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "cidy.settings")
django.setup()

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
from teacher.models import Subject, Level, Section

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