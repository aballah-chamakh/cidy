import 'dart:convert';
import 'package:cidy/config.dart';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AddGroupForm extends StatefulWidget {
  final VoidCallback onGroupCreated;
  // Use the same options map provided by the groups listing API
  // (teacher_levels_sections_subjects_hierarchy), like GroupFilterForm does.
  final Map<String, dynamic> filterOptions;

  const AddGroupForm({
    super.key,
    required this.onGroupCreated,
    required this.filterOptions,
  });

  @override
  State<AddGroupForm> createState() => _AddGroupFormState();
}

class _AddGroupFormState extends State<AddGroupForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isCreating = false;

  // Options derived from filterOptions hierarchy
  Map<String, dynamic> _levels = {}; // levelName -> { sections, subjects? }
  Map<String, dynamic> _sections = {}; // sectionName -> { subjects }
  List<dynamic> _subjects = []; // list of subject names

  // Selected values (by name)
  String? _selectedLevelName;
  String? _selectedSectionName;
  String? _selectedSubjectName;

  @override
  void initState() {
    super.initState();
    _processFilterOptions();
  }

  void _processFilterOptions() {
    // The provided hierarchy is expected to be a map like:
    // { levelName: { sections: { sectionName: { subjects: [subjName, ...] } }, subjects?: [subjName, ...] } }
    _levels = widget.filterOptions;
    // Reset dependent options
    _sections = {};
    _subjects = [];
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
    });

    try {
      // Resolve IDs from names via common endpoints to preserve backend contract
      final ids = await _resolveIdsFromNames(
        levelName: _selectedLevelName!,
        sectionName: _selectedSectionName,
        subjectName: _selectedSubjectName!,
      );

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
          'name': _nameController.text.trim(),
          'level': ids['levelId'],
          'section': ids['sectionId'],
          'subject': ids['subjectId'],
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

  Future<Map<String, int?>> _resolveIdsFromNames({
    required String levelName,
    String? sectionName,
    required String subjectName,
  }) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final headers = {'Authorization': 'Bearer $token'};

    // Fetch lists and map by name
    final levelsResp = await http.get(
      Uri.parse('${Config.backendUrl}/api/common/levels/'),
      headers: headers,
    );
    if (levelsResp.statusCode != 200) {
      throw Exception('Impossible de charger les niveaux');
    }
    final sectionsResp = await http.get(
      Uri.parse('${Config.backendUrl}/api/common/sections/'),
      headers: headers,
    );
    if (sectionsResp.statusCode != 200) {
      throw Exception('Impossible de charger les sections');
    }
    final subjectsResp = await http.get(
      Uri.parse('${Config.backendUrl}/api/common/subjects/'),
      headers: headers,
    );
    if (subjectsResp.statusCode != 200) {
      throw Exception('Impossible de charger les matières');
    }

    final List<dynamic> levels = json.decode(levelsResp.body) as List<dynamic>;
    final List<dynamic> sections =
        json.decode(sectionsResp.body) as List<dynamic>;
    final List<dynamic> subjects =
        json.decode(subjectsResp.body) as List<dynamic>;

    int? levelId;
    int? sectionId;
    int? subjectId;

    for (final lvl in levels) {
      if ((lvl['name'] ?? '').toString() == levelName) {
        levelId = lvl['id'] as int?;
        break;
      }
    }
    if (levelId == null) {
      throw Exception("Niveau introuvable: $levelName");
    }

    if (sectionName != null && sectionName.isNotEmpty) {
      for (final sec in sections) {
        if ((sec['name'] ?? '').toString() == sectionName) {
          sectionId = sec['id'] as int?;
          break;
        }
      }
      if (sectionId == null) {
        throw Exception("Section introuvable: $sectionName");
      }
    }

    for (final subj in subjects) {
      if ((subj['name'] ?? '').toString() == subjectName) {
        subjectId = subj['id'] as int?;
        break;
      }
    }
    if (subjectId == null) {
      throw Exception("Matière introuvable: $subjectName");
    }

    return {'levelId': levelId, 'sectionId': sectionId, 'subjectId': subjectId};
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Nom du groupe'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Veuillez saisir un nom de groupe';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedLevelName,
          decoration: const InputDecoration(labelText: 'Niveau'),
          items: [
            ..._levels.keys.map(
              (levelName) => DropdownMenuItem<String>(
                value: levelName,
                child: Text(levelName),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _selectedLevelName = value;
              _selectedSectionName = null;
              _selectedSubjectName = null;
              if (value != null && _levels.containsKey(value)) {
                _sections = _levels[value]['sections'] ?? {};
                // If no sections, subjects may be directly under level
                if ((_sections).isEmpty) {
                  _subjects =
                      (_levels[value]['subjects'] ?? []) as List<dynamic>;
                } else {
                  _subjects = [];
                }
              } else {
                _sections = {};
                _subjects = [];
              }
            });
          },
          validator: (value) => value == null ? 'Sélectionnez un niveau' : null,
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (context) {
            final bool hasSections = _sections.isNotEmpty;
            return DropdownButtonFormField<String>(
              value: _selectedSectionName,
              decoration: InputDecoration(
                labelText: 'Section',
                filled: !hasSections,
                fillColor: !hasSections ? Colors.grey[200] : null,
              ),
              items: [
                if (hasSections)
                  ..._sections.keys.map(
                    (sectionName) => DropdownMenuItem<String>(
                      value: sectionName,
                      child: Text(sectionName),
                    ),
                  ),
              ],
              onChanged: hasSections
                  ? (value) {
                      setState(() {
                        _selectedSectionName = value;
                        _selectedSubjectName = null;
                        if (value != null && _sections.containsKey(value)) {
                          _subjects =
                              (_sections[value]['subjects'] ?? [])
                                  as List<dynamic>;
                        } else {
                          _subjects = [];
                        }
                      });
                    }
                  : null,
            );
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedSubjectName,
          decoration: const InputDecoration(labelText: 'Matière'),
          items: [
            ..._subjects.map(
              (s) => DropdownMenuItem<String>(
                value: s.toString(),
                child: Text(s.toString()),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _selectedSubjectName = value;
            });
          },
          validator: (value) =>
              value == null ? 'Sélectionnez une matière' : null,
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
              : const Text('Créer le groupe'),
        ),
      ],
    );
  }
}
