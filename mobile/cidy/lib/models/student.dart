import 'package:flutter/material.dart';

class TeacherStudent {
  final int id;
  final String image;
  final String fullname;
  final String level;
  final String section;
  final String phoneNumber;
  final double paidAmount;
  final double unpaidAmount;
  final List<Group> groups;

  TeacherStudent({
    required this.id,
    required this.image,
    required this.fullname,
    required this.level,
    required this.section,
    required this.phoneNumber,
    required this.paidAmount,
    required this.unpaidAmount,
    required this.groups,
  });

  factory TeacherStudent.fromJson(Map<String, dynamic> json) {
    var groupsList = json['groups'] as List;
    List<Group> groups = groupsList.map((i) => Group.fromJson(i)).toList();

    return TeacherStudent(
      id: json['id'],
      image: json['image'],
      fullname: json['fullname'],
      level: json['level'],
      section: json['section'],
      phoneNumber: json['phone_number'],
      paidAmount: double.parse(json['paid_amount'].toString()),
      unpaidAmount: double.parse(json['unpaid_amount'].toString()),
      groups: groups,
    );
  }
}

class Group {
  final int id;
  final String name;
  final String label;
  final double paidAmount;
  final double unpaidAmount;
  final String weekDay;
  final String startTime;
  final String endTime;
  final List<Class> classes;

  Group({
    required this.id,
    required this.name,
    required this.label,
    required this.paidAmount,
    required this.unpaidAmount,
    required this.weekDay,
    required this.startTime,
    required this.endTime,
    required this.classes,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    var classesList = json['classes'] as List;
    List<Class> classes = classesList.map((i) => Class.fromJson(i)).toList();
    return Group(
      id: json['id'],
      name: json['name'],
      label: json['label'],
      paidAmount: double.parse(json['paid_amount'].toString()),
      unpaidAmount: double.parse(json['unpaid_amount'].toString()),
      weekDay: json['week_day'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      classes: classes,
    );
  }
}

class Class {
  final int id;
  final String status;
  final DateTime? attendanceDate;
  final TimeOfDay? attendanceStartTime;
  final TimeOfDay? attendanceEndTime;
  final DateTime? absenceDate;
  final TimeOfDay? absenceStartTime;
  final TimeOfDay? absenceEndTime;
  final DateTime? paidAt;

  Class({
    required this.id,
    required this.status,
    this.attendanceDate,
    this.attendanceStartTime,
    this.attendanceEndTime,
    this.absenceDate,
    this.absenceStartTime,
    this.absenceEndTime,
    this.paidAt,
  });

  factory Class.fromJson(Map<String, dynamic> json) {
    return Class(
      id: json['id'],
      status: json['status'],
      attendanceDate: json['attendance_date'] != null
          ? DateTime.parse(json['attendance_date'])
          : null,
      attendanceStartTime: json['attendance_start_time'] != null
          ? TimeOfDay.fromDateTime(
              DateTime.parse('2000-01-01T${json['attendance_start_time']}'),
            )
          : null,
      attendanceEndTime: json['attendance_end_time'] != null
          ? TimeOfDay.fromDateTime(
              DateTime.parse('2000-01-01T${json['attendance_end_time']}'),
            )
          : null,
      absenceDate: json['absence_date'] != null
          ? DateTime.parse(json['absence_date'])
          : null,
      absenceStartTime: json['absence_start_time'] != null
          ? TimeOfDay.fromDateTime(
              DateTime.parse('2000-01-01T${json['absence_start_time']}'),
            )
          : null,
      absenceEndTime: json['absence_end_time'] != null
          ? TimeOfDay.fromDateTime(
              DateTime.parse('2000-01-01T${json['absence_end_time']}'),
            )
          : null,
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
    );
  }
}
