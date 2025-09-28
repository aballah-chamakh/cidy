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


# Add the super user if he does not exist
from account.models import User
if not User.objects.filter(email="chamakhabdallah8@gmail.com").exists():
    User.objects.create_superuser("chamakhabdallah8@gmail.com","58671414", "cidy1234",)

# Start testing


from teacher_tests import TestDashboardViews

test = TestDashboardViews()
teachers = test.get_teachers()
print(teachers)