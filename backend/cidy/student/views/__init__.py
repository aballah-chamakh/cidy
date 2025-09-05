from .teacher_views import get_teachers,send_a_student_request
from .subject_views import get_student_subject_list,get_subject_detail
from .notification_views import get_unread_notifications_count,mark_notifications_as_read,get_notifications,get_new_notifications
from .account_views import (
    get_account_info,
    update_account_info,
    change_password,
    get_incompatible_groups_with_the_new_level_and_section
)
from .parent_views import get_student_parents 