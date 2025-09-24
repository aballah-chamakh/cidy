import 'package:flutter/material.dart';
import '../widgets/teacher_layout.dart';

class TeacherWeekScheduleScreen extends StatelessWidget {
  const TeacherWeekScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TeacherLayout(
      title: "Week Schedule",
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Your Weekly Schedule",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 7, // Assuming 7 days in a week
                itemBuilder: (context, index) {
                  final day = [
                    "Monday",
                    "Tuesday",
                    "Wednesday",
                    "Thursday",
                    "Friday",
                    "Saturday",
                    "Sunday",
                  ][index];
                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: Icon(
                        Icons.calendar_today,
                        color: Theme.of(context).primaryColor,
                      ),
                      title: Text(day),
                      subtitle: const Text("No events scheduled"),
                      onTap: () {
                        // Handle day-specific schedule tap
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
