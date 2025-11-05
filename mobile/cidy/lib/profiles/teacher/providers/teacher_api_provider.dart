import 'package:cidy/app_tools.dart';
import 'package:cidy/models/student.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TeacherApiProvider with ChangeNotifier {
  final String _baseUrl =
      "http://10.0.2.2:8000"; // Use 10.0.2.2 for Android emulator

  Future<TeacherStudent> getStudentDetails(int studentId) async {
    String? token = await AppTools.getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/api/teacher/students/$studentId/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return TeacherStudent.fromJson(
        json.decode(utf8.decode(response.bodyBytes)),
      );
    } else {
      throw Exception('Failed to load student details');
    }
  }
}
