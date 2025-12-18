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
from teacher_app.week_schedule_views.get_week_schedule import TestListingWeekSchedule
from teacher_app.group_views import TestMarkPayment, TestMarkAttendance,TestUnMarkAttendance, TestMarkAbsence, TestUnMarkAbsence, TestUnMarkPayment,TestMarkAttendanceAndPayment


def test_runner(test_class):
    test = test_class()
    test.set_up()
    test.test()


test_runner(TestDateRangeFilter)
quit()

test_runner(TestMarkAttendance)
test_runner(TestUnMarkAttendance)
test_runner(TestMarkAbsence)
test_runner(TestUnMarkAbsence)
test_runner(TestMarkPayment)
test_runner(TestUnMarkPayment)
test_runner(TestMarkAttendanceAndPayment)
test_runner(TestDateRangeFilter)

quit()

test_runner(TestDateRangeFilter)
quit()
test_runner(TestListingWeekSchedule)
quit()

#test_runner(TestMarkPayment)

test_runner(TestDateRangeFilter)
test_runner(TestNoClasses)
test_runner(TestNoTeacherSubjects)
test_runner(TestNoGroupEnrollments)
