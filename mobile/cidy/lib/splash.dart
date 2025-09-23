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
    final profileType = await storage.read(key: 'profile_type');

    if (profileType == null) {
      // No token found, redirect to register
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const RegisterScreen()),
      );
    } else {
      Widget profileScreen;
      switch (profileType) {
        case 'student':
          profileScreen = const StudentEntry();
          break;
        case 'teacher':
          profileScreen = const TeacherDashboardScreen();
          break;
        case 'parent':
          profileScreen = const ParentEntry();
          break;
        default:
          profileScreen = const RegisterScreen();
      }

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => profileScreen));
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
