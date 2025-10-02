import 'package:cidy/profiles/teacher/screens/teacher_student_detail_screen.dart';
import 'package:cidy/profiles/teacher/widgets/student_filter_form.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cidy/config.dart';
import 'package:cidy/profiles/teacher/models/student_model.dart';

class TeacherStudentsScreen extends StatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen> {
  List<Student> _students = [];
  bool _isLoading = true;
  String _error = '';
  final _storage = const FlutterSecureStorage();
  Map<String, dynamic> _filters = {
    'name': null,
    'sort_by': null,
    'payment_status': null,
  };

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }

    String? token = await _storage.read(key: 'auth_token');
    if (token == null) {
      setState(() {
        _isLoading = false;
        _error = 'Authentication token not found. Please log in again.';
      });
      return;
    }

    try {
      final queryParameters = {
        'name': _filters['name'],
        'sort_by': _filters['sort_by'],
        'payment_status': _filters['payment_status'],
      }..removeWhere((key, value) => value == null || value == '');

      final authority = Uri.parse(Config.backendUrl).authority;
      final path = '/api/teacher/students/';
      final uri = Uri.http(authority, path, queryParameters);
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as List;
        setState(() {
          _students = data.map((json) => Student.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load students: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'An error occurred: $e';
      });
    }
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StudentFilterForm(
          currentFilters: _filters,
          onApplyFilter: (newFilters) {
            setState(() {
              _filters = newFilters;
            });
            _fetchStudents();
            Navigator.pop(context);
          },
          onResetFilter: () {
            setState(() {
              _filters = {
                'name': null,
                'sort_by': null,
                'payment_status': null,
              };
            });
            _fetchStudents();
            Navigator.pop(context);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Students'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterModal,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Implement add student
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchStudents(isRefresh: true),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _error,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Students Found',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'You have not added any students yet.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement add student
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Student'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final student = _students[index];
        return _buildStudentCard(student);
      },
    );
  }

  Widget _buildStudentCard(Student student) {
    final paymentStatus = _getPaymentStatus(student);
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TeacherStudentDetailScreen(studentId: student.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(
                  student.image ?? 'https://via.placeholder.com/150',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullname,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${student.id}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusChip(
                    paymentStatus['text']!,
                    paymentStatus['color']!,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${student.unpaid} DT Unpaid',
                    style: TextStyle(
                      color: student.unpaid > 0 ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getPaymentStatus(Student student) {
    if (student.unpaid == 0) {
      return {'text': 'Paid', 'color': Colors.green};
    } else if (student.paid > 0) {
      return {'text': 'Partially Paid', 'color': Colors.orange};
    } else {
      return {'text': 'Unpaid', 'color': Colors.red};
    }
  }

  Widget _buildStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
