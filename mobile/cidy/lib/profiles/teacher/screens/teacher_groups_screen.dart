import 'package:flutter/material.dart';
import '../widgets/teacher_layout.dart';

class TeacherGroupsScreen extends StatelessWidget {
  const TeacherGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TeacherLayout(
      title: 'Teacher Groups',
      body: Center(
        child: Text(
          'This is the Teacher Groups Screen',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
