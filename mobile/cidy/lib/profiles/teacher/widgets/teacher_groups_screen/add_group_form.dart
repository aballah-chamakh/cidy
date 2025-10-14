import 'dart:convert';
import 'package:cidy/config.dart';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:cidy/authentication/login.dart';
import 'package:cidy/constants.dart';

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

  // Field-specific error messages
  String? _nameError;
  String? _timeError;

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

    setState(() {
      _isCreating = true;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (!mounted) return;

      if (token == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
        return;
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
      if (!mounted) return;

      if (response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final int? groupId = (data is Map && data['group_id'] is int)
            ? data['group_id'] as int
            : null;
        Navigator.of(context).pop();
        if (groupId != null) {
          widget.onGroupCreated(groupId);
        } else {
          // Fallback: refresh only
          widget.onGroupCreated(-1);
        }
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else if (response.statusCode == 400) {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        if (errorData is Map && errorData.containsKey('non_field_errors')) {
          final errorType = errorData['non_field_errors'][0];
          if (errorType == 'ALREADY_EXISTING_GROUP_NAME_DETECTED') {
            setState(() {
              _nameError =
                  'Un groupe avec le même nom existe déjà pour ce niveau/section/matière';
            });
            return;
          } else if (errorType == 'SCHEDULE_CONFLICT_DETECTED') {
            setState(() {
              _timeError = 'Cet horaire entre en conflit avec un autre groupe.';
            });
            return;
          }
        }
        // For other 400 errors, show snackbar
        Navigator.of(context).pop();
        _showError('Erreur du serveur (500)');
      } else {
        Navigator.of(context).pop();
        _showError('Erreur du serveur (500).');
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showError('Erreur du serveur (500).');
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 0,
      ), // 👈 margins on left/right
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.of(context).size.height * 0.7, // 70% of screen height
        ),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  const Divider(height: 10, thickness: 1),
                  Flexible(child: _buildFormContent()),
                  const SizedBox(height: 16),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Ajouter un groupe',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
          textAlign: TextAlign.left,
        ),
        IconButton(
          icon: Icon(
            Icons.close,
            size: 30,
            color: Theme.of(context).primaryColor,
          ),
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
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Ajouter',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildFormContent() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nom du groupe',
              labelStyle: TextStyle(color: Theme.of(context).primaryColor),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).primaryColor),
                borderRadius: BorderRadius.circular(8.0),
              ),
              errorText: _nameError,
            ),
            onChanged: (value) {
              if (_nameError != null) {
                setState(() {
                  _nameError = null;
                });
              }
            },
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
                  child: Text(levelName, style: TextStyle(fontSize: 16)),
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
            validator: (value) =>
                value == null ? 'Sélectionnez un niveau' : null,
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
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                    ),
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
                final levelHasSections =
                    (levelDef['sections'] ?? {}).isNotEmpty;
                if (levelHasSections) {
                  if (_selectedSectionName != null &&
                      _selectedSectionName!.isNotEmpty) {
                    final sectionDef = _sections[_selectedSectionName!];
                    currentSubjects =
                        (sectionDef?['subjects'] ?? []) as List<dynamic>;
                    isEnabled = currentSubjects.isNotEmpty;
                  }
                } else {
                  currentSubjects =
                      (levelDef['subjects'] ?? []) as List<dynamic>;
                  isEnabled = currentSubjects.isNotEmpty;
                }
              }

              return DropdownButtonFormField<String>(
                value: _selectedSubjectName,
                decoration: InputDecoration(
                  labelText: 'Matière',
                  labelStyle: TextStyle(color: Theme.of(context).primaryColor),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                    ),
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
              ...weekDays.map(
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
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    final bool isEnabled = _selectedDayEnglish != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _startTimeController,
                decoration: InputDecoration(
                  labelText: 'Heure de début',
                  labelStyle: TextStyle(color: Theme.of(context).primaryColor),
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
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
                  if (_timeError != null) {
                    setState(() {
                      _timeError = null;
                    });
                  }
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
                  labelStyle: TextStyle(color: Theme.of(context).primaryColor),
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
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
                  if (_timeError != null) {
                    setState(() {
                      _timeError = null;
                    });
                  }
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
        ),
        if (_timeError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _timeError!,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
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
