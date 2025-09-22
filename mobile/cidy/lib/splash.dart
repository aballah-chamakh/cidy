import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'authentication/register.dart';
import 'profiles/student/student_entry.dart';
import 'profiles/teacher/screens/teacher_dashboard_screen.dart';
import 'profiles/parent/parent_entry.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();

    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait for splash animation to complete
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    const storage = FlutterSecureStorage();
    final accessToken = await storage.read(key: 'access_token');

    if (accessToken == null) {
      // No token found, redirect to register
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const RegisterScreen()),
      );
    } else {
      // Token exists, decode it to get profile type
      try {
        final parts = accessToken.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          // Add padding if needed
          String normalizedPayload = base64.normalize(payload);
          final decodedPayload = utf8.decode(base64.decode(normalizedPayload));
          final tokenData = jsonDecode(decodedPayload);
          final profileType = tokenData['profile_type'];

          Widget entryWidget;
          switch (profileType) {
            case 'student':
              entryWidget = const StudentEntry();
              break;
            case 'teacher':
              entryWidget = const TeacherDashboardScreen();
              break;
            case 'parent':
              entryWidget = const ParentEntry();
              break;
            default:
              entryWidget = const RegisterScreen();
          }

          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => entryWidget),
          );
        } else {
          // Invalid token format, redirect to register
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const RegisterScreen()),
          );
        }
      } catch (e) {
        // Error decoding token, redirect to register
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const RegisterScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor, // Orange background
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Image.asset('assets/white_cidy_logo.png', height: 100.0),
          ),
        ),
      ),
    );
  }
}
