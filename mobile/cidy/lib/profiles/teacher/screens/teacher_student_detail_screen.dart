import 'package:cidy/app_styles.dart';
import 'package:cidy/models/student.dart';
import 'package:cidy/profiles/teacher/providers/teacher_api_provider.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_layout.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

class TeacherStudentDetailScreen extends StatefulWidget {
  final int studentId;

  const TeacherStudentDetailScreen({super.key, required this.studentId});

  @override
  State<TeacherStudentDetailScreen> createState() =>
      _TeacherStudentDetailScreenState();
}

class _TeacherStudentDetailScreenState
    extends State<TeacherStudentDetailScreen> {
  late Future<TeacherStudent> _studentFuture;
  TeacherStudent? _student;
  Group? _selectedGroup;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _studentFuture = _fetchStudentDetails();
  }

  Future<TeacherStudent> _fetchStudentDetails() async {
    try {
      final student = await Provider.of<TeacherApiProvider>(
        context,
        listen: false,
      ).getStudentDetails(widget.studentId);
      setState(() {
        _student = student;
        if (_student!.groups.isNotEmpty) {
          _selectedGroup = _student!.groups.first;
        }
      });
      return student;
    } catch (e) {
      // Handle error appropriately
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TeacherLayout(
      title: "Student",
      body: FutureBuilder<TeacherStudent>(
        future: _studentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (_student == null) {
            return const Center(child: Text("Student not found."));
          }
          return _buildStudentDetails();
        },
      ),
    );
  }

  Widget _buildKpiCard(String value, String label, Color valueColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(label, style: AppStyles.body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfileSection(),
          const SizedBox(height: 20),
          _buildOverallFinanceSection(),
          const SizedBox(height: 20),
          _buildGroupSection(),
          if (_selectedGroup != null) ...[
            const SizedBox(height: 20),
            _buildGroupFinanceSection(),
            const SizedBox(height: 20),
            _buildCalendarSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: NetworkImage(_student!.image),
        ),
        const SizedBox(height: 10),
        Text(_student!.fullname, style: AppStyles.title),
        const SizedBox(height: 5),
        Text(
          '${_student!.level}${_student!.section.isNotEmpty ? ' - ${_student!.section}' : ''}',
          style: AppStyles.body,
        ),
        const SizedBox(height: 5),
        Text(_student!.phoneNumber, style: AppStyles.body),
      ],
    );
  }

  Widget _buildOverallFinanceSection() {
    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            '\$${_student!.paidAmount.toStringAsFixed(2)}',
            'Paid',
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildKpiCard(
            '\$${_student!.unpaidAmount.toStringAsFixed(2)}',
            'Unpaid',
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildGroupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Group", style: AppStyles.label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: DropdownButton<Group>(
            value: _selectedGroup,
            isExpanded: true,
            underline: const SizedBox(),
            onChanged: (Group? newValue) {
              setState(() {
                _selectedGroup = newValue;
              });
            },
            items: _student!.groups.map<DropdownMenuItem<Group>>((Group group) {
              return DropdownMenuItem<Group>(
                value: group,
                child: Text(group.label),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupFinanceSection() {
    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            '\$${_selectedGroup!.paidAmount.toStringAsFixed(2)}',
            '${_selectedGroup!.name} - Paid',
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildKpiCard(
            '\$${_selectedGroup!.unpaidAmount.toStringAsFixed(2)}',
            '${_selectedGroup!.name} - Unpaid',
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarSection() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TableCalendar(
        focusedDay: _focusedDay,
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        eventLoader: _getEventsForDay,
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isNotEmpty) {
              return Positioned(
                right: 1,
                bottom: 1,
                child: _buildEventsMarker(date, events),
              );
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildEventsMarker(DateTime date, List events) {
    final classEvent = events.first as ClassEvent;
    return Tooltip(
      message: classEvent.tooltip,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: classEvent.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  List<ClassEvent> _getEventsForDay(DateTime day) {
    List<ClassEvent> events = [];
    if (_selectedGroup == null) return events;

    // Add existing classes
    for (var cls in _selectedGroup!.classes) {
      DateTime? classDate;
      if (cls.status != 'absent' && cls.attendanceDate != null) {
        classDate = cls.attendanceDate;
      } else if (cls.status == 'absent' && cls.absenceDate != null) {
        classDate = cls.absenceDate;
      }

      if (classDate != null && isSameDay(classDate, day)) {
        events.add(ClassEvent.fromClass(context, cls));
      }
    }

    // Add future placeholders
    if (day.isAfter(DateTime.now())) {
      final weekDays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      if (weekDays[day.weekday - 1] == _selectedGroup!.weekDay) {
        // Check if a class already exists on this day
        bool classExists = _selectedGroup!.classes.any(
          (c) => c.attendanceDate != null && isSameDay(c.attendanceDate!, day),
        );
        if (!classExists) {
          events.add(ClassEvent.forFutureClass(day, _selectedGroup!));
        }
      }
    }

    return events;
  }
}

class ClassEvent {
  final Color color;
  final String tooltip;

  ClassEvent({required this.color, required this.tooltip});

  factory ClassEvent.fromClass(BuildContext context, Class cls) {
    Color color;
    String statusText = '';
    String attendanceInfo = '';
    String paymentInfo = '';

    switch (cls.status) {
      case 'attended_and_paid':
        color = Colors.green;
        statusText = 'Attended & Paid';
        if (cls.attendanceDate != null &&
            cls.attendanceStartTime != null &&
            cls.attendanceEndTime != null) {
          attendanceInfo =
              'Attended on ${DateFormat('dd/MM/yyyy').format(cls.attendanceDate!)} from ${cls.attendanceStartTime!.format(context)} to ${cls.attendanceEndTime!.format(context)}';
        }
        if (cls.paidAt != null) {
          paymentInfo =
              'Paid on ${DateFormat('dd/MM/yyyy \'at\' HH:mm').format(cls.paidAt!)}';
        }
        break;
      case 'attended_and_the_payment_due':
        color = Colors.red;
        statusText = 'Attended & Payment Due';
        if (cls.attendanceDate != null &&
            cls.attendanceStartTime != null &&
            cls.attendanceEndTime != null) {
          attendanceInfo =
              'Attended on ${DateFormat('dd/MM/yyyy').format(cls.attendanceDate!)} from ${cls.attendanceStartTime!.format(context)} to ${cls.attendanceEndTime!.format(context)}';
        }
        break;
      case 'attended_and_the_payment_not_due':
        color = Colors.orange;
        statusText = 'Attended & Payment Not Due';
        if (cls.attendanceDate != null &&
            cls.attendanceStartTime != null &&
            cls.attendanceEndTime != null) {
          attendanceInfo =
              'Attended on ${DateFormat('dd/MM/yyyy').format(cls.attendanceDate!)} from ${cls.attendanceStartTime!.format(context)} to ${cls.attendanceEndTime!.format(context)}';
        }
        break;
      case 'absent':
        color = Colors.grey[600]!;
        statusText = 'Absent';
        if (cls.absenceDate != null &&
            cls.absenceStartTime != null &&
            cls.absenceEndTime != null) {
          attendanceInfo =
              'Absent on ${DateFormat('dd/MM/yyyy').format(cls.absenceDate!)} from ${cls.absenceStartTime!.format(context)} to ${cls.absenceEndTime!.format(context)}';
        }
        break;
      default:
        color = Colors.transparent;
    }

    String tooltip = statusText;
    if (attendanceInfo.isNotEmpty) tooltip += '\n$attendanceInfo';
    if (paymentInfo.isNotEmpty) tooltip += '\n$paymentInfo';

    return ClassEvent(color: color, tooltip: tooltip);
  }

  factory ClassEvent.forFutureClass(DateTime date, Group group) {
    String timeFormat(String time) {
      final parts = time.split(':');
      return '${parts[0]}:${parts[1]}';
    }

    final startTime = timeFormat(group.startTime);
    final endTime = timeFormat(group.endTime);

    return ClassEvent(
      color: Colors.grey[400]!,
      tooltip:
          'Future Class\nScheduled on ${DateFormat('dd/MM/yyyy').format(date)} from $startTime to $endTime',
    );
  }
}
