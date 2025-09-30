from account.models import User 
from teacher.models import Teacher


class TestNoTeacherSubjects:

    # Data summary : 
    # 1 teacher
    def set_up(self):
        # Create a teacher 
        user  = User.objects.create_user("teacher10@gmail.com", "44558866", "iloveuu")
        teacher = Teacher.objects.create(user=user,fullname="teacher10",gender="M")

    def test():
        pass
    