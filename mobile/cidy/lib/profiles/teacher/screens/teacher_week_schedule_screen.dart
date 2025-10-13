import 'dart:convert';
import 'package:cidy/app_styles.dart';
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

          String levelName = groupData['level'];
          String subjectName = groupData['subject'];
          String groupName = groupData['name'];
          bool temporarySchedule = groupData['temporary_schedule'] ?? false;

          String subject = '$levelName\n';
          subject += '$subjectName\n';
          subject += '$groupName';
          if (temporarySchedule) {
            subject += '\n(Temporaire)';
          }

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
      title: 'Planning de la semaine',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
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
                        DateFormat('EEEE, d MMMM', 'fr_FR').format(day),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final availableHeight = constraints.maxHeight;
                          const double startHour = 8;
                          const double endHour = 24;
                          // The calendar displays time slots for each hour.
                          final double numberOfHours = endHour - startHour;

                          // Calculate the height for each time slot to fill the available space.
                          // We subtract a small amount (e.g., 1) to account for borders/dividers
                          // to prevent the calendar from becoming scrollable due to a single pixel overflow.
                          final double calculatedIntervalHeight =
                              (availableHeight - 1) / numberOfHours;

                          // Ensure the height is at least 40, as requested.
                          final double finalIntervalHeight =
                              calculatedIntervalHeight > 40
                              ? calculatedIntervalHeight
                              : 40;

                          return Listener(
                            onPointerMove: (PointerMoveEvent event) {
                              // Check if the primary movement is horizontal
                              if (event.delta.dx.abs() > event.delta.dy.abs()) {
                                // Manually adjust the PageView's position
                                _pageController.position.jumpTo(
                                  _pageController.position.pixels -
                                      event.delta.dx,
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
                              timeSlotViewSettings: TimeSlotViewSettings(
                                startHour: startHour,
                                endHour: endHour,
                                timeIntervalHeight: finalIntervalHeight,
                                nonWorkingDays: const <int>[],
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
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.vertical,
                                        child: Text(
                                          appointment.subject,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                            ),
                          );
                        },
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
