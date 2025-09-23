import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:cidy/authentication/login.dart';
import '../../widgets/profile_appbar.dart';
import '../../widgets/profile_sidebar.dart';
import '../../models/sidebar_menu_item.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cidy/config.dart';
import 'package:cidy/route_observer.dart';

class TeacherLayout extends StatefulWidget {
  final Widget body;
  final String title;

  const TeacherLayout({super.key, required this.title, required this.body});

  @override
  State<TeacherLayout> createState() => _TeacherLayoutState();
}

class _TeacherLayoutState extends State<TeacherLayout>
    with RouteAware, WidgetsBindingObserver {
  String _teacherFullName = '';
  String _teacherImageUrl = '';
  String _teacherEmail = '';
  int _notificationCount = 0;
  var _notificationCountUpdaterTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPushNext() {
    _stopNotificationCountUpdater();
  }

  @override
  void didPopNext() {
    _startNotificationCountUpdater();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startNotificationCountUpdater();
    } else {
      _stopNotificationCountUpdater();
    }
  }

  Future<void> _loadTeacherInfo() async {
    // Load teacher info from local storage using SharedPreferences
    const storage = FlutterSecureStorage();

    final teacherfullName = await storage.read(key: 'fullname');
    final teacherImageUrl = await storage.read(key: 'image_url');
    final teacherEmail = await storage.read(key: 'email');

    setState(() {
      _teacherFullName = teacherfullName!;
      _teacherImageUrl = teacherImageUrl!;
      _teacherEmail = teacherEmail!;
    });
  }

  Future<void> _updateNotificationCount() async {
    // Replace with your API call to fetch unread notification count
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');
    final response = await http.get(
      Uri.parse('${Config.backendUrl}/api/teacher/notifications/unread_count/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        // Assuming the API returns {"unread_count": 5}
        _notificationCount = data['unread_count'];
      });
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

  @override
  void initState() {
    super.initState();
    _loadTeacherInfo();
    _startNotificationCountUpdater();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _stopNotificationCountUpdater();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            },
          ),
          SidebarMenuItem(
            label: "Planning de la semaine",
            icon: Icons.calendar_today,
            onTap: () {
              // Navigate to the week schedule screen
            },
          ),
          SidebarMenuItem(
            label: "Groupes",
            icon: Icons.group,
            onTap: () {
              // Navigate to the groups screen
            },
          ),
          SidebarMenuItem(
            label: "Étudiants",
            icon: Icons.school,
            onTap: () {
              // Navigate to the students screen
            },
          ),
          SidebarMenuItem(
            label: "Tarifs",
            icon: Icons.attach_money,
            onTap: () {
              // Navigate to the prices screen
            },
          ),
          SidebarMenuItem(
            label: "Notifications",
            icon: Icons.notifications,
            onTap: () {
              // Navigate to the notifications screen
            },
          ),
          SidebarMenuItem(
            label: "Paramètres",
            icon: Icons.settings,
            onTap: () {
              // Navigate to the settings screen
            },
          ),
        ],
        onLogout: () async {
          // Handle logout
          const storage = FlutterSecureStorage();
          await storage.deleteAll();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        },
        onClose: () {
          Navigator.of(context).pop();
        },
        notificationCount: _notificationCount,
      ),
      body: widget.body,
    );
  }
}
