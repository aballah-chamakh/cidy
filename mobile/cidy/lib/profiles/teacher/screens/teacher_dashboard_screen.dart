import 'package:flutter/material.dart';
import '../widgets/teacher_layout.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return TeacherLayout(
      title: "Teacher Dashboard",
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome to the Teacher Dashboard",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                child: ListTile(
                  leading: Icon(
                    Icons.assignment,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: const Text("Assignments"),
                  subtitle: const Text("View and manage assignments"),
                  onTap: () {
                    // Navigate to assignments screen
                  },
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 4,
                child: ListTile(
                  leading: Icon(
                    Icons.people,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: const Text("Students"),
                  subtitle: const Text("View and manage students"),
                  onTap: () {
                    // Navigate to students screen
                  },
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 4,
                child: ListTile(
                  leading: Icon(
                    Icons.calendar_today,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: const Text("Schedule"),
                  subtitle: const Text("View your schedule"),
                  onTap: () {
                    // Navigate to schedule screen
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
