import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:cidy/config.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_layout.dart';
import 'package:intl/intl.dart';

class TeacherWeekScheduleScreen extends StatefulWidget {
  const TeacherWeekScheduleScreen({super.key});

  @override
  State<TeacherWeekScheduleScreen> createState() =>
      _TeacherWeekScheduleScreenState();
}

class _TeacherWeekScheduleScreenState extends State<TeacherWeekScheduleScreen> {
  bool _isLoading = true;
  late _AppointmentDataSource _dataSource;
  final PageController _pageController = PageController(
    initialPage: DateTime.now().weekday - 1,
  );
  DateTime? _startOfWeek;
  DateTime? _endOfWeek;
  static const Map<String, int> weekDayToNumber = {
    'Monday': 0,
    'Tuesday': 1,
    'Wednesday': 2,
    'Thursday': 3,
    'Friday': 4,
    'Saturday': 5,
    'Sunday': 6,
  };

  @override
  void initState() {
    super.initState();
    _dataSource = _AppointmentDataSource([]);
    _initializeWeekRange();
    _fetchGroups();
  }

  void _initializeWeekRange() {
    final now = DateTime.now();
    // Adjust to make Monday the first day of the week (weekday is 1-7, Monday-Sunday)
    int daysToSubtract = now.weekday - 1;
    _startOfWeek = DateTime(now.year, now.month, now.day - daysToSubtract);
    _endOfWeek = _startOfWeek!.add(const Duration(days: 6));
  }

  Future<void> _fetchGroups() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      final response = await http.get(
        Uri.parse('${Config.backendUrl}/api/teacher/week_schedule/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Fetched data: $data');
        final List<Appointment> appointments = [];
        if (data['groups'] is! List) {
          throw 'Invalid data format from server';
        }

        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

        for (var groupData in data['groups']) {
          final startTimeStr = groupData['start_time'];
          final endTimeStr = groupData['end_time'];
          final dayOfWeek = weekDayToNumber[groupData['week_day']];
          final startTime = TimeOfDay(
            hour: int.parse(startTimeStr.split(':')[0]),
            minute: int.parse(startTimeStr.split(':')[1]),
          );
          final endTime = TimeOfDay(
            hour: int.parse(endTimeStr.split(':')[0]),
            minute: int.parse(endTimeStr.split(':')[1]),
          );

          final eventDate = startOfWeek.add(Duration(days: dayOfWeek!));
          final startDateTime = DateTime(
            eventDate.year,
            eventDate.month,
            eventDate.day,
            startTime.hour,
            startTime.minute,
          );
          final endDateTime = DateTime(
            eventDate.year,
            eventDate.month,
            eventDate.day,
            endTime.hour,
            endTime.minute,
          );

          String section = groupData['section'] != null
              ? ' - ${groupData['section']['name']}'
              : '';
          String levelName = groupData['level']['name'] ?? 'N/A';
          String subjectName = groupData['subject']['name'] ?? 'N/A';
          String groupName = groupData['name'] ?? 'No Name';

          final subject = '$levelName$section\n$subjectName\n$groupName';

          final appointment = Appointment(
            startTime: startDateTime,
            endTime: endDateTime,
            subject: subject,
            id: groupData['id'].toString(),
            color: Theme.of(context).primaryColor,
          );
          appointments.add(appointment);
        }

        if (mounted) {
          setState(() {
            _dataSource = _AppointmentDataSource(appointments);
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to load schedule: ${response.reasonPhrase}',
              ),
            ),
          );
        }
      }
    } catch (e, stacktrace) {
      if (mounted) {
        print('An error occurred: $e');
        print(stacktrace);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TeacherLayout(
      title: 'Week Schedule',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.horizontal,
              itemCount: 7, // 7 days in a week
              itemBuilder: (context, index) {
                final day = _startOfWeek!.add(Duration(days: index));
                final dailyAppointments = _dataSource.appointments
                    ?.where((appointment) {
                      final app = appointment as Appointment;
                      return app.startTime.year == day.year &&
                          app.startTime.month == day.month &&
                          app.startTime.day == day.day;
                    })
                    .cast<Appointment>()
                    .toList();

                final dailyDataSource = _AppointmentDataSource(
                  dailyAppointments ?? [],
                );

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        DateFormat('EEEE, MMMM d').format(day),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Expanded(
                      child: Listener(
                        onPointerMove: (pointerMoveEvent) {
                          if (pointerMoveEvent.delta.dx.abs() >
                              pointerMoveEvent.delta.dy.abs()) {
                            _pageController.position.jumpTo(
                              _pageController.position.pixels -
                                  pointerMoveEvent.delta.dx,
                            );
                          }
                        },
                        child: SfCalendar(
                          view: CalendarView.day,
                          dataSource: dailyDataSource,
                          initialDisplayDate: day,
                          allowDragAndDrop: false,
                          minDate: _startOfWeek,
                          maxDate: _endOfWeek,
                          firstDayOfWeek: 1, // Monday
                          timeSlotViewSettings: const TimeSlotViewSettings(
                            startHour: 8,
                            endHour: 24,
                            nonWorkingDays: <int>[
                              DateTime.saturday,
                              DateTime.sunday,
                            ],
                          ),
                          viewNavigationMode: ViewNavigationMode.none,
                          headerHeight: 0,
                          viewHeaderHeight: 0,
                          appointmentBuilder:
                              (context, calendarAppointmentDetails) {
                                final appointment =
                                    calendarAppointmentDetails
                                            .appointments
                                            .first
                                        as Appointment;
                                return Container(
                                  decoration: BoxDecoration(
                                    color: appointment.color,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: Text(
                                    appointment.subject,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 3,
                                  ),
                                );
                              },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _AppointmentDataSource extends CalendarDataSource {
  _AppointmentDataSource(List<Appointment> source) {
    appointments = source;
  }
}
