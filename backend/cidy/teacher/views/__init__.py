from .dashboard_views import get_dashboard_data
from .week_schedule_views import get_week_schedule, update_group_schedule
from .notifications_views import (
    get_unread_notifications_count,
    mark_notifications_as_read,
    get_notifications,
    get_new_notifications,
    mark_a_notification_as_read,
    student_request_accept_form_data,
    accept_student_request,
    reject_student_request,
    parent_request_accept_form_data,
    accept_parent_request,
    decline_parent_request
)

from .groups_views import (
    can_create_group, get_groups, 
    create_group, delete_groups, 
    get_group_details, edit_group, get_group_students,
    create_group_student,get_the_possible_students_for_a_group,add_students_to_group,remove_students_from_group,
    mark_attendance, unmark_attendance,
    mark_absence, unmark_absence,
    mark_payment, unmark_payment
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

from .account_views import (
    get_account_info,
    update_account_info,
    change_password
)