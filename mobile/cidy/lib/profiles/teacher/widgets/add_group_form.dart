import 'dart:convert';
import 'package:cidy/config.dart';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class AddGroupForm extends StatefulWidget {
  // Return the created group's id so the caller can navigate to its details
  final void Function(int groupId) onGroupCreated;
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
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  bool _isCreating = false;

  // Options derived from filterOptions hierarchy
  Map<String, dynamic> _levels = {}; // levelName -> { sections, subjects? }
  Map<String, dynamic> _sections = {}; // sectionName -> { subjects }

  // Selected values (by name)
  String? _selectedLevelName;
  String? _selectedSectionName;
  String? _selectedSubjectName;

  // Schedule fields
  String? _selectedDayEnglish; // store English day for API
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final List<Map<String, String>> _weekDays = const [
    {'value': 'Monday', 'name': 'Lundi'},
    {'value': 'Tuesday', 'name': 'Mardi'},
    {'value': 'Wednesday', 'name': 'Mercredi'},
    {'value': 'Thursday', 'name': 'Jeudi'},
    {'value': 'Friday', 'name': 'Vendredi'},
    {'value': 'Saturday', 'name': 'Samedi'},
    {'value': 'Sunday', 'name': 'Dimanche'},
  ];

  @override
  void initState() {
    super.initState();
    _processFilterOptions();
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  void _processFilterOptions() {
    // The provided hierarchy is expected to be a map like:
    // { levelName: { sections: { sectionName: { subjects: [subjName, ...] } }, subjects?: [subjName, ...] } }
    _levels = widget.filterOptions;
    // Reset dependent options
    _sections = {};
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    // Additional frontend validations
    final scheduleError = _validateTimeRange();
    if (scheduleError != null) {
      _showError(scheduleError);
      return;
    }

    // Validate against existing groups (duplicates and overlap)
    final preCheckError = await _checkConflicts();
    if (preCheckError != null) {
      _showError(preCheckError);
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      // Use the create endpoint exposed by the backend
      final url = Uri.parse('${Config.backendUrl}/api/teacher/groups/create/');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': _nameController.text.trim(),
          'level': _selectedLevelName!,
          'section': _selectedSectionName,
          'subject': _selectedSubjectName!,
          'week_day': _selectedDayEnglish,
          'start_time': _formatTime(_startTime!),
          'end_time': _formatTime(_endTime!),
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final int? groupId = (data is Map && data['id'] is int)
            ? data['id'] as int
            : null;
        if (mounted) {
          Navigator.of(context).pop();
          if (groupId != null) {
            widget.onGroupCreated(groupId);
          } else {
            // Fallback: refresh only
            widget.onGroupCreated(-1);
          }
        }
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        if (errorData is Map && errorData.containsKey('detail')) {
          final detail = errorData['detail'];
          if (detail == 'ALREADY_EXISTING_GROUP_NAME_DETECTED') {
            throw Exception(
              'Un groupe avec le même nom existe déjà pour ce niveau/section/matière',
            );
          } else if (detail == 'SCHEDULE_CONFLICT_DETECTED') {
            throw Exception(
              'Conflit d\'horaire: la plage choisie chevauche un autre groupe.',
            );
          }
        }
        throw Exception('Failed to create group: $errorData');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  TimeOfDay? _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length == 2) {
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    return null;
  }

  String? _validateTimeRange() {
    if (_selectedDayEnglish == null) {
      return 'Sélectionnez un jour de la semaine';
    }
    if (_startTime == null || _endTime == null) {
      return 'Sélectionnez une plage horaire';
    }
    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    final minStart = 8 * 60; // 08:00
    final maxEnd = 24 * 60; // 24:00
    if (startMinutes < minStart) {
      return 'L\'heure de début doit être à partir de 08:00';
    }
    if (endMinutes > maxEnd) {
      return 'L\'heure de fin ne doit pas dépasser 24:00';
    }
    if (endMinutes <= startMinutes) {
      return 'L\'heure de fin doit être supérieure à l\'heure de début';
    }
    return null;
  }

  Future<String?> _checkConflicts() async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) {
        return 'Authentication token not found.';
      }

      // Fetch candidates with same name/level/section/subject
      final query1 = <String, String>{'name': _nameController.text.trim()};
      if (_selectedLevelName != null) query1['level'] = _selectedLevelName!;
      if (_selectedSectionName != null && _selectedSectionName!.isNotEmpty) {
        query1['section'] = _selectedSectionName!;
      }
      if (_selectedSubjectName != null)
        query1['subject'] = _selectedSubjectName!;

      final uri1 = Uri.parse(
        '${Config.backendUrl}/api/teacher/groups/',
      ).replace(queryParameters: query1);
      final resp1 = await http.get(
        uri1,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp1.statusCode == 200) {
        final List<dynamic> groups = json.decode(utf8.decode(resp1.bodyBytes));
        if (groups.isNotEmpty) {
          return 'Un groupe avec le même nom existe déjà pour ce niveau/section/matière';
        }
      }

      // Check time overlap on the same day
      final query2 = <String, String>{'day': _selectedDayEnglish!};
      final uri2 = Uri.parse(
        '${Config.backendUrl}/api/teacher/groups/',
      ).replace(queryParameters: query2);
      final resp2 = await http.get(
        uri2,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp2.statusCode == 200) {
        final List<dynamic> groups = json.decode(utf8.decode(resp2.bodyBytes));
        for (final g in groups) {
          final String st = (g['start_time'] ?? '').toString();
          final String et = (g['end_time'] ?? '').toString();
          if (st.isEmpty || et.isEmpty) continue;
          final partsS = st.split(':');
          final partsE = et.split(':');
          if (partsS.length < 2 || partsE.length < 2) continue;
          final gStart = int.parse(partsS[0]) * 60 + int.parse(partsS[1]);
          final gEnd = int.parse(partsE[0]) * 60 + int.parse(partsE[1]);
          final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
          final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
          final bool overlap = startMinutes < gEnd && endMinutes > gStart;
          if (overlap) {
            return 'Conflit d\'horaire: la plage choisie chevauche un autre groupe (${st} - ${et}).';
          }
        }
      }
      return null;
    } catch (_) {
      // If pre-check fails, defer to backend validation
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const Divider(height: 10, thickness: 1),
              _buildFormContent(),
              const SizedBox(height: 16),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Ajouter un groupe',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.left,
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 24),
          padding: EdgeInsets.zero, // 👈 removes default padding
          constraints: BoxConstraints(), // 👈 removes default constraints
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isCreating ? null : _createGroup,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: _isCreating
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text(
                'Ajouter',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
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
          decoration: InputDecoration(
            labelText: 'Niveau',
            labelStyle: TextStyle(color: Theme.of(context).primaryColor),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
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
              } else {
                _sections = {};
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
                labelStyle: TextStyle(color: Theme.of(context).primaryColor),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                  borderRadius: BorderRadius.circular(8.0),
                ),
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
                      });
                    }
                  : null,
              validator: (value) {
                if (!hasSections) return null;
                if (value == null || value.isEmpty) {
                  return 'Sélectionnez une section';
                }
                return null;
              },
            );
          },
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (context) {
            bool isEnabled = false;
            List<dynamic> currentSubjects = [];

            if (_selectedLevelName != null) {
              final levelDef = _levels[_selectedLevelName];
              final levelHasSections = (levelDef['sections'] ?? {}).isNotEmpty;
              if (levelHasSections) {
                if (_selectedSectionName != null &&
                    _selectedSectionName!.isNotEmpty) {
                  final sectionDef = _sections[_selectedSectionName!];
                  currentSubjects =
                      (sectionDef?['subjects'] ?? []) as List<dynamic>;
                  isEnabled = currentSubjects.isNotEmpty;
                }
              } else {
                currentSubjects = (levelDef['subjects'] ?? []) as List<dynamic>;
                isEnabled = currentSubjects.isNotEmpty;
              }
            }

            return DropdownButtonFormField<String>(
              value: _selectedSubjectName,
              decoration: InputDecoration(
                labelText: 'Matière',
                labelStyle: TextStyle(color: Theme.of(context).primaryColor),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                filled: !isEnabled,
                fillColor: !isEnabled ? Colors.grey[200] : null,
              ),
              items: [
                if (isEnabled)
                  ...currentSubjects.map(
                    (s) => DropdownMenuItem<String>(
                      value: s.toString(),
                      child: Text(s.toString()),
                    ),
                  ),
              ],
              onChanged: isEnabled
                  ? (value) {
                      setState(() {
                        _selectedSubjectName = value;
                      });
                    }
                  : null,
              validator: (value) {
                if (!isEnabled) return null;
                if (value == null || value.isEmpty) {
                  return 'Sélectionnez une matière';
                }
                return null;
              },
            );
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedDayEnglish,
          decoration: InputDecoration(
            labelText: 'Jour de la semaine',
            labelStyle: TextStyle(color: Theme.of(context).primaryColor),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          items: [
            ..._weekDays.map(
              (d) => DropdownMenuItem<String>(
                value: d['value']!,
                child: Text(d['name']!),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _selectedDayEnglish = value;
            });
          },
          validator: (value) => value == null ? 'Sélectionnez un jour' : null,
        ),
        const SizedBox(height: 16),
        _buildTimeRangeSelector(),
      ],
    );
  }

  Widget _buildTimeRangeSelector() {
    final bool isEnabled = _selectedDayEnglish != null;
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _startTimeController,
            decoration: InputDecoration(
              labelText: 'Heure de début',
              border: const OutlineInputBorder(),
              filled: !isEnabled,
              fillColor: !isEnabled ? Colors.grey[200] : null,
              hintText: 'HH:MM',
            ),
            enabled: isEnabled,
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
              _TimeTextInputFormatter(),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez saisir une heure de début';
              }
              final time = _parseTime(value);
              if (time == null) return 'Format invalide';
              if (time.hour < 8) return 'Min 08:00';
              if (_endTime != null &&
                  (time.hour > _endTime!.hour ||
                      (time.hour == _endTime!.hour &&
                          time.minute > _endTime!.minute))) {
                return 'Début > Fin';
              }
              return null;
            },
            onChanged: (value) {
              if (value.isNotEmpty) {
                final time = _parseTime(value);
                if (time != null) {
                  setState(() {
                    _startTime = time;
                  });
                }
              } else {
                setState(() {
                  _startTime = null;
                });
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _endTimeController,
            decoration: InputDecoration(
              labelText: 'Heure de fin',
              border: const OutlineInputBorder(),
              filled: !isEnabled,
              fillColor: !isEnabled ? Colors.grey[200] : null,
              hintText: 'HH:MM',
            ),
            enabled: isEnabled,
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
              _TimeTextInputFormatter(),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez saisir une heure de fin';
              }
              final time = _parseTime(value);
              if (time == null) return 'Format invalide';
              if (time.hour == 0 && time.minute > 0) return 'Max 00:00';
              if (_startTime != null &&
                  (time.hour < _startTime!.hour ||
                      (time.hour == _startTime!.hour &&
                          time.minute < _startTime!.minute))) {
                return 'Fin < Début';
              }
              return null;
            },
            onChanged: (value) {
              if (value.isNotEmpty) {
                final time = _parseTime(value);
                if (time != null) {
                  setState(() {
                    _endTime = time;
                  });
                }
              } else {
                setState(() {
                  _endTime = null;
                });
              }
            },
          ),
        ),
        if (_startTimeController.text.isNotEmpty ||
            _endTimeController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _startTime = null;
                _endTime = null;
                _startTimeController.clear();
                _endTimeController.clear();
              });
            },
          ),
      ],
    );
  }
}

class _TimeTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text;
    if (newText.length > 5) {
      return oldValue;
    }

    String text = newText.replaceAll(':', '');
    if (text.length > 2) {
      text = '${text.substring(0, 2)}:${text.substring(2)}';
    }

    // Validate hour and minute
    if (text.contains(':')) {
      final parts = text.split(':');
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);

      if (hour != null && hour > 23) {
        return oldValue;
      }
      if (minute != null && minute > 59) {
        return oldValue;
      }
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
