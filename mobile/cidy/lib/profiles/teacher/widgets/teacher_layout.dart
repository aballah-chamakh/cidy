import 'package:flutter/material.dart';
import '../../widgets/profile_appbar.dart';
import '../../widgets/profile_sidebar.dart';
import '../../models/sidebar_menu_item.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TeacherLayout extends StatefulWidget {
  final Widget body;
  final String title;

  const TeacherLayout({super.key, required this.title, required this.body});

  @override
  State<TeacherLayout> createState() => _TeacherLayoutState();
}

class _TeacherLayoutState extends State<TeacherLayout> {
  String _teacherFullName = '';
  String _profileImageUrl = '';

  @override
  void initState() {
    super.initState();
    _loadTeacherInfo();
  }

  Future<void> _loadTeacherInfo() async {
    // Load teacher info from local storage using SharedPreferences
    const storage = FlutterSecureStorage();

    final fullName = await storage.read(key: 'teacherFullName');
    final profileImageUrl = await storage.read(key: 'teacherProfileImageUrl');

    setState(() {
      _teacherFullName = fullName!;
      _profileImageUrl = profileImageUrl!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfileAppBar(
        title: widget.title,
        notificationCount: 5,
        onNotificationTap: () {
          // Handle notification tap
          print("Notification tapped");
        },
      ),
      drawer: ProfileSidebar(
        fullName: _teacherFullName,
        profileImageUrl: _profileImageUrl,
        menuItems: [
          SidebarMenuItem(label: "Home", icon: Icons.home, onTap: () {}),
          SidebarMenuItem(
            label: "Settings",
            icon: Icons.settings,
            onTap: () {},
          ),
        ],
        onLogout: () {
          // Handle logout
          print("Logged out");
        },
        onClose: () {
          Navigator.of(context).pop();
        },
        notificationCount: 5,
      ),
      body: widget.body,
    );
  }
}
