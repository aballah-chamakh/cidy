import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cidy/config.dart';

class TeacherStudentDetailScreen extends StatefulWidget {
  final int studentId;

  const TeacherStudentDetailScreen({super.key, required this.studentId});

  @override
  State<TeacherStudentDetailScreen> createState() =>
      _TeacherStudentDetailScreenState();
}

class _TeacherStudentDetailScreenState
    extends State<TeacherStudentDetailScreen> {
  var _student;
  bool _isLoading = true;
  String _error = '';
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _fetchStudentDetails();
  }

  Future<void> _fetchStudentDetails() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    String? token = await _storage.read(key: 'auth_token');
    if (token == null) {
      setState(() {
        _isLoading = false;
        _error = 'Authentication token not found. Please log in again.';
      });
      return;
    }

    try {
      final authority = Uri.parse(Config.backendUrl).authority;
      final path = '/api/teacher/students/${widget.studentId}/';
      final uri = Uri.http(authority, path);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _student = Student.fromJson(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load student details: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'An error occurred: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_student?.fullname ?? 'Student Details')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Text(_error, style: const TextStyle(color: Colors.red)),
      );
    }
    if (_student == null) {
      return const Center(child: Text('Student not found.'));
    }

    final student = _student!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(
                student.image ?? 'https://via.placeholder.com/150',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              student.fullname,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Financials',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildFinancialsRow('Paid:', '${student.paid}'),
                  const SizedBox(height: 8),
                  _buildFinancialsRow('Unpaid:', '${student.unpaid}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // TODO: Add more details like parent info, groups, etc.
        ],
      ),
    );
  }

  Widget _buildFinancialsRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(value, style: const TextStyle(fontSize: 16)),
      ],
    );
  }
}
