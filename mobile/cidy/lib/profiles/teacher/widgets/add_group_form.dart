import 'dart:convert';
import 'package:cidy/config.dart';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AddGroupForm extends StatefulWidget {
  final VoidCallback onGroupCreated;

  const AddGroupForm({super.key, required this.onGroupCreated});

  @override
  State<AddGroupForm> createState() => _AddGroupFormState();
}

class _AddGroupFormState extends State<AddGroupForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int? _selectedLevelId;
  int? _selectedSectionId;
  int? _selectedSubjectId;
  bool _isCreating = false;
  bool _isLoadingDependencies = true;

  List _levels = [];
  List _sections = [];
  List _subjects = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDependencies();
  }

  Future<void> _fetchDependencies() async {
    if (!mounted) return;
    setState(() {
      _isLoadingDependencies = true;
      _errorMessage = null;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      final headers = {'Authorization': 'Bearer $token'};

      final levelsResponse = await http.get(
        Uri.parse('${Config.backendUrl}/api/common/levels/'),
        headers: headers,
      );
      final sectionsResponse = await http.get(
        Uri.parse('${Config.backendUrl}/api/common/sections/'),
        headers: headers,
      );
      final subjectsResponse = await http.get(
        Uri.parse('${Config.backendUrl}/api/common/subjects/'),
        headers: headers,
      );

      if (levelsResponse.statusCode == 200 &&
          sectionsResponse.statusCode == 200 &&
          subjectsResponse.statusCode == 200) {
        if (mounted) {
          setState(() {
            final levelsData = json.decode(levelsResponse.body) as List;
            _levels = levelsData;

            final sectionsData = json.decode(sectionsResponse.body) as List;
            _sections = sectionsData;

            final subjectsData = json.decode(subjectsResponse.body) as List;
            _subjects = subjectsData;
          });
        }
      } else {
        throw Exception('Failed to load form dependencies.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDependencies = false;
        });
      }
    }
  }

  Future<void> _createGroup() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isCreating = true;
      });

      try {
        const storage = FlutterSecureStorage();
        final token = await storage.read(key: 'access_token');
        if (token == null) {
          throw Exception('Authentication token not found.');
        }

        final url = Uri.parse('${Config.backendUrl}/api/teacher/groups/');
        final response = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'name': _nameController.text,
            'level': _selectedLevelId,
            'section': _selectedSectionId,
            'subject': _selectedSubjectId,
          }),
        );

        if (response.statusCode == 201) {
          if (mounted) {
            widget.onGroupCreated();
            Navigator.of(context).pop();
          }
        } else {
          final errorData = json.decode(response.body);
          throw Exception('Failed to create group: $errorData');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isCreating = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(key: _formKey, child: _buildFormContent()),
      ),
    );
  }

  Widget _buildFormContent() {
    if (_isLoadingDependencies) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Group Name'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a group name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          value: _selectedLevelId,
          decoration: const InputDecoration(labelText: 'Level'),
          items: _levels.map((level) {
            return DropdownMenuItem<int>(
              value: level.id,
              child: Text(level.name),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedLevelId = value;
            });
          },
          validator: (value) => value == null ? 'Please select a level' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          value: _selectedSectionId,
          decoration: const InputDecoration(labelText: 'Section'),
          items: _sections.map((section) {
            return DropdownMenuItem<int>(
              value: section.id,
              child: Text(section.name),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedSectionId = value;
            });
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          value: _selectedSubjectId,
          decoration: const InputDecoration(labelText: 'Subject'),
          items: _subjects.map((subject) {
            return DropdownMenuItem<int>(
              value: subject.id,
              child: Text(subject.name),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedSubjectId = value;
            });
          },
          validator: (value) =>
              value == null ? 'Please select a subject' : null,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isCreating ? null : _createGroup,
          child: _isCreating
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create Group'),
        ),
      ],
    );
  }
}
