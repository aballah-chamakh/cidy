from .teacher_views import (get_tes_levels_sections_subjects,
                            get_teachers, parenting_request_form_data,
                            send_parenting_request)

from .son_views import (get_parent_sons, get_son_detail, get_son_subject_detail, edit_a_son, create_a_son)
from .notification_views import get_unread_notifications_count,mark_notifications_as_read,get_notifications,get_new_notifications
from .account_views import (get_account_info, update_account_info, change_password)