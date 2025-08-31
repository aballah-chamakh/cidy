from .dashboard_views import get_dashboard_data
from .week_schedule_views import get_week_schedule, update_group_schedule
from .notifications_views import get_unread_notifications_count, reset_notification_count
from .groups_views import (
    can_create_group, get_groups, 
    create_group, delete_groups, 
    get_group_details, edit_group,get_group_students,
    create_group_student,add_students_to_group,
    mark_attendance,unmark_attendance,
    mark_absence,unmark_absence,
    mark_payment,unmark_payment,
)
from .students_views import (
    can_create_student,
    get_students,
    create_student,
    delete_students,
    get_student_details,
    mark_attendance_of_a_student,
    unmark_attendance_of_a_student,
    mark_absence_of_a_student,
    unmark_absence_of_a_student,
    mark_payment_of_a_student,
    unmark_payment_of_a_student
)

from .prices_views import (
    prices_list,
    add_teacher_subject,
    edit_teacher_subject_price,
    delete_level_section_subject
)