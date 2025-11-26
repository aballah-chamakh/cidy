import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:cidy/authentication/login.dart';
import 'package:cidy/profiles/widgets/profile_appbar.dart';
import 'package:cidy/profiles/widgets/profile_sidebar.dart';
import 'package:cidy/profiles/models/sidebar_menu_item.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cidy/config.dart';
import 'package:cidy/route_observer.dart';
import 'package:cidy/profiles/teacher/screens/teacher_dashboard_screen.dart';
import 'package:cidy/profiles/teacher/screens/teacher_groups_screen.dart';
import 'package:cidy/profiles/teacher/screens/teacher_week_schedule_screen.dart';
import 'package:cidy/profiles/teacher/screens/teacher_students_screen.dart';
import 'package:cidy/profiles/teacher/screens/teacher_subjects_screen.dart';
import 'package:cidy/profiles/teacher/screens/teacher_account_screen.dart';

import 'package:cidy/app_state.dart';

typedef TeacherBodyBuilder =
    Widget Function({Future<void> Function()? reloadTeacherInfo});

class TeacherLayout extends StatefulWidget {
  final Widget? body;
  final TeacherBodyBuilder? bodyBuilder;
  final String title;

  const TeacherLayout({
    super.key,
    required this.title,
    this.body,
    this.bodyBuilder,
  }) : assert(
         body != null || bodyBuilder != null,
         'Provide either body or bodyBuilder',
       );

  @override
  State<TeacherLayout> createState() => _TeacherLayoutState();
}

class _TeacherLayoutState extends State<TeacherLayout> with RouteAware {
  String _teacherFullName = '';
  String _teacherImageUrl = '';
  String _teacherEmail = '';
  int _notificationCount = 0;
  Timer? _notificationCountUpdaterTimer;

  @override
  void initState() {
    super.initState();
    /*
    setState(() {
      _notificationCount = AppState.notificationCount;
    });*/
    _loadTeacherInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  Future<void> _loadTeacherInfo() async {
    // Load teacher info from local storage using SharedPreferences
    const storage = FlutterSecureStorage();

    final teacherfullName = await storage.read(key: 'fullname');
    final teacherImageUrl = await storage.read(key: 'image_url');
    final teacherEmail = await storage.read(key: 'email');
    if (!mounted) return;

    setState(() {
      _teacherFullName = teacherfullName!;
      _teacherImageUrl = teacherImageUrl!;
      _teacherEmail = teacherEmail!;
    });
  }

  /*
  Future<void> _updateNotificationCount() async {
    // Replace with your API call to fetch unread notification count
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    final response = await http.get(
      Uri.parse('${Config.backendUrl}/api/teacher/notifications/unread_count/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (!mounted) return;

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        // Assuming the API returns {"unread_count": 5}
        _notificationCount = data['unread_count'];
        AppState.notificationCount = _notificationCount;
      });
    } else if (response.statusCode == 401) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }


  void _startNotificationCountUpdater() {
    const duration = Duration(seconds: 5); // Update every 30 seconds

    // Start periodic updates

    _notificationCountUpdaterTimer = Timer.periodic(duration, (Timer timer) {
      _updateNotificationCount();
    });
  }

  void _stopNotificationCountUpdater() {
    if (_notificationCountUpdaterTimer != null) {
      _notificationCountUpdaterTimer!.cancel();
      _notificationCountUpdaterTimer = null;
    }
  }

  // -------- RouteAware Callbacks --------
  @override
  void didPush() {
    // This screen was just pushed onto the stack
    _startNotificationCountUpdater();
  }

  @override
  void didPop() {
    // This screen is being popped off
    _stopNotificationCountUpdater();
  }

  @override
  void didPushNext() {
    // Another screen has been pushed on top of this one
    _stopNotificationCountUpdater();
  }

  @override
  void didPopNext() {
    // The screen above this one was popped, revealing this screen again
    _startNotificationCountUpdater();
  }
*/
  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    // _stopNotificationCountUpdater();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: ProfileAppBar(
        title: widget.title,
        notificationCount: _notificationCount,
        onNotificationTap: () {
          // Handle notification tap
          print("Notification tapped");
        },
      ),
      drawer: ProfileSidebar(
        email: _teacherEmail,
        fullName: _teacherFullName,
        imageUrl: _teacherImageUrl,
        menuItems: [
          SidebarMenuItem(
            label: "Tableau de bord",
            icon: Icons.dashboard,
            onTap: () {
              // Navigate to the dashboard screen
              if (ModalRoute.of(context)?.settings.name ==
                  '/teacher_dashboard') {
                // Navigator.of(context).pop(); // Just close the drawer
                return; // Already on the dashboard
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    settings: RouteSettings(name: '/teacher_dashboard'),
                    builder: (context) => const TeacherDashboardScreen(),
                  ),
                );
              }
            },
          ),
          SidebarMenuItem(
            label: "Planning de la semaine",
            icon: Icons.calendar_today,
            onTap: () {
              // Navigate to the week schedule screen
              if (ModalRoute.of(context)?.settings.name ==
                  '/teacher_week_schedule') {
                //Navigator.of(context).pop(); // Just close the drawer
                return; // Already on the week schedule
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    settings: RouteSettings(name: '/teacher_week_schedule'),
                    builder: (context) => const TeacherWeekScheduleScreen(),
                  ),
                );
              }
            },
          ),
          SidebarMenuItem(
            label: "Groupes",
            icon: Icons.group,
            onTap: () {
              // Navigate to the groups screen
              if (ModalRoute.of(context)?.settings.name == '/teacher_groups') {
                //Navigator.of(context).pop(); // Just close the drawer
                return; // Already on the groups screen
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    settings: RouteSettings(name: '/teacher_groups'),
                    builder: (context) => const TeacherGroupsScreen(),
                  ),
                );
              }
            },
          ),
          SidebarMenuItem(
            label: "Étudiants",
            icon: Icons.school,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: RouteSettings(name: '/teacher_students'),
                  builder: (context) => const TeacherStudentsScreen(),
                ),
              );

              // Navigate to the students screen
            },
          ),
          SidebarMenuItem(
            label: "Matières",
            icon: Icons.menu_book,
            onTap: () {
              // Navigate to the subjects screen
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: RouteSettings(name: '/teacher_subjects'),
                  builder: (context) => const TeacherSubjectsScreen(),
                ),
              );
            },
          ),
          /*SidebarMenuItem(
            label: "Notifications",
            icon: Icons.notifications,
            onTap: () {
              // Navigate to the notifications screen
            },
          ),*/
          SidebarMenuItem(
            label: "Compte",
            icon: Icons.person,
            onTap: () {
              // Navigate to the settings screen
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: RouteSettings(name: '/teacher_subjects'),
                  builder: (context) => const TeacherAccountScreen(),
                ),
              );
            },
          ),
        ],
        onLogout: () async {
          // Handle logout
          const storage = FlutterSecureStorage();
          await storage.deleteAll();
          if (!context.mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        },
        onClose: () {
          Navigator.of(context).pop();
        },
        notificationCount: _notificationCount,
      ),
      body: widget.bodyBuilder != null
          ? widget.bodyBuilder!(reloadTeacherInfo: _loadTeacherInfo)
          : widget.body!,
    );
  }
}
