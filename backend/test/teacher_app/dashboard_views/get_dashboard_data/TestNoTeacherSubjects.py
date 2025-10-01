from account.models import User 
from teacher.models import Teacher,Level
from teacher_app.TeacherClient import TeacherClient


class TestNoTeacherSubjects:

    # Data summary : 
    # 1 teacher
    def set_up(self):
        User.objects.all().delete()
        Level.objects.all().delete()
        User.objects.create_superuser("chamakhabdallah8@gmail.com","58671414", "cidy1234")
        # Create a teacher 
        user  = User.objects.create_user("teacher10@gmail.com", "44558866", "iloveuu")
        teacher = Teacher.objects.create(user=user,fullname="teacher10",gender="M")

    def test(self):
        print("START TESTING LOADING DASHBOARD DATA WITH NO TEACHER SUBJECTS :")
        teacher_client = TeacherClient("teacher10@gmail.com","iloveuu")
        teacher_client.authenticate() 
        
        dashboard_data = teacher_client.get_dashboard_data()

        expected_dashboard_data = {'has_levels': False}
        
        if dashboard_data == expected_dashboard_data:
            print("    SUCCESSFUL TEST : LOADING DASHBOARD DATA WITH NO TEACHER SUBJECTS")
        else : 
            print("    FAILED TEST : LOADING DASHBOARD DATA WITH NO TEACHER SUBJECTS")
            print("    RETURNED DASHBOARD DATA:", dashboard_data)
    