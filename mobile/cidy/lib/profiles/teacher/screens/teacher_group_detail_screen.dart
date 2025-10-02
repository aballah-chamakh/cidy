import 'dart:convert';
import 'package:cidy/config.dart';
import 'package:cidy/profiles/teacher/models/group_model.dart';
import 'package:cidy/profiles/teacher/models/student_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class TeacherGroupDetailScreen extends StatefulWidget {
  final int groupId;

  const TeacherGroupDetailScreen({super.key, required this.groupId});

  @override
  State<TeacherGroupDetailScreen> createState() =>
      _TeacherGroupDetailScreenState();
}

class _TeacherGroupDetailScreenState extends State<TeacherGroupDetailScreen> {
  bool _isLoading = true;
  Group? _group;
  List<Student> _students = [];
  String? _errorMessage;
  final Set<int> _selectedStudentIds = {};

  @override
  void initState() {
    super.initState();
    _fetchGroupDetails();
  }

  Future<void> _fetchGroupDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/groups/${widget.groupId}/',
      );
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _group = Group.fromJson(data['group']);
            _students = (data['students'] as List)
                .map((studentJson) => Student.fromJson(studentJson))
                .toList();
            _isLoading = false;
          });
        }
      } else {
        throw Exception(
          'Failed to load group details: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading ? 'Loading...' : 'Group: ${_group!.name}'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text('Error: $_errorMessage'));
    }

    if (_group == null) {
      return const Center(child: Text('Group not found.'));
    }

    return _buildGroupDetails();
  }

  Widget _buildGroupDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildGroupDetailsCard(),
          const SizedBox(height: 16),
          _buildKpiCards(),
          const SizedBox(height: 16),
          _buildStudentListCard(),
        ],
      ),
    );
  }

  Widget _buildGroupDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Group Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        // TODO: Implement edit group
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        // TODO: Implement delete group
                      },
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            _buildDetailRow('Name', _group!.name),
            if (_group!.section != null)
              _buildDetailRow(
                'Level & Section',
                '${_group!.level} - ${_group!.section}',
              ),
            _buildDetailRow('Subject', _group!.subject),
            _buildDetailRow(
              'Week day and time range',
              '${_group!.day}, ${_group!.startTime.format(context)} - ${_group!.endTime.format(context)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildKpiCards() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildKpiCard(_group!.paid.toString(), 'Paid', Colors.green),
        _buildKpiCard(_group!.unpaid.toString(), 'Unpaid', Colors.red),
        _buildKpiCard(_group!.studentCount.toString(), 'Students', Colors.blue),
      ],
    );
  }

  Widget _buildKpiCard(String value, String label, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentListCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_students.length} Student(s)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Implement add student
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Filters will go here
            _students.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('No students in this group.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      return _buildStudentCard(_students[index]);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(Student student) {
    final isSelected = _selectedStudentIds.contains(student.id);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: student.image != null
              ? NetworkImage('${Config.backendUrl}${student.image}')
              : null,
          child: student.image == null ? const Icon(Icons.person) : null,
        ),
        title: Text(student.fullname),
        subtitle: Row(
          children: [
            Text(
              '${student.paid} paid',
              style: const TextStyle(color: Colors.green),
            ),
            const SizedBox(width: 8),
            Text(
              '${student.unpaid} unpaid',
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
        trailing: Checkbox(
          value: isSelected,
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                _selectedStudentIds.add(student.id);
              } else {
                _selectedStudentIds.remove(student.id);
              }
            });
          },
        ),
        onTap: () {
          // TODO: Navigate to student detail
        },
      ),
    );
  }
}
