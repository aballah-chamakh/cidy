import 'package:flutter/material.dart';

class Group {
  final int id;
  final String name;
  final String level;
  final String? section;
  final String subject;
  final double paid;
  final double unpaid;
  final int studentCount;
  final String day;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  Group({
    required this.id,
    required this.name,
    required this.level,
    this.section,
    required this.subject,
    required this.paid,
    required this.unpaid,
    required this.studentCount,
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'],
      name: json['name'],
      level: json['level_details']['name'],
      section: json['section_details']?['name'],
      subject: json['subject_details']['name'],
      paid: double.parse(json['total_paid'] ?? '0.0'),
      unpaid: double.parse(json['total_unpaid'] ?? '0.0'),
      studentCount: json['student_count'],
      day: json['day'],
      startTime: TimeOfDay(
        hour: int.parse(json['start_time'].split(':')[0]),
        minute: int.parse(json['start_time'].split(':')[1]),
      ),
      endTime: TimeOfDay(
        hour: int.parse(json['end_time'].split(':')[0]),
        minute: int.parse(json['end_time'].split(':')[1]),
      ),
    );
  }
}
