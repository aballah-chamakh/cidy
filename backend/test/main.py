import os, sys
import django

from pathlib import Path

# Add the Django project directory to the Python path
current_dir = Path(__file__).resolve().parent
django_project_dir = current_dir.parent / "cidy"
sys.path.insert(0, str(django_project_dir))

# Set the DJANGO_SETTINGS_MODULE environment variable
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "cidy.settings")
django.setup()



# Start testing
from teacher_app.dashboard_views.get_dashboard_data import TestDateRangeFilter,TestNoClasses,TestNoTeacherSubjects,TestNoGroupEnrollments

def test_runner(test_class):
    test = test_class()
    test.set_up()
    test.test()

test_runner(TestNoClasses)
test_runner(TestNoTeacherSubjects)
test_runner(TestNoGroupEnrollments)
test_runner(TestDateRangeFilter)
