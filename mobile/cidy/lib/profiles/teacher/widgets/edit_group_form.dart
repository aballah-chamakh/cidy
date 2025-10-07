import 'dart:convert';

import 'package:cidy/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cidy/authentication/login.dart';

class EditGroupForm extends StatefulWidget {
  final Map<String, dynamic> group;
  final VoidCallback onGroupUpdated;

  const EditGroupForm({
    super.key,
    required this.group,
    required this.onGroupUpdated,
  });

  @override
  State<EditGroupForm> createState() => _EditGroupFormState();
}

class _EditGroupFormState extends State<EditGroupForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  bool _isLoading = false;
  String? _nameError;
  String? _timeError;

  // Schedule fields
  String? _selectedDayEnglish;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _scheduleChangeType;

  // Original values for comparison
  String? _originalDayEnglish;
  TimeOfDay? _originalStartTime;
  TimeOfDay? _originalEndTime;

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
    _initializeForm();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    _nameController.text = widget.group['name'] ?? '';

    // Set day
    _selectedDayEnglish = widget.group['week_day'];
    _originalDayEnglish = _selectedDayEnglish;

    // Set times
    _startTime = _parseTime(widget.group['start_time']);
    _endTime = _parseTime(widget.group['end_time']);
    _originalStartTime = _startTime;
    _originalEndTime = _endTime;
  }

  TimeOfDay? _parseTime(String? timeString) {
    if (timeString == null) return null;
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (e) {
      // Handle parsing error
    }
    return null;
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool _hasScheduleChanged() {
    return _selectedDayEnglish != _originalDayEnglish ||
        _startTime != _originalStartTime ||
        _endTime != _originalEndTime;
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime
          ? (_startTime ?? const TimeOfDay(hour: 8, minute: 0))
          : (_endTime ?? const TimeOfDay(hour: 23, minute: 59)),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _editGroup() async {
    // Clear previous errors
    setState(() {
      _nameError = null;
      _timeError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    if (_startTime == null || _endTime == null) {
      setState(() {
        _timeError = 'Veuillez sélectionner l\'heure de début et de fin';
      });
      return;
    }

    // Validate time range (8h to 23h59)
    if (_startTime!.hour < 8 ||
        _endTime!.hour >= 24 ||
        (_endTime!.hour == 23 && _endTime!.minute > 59)) {
      setState(() {
        _timeError = 'L\'horaire doit être entre 8h et 23h59';
      });
      return;
    }

    if (_startTime!.hour > _endTime!.hour ||
        (_startTime!.hour == _endTime!.hour &&
            _startTime!.minute >= _endTime!.minute)) {
      setState(() {
        _timeError = 'L\'heure de début doit être antérieure à l\'heure de fin';
      });
      return;
    }

    if (_hasScheduleChanged() && _scheduleChangeType == null) {
      setState(() {
        _timeError =
            'Veuillez spécifier si le changement d\'horaire est permanent ou temporaire';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
        return;
      }

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/groups/${widget.group['id']}/edit/',
      );

      final requestBody = {
        'name': _nameController.text.trim(),
        'week_day': _selectedDayEnglish!,
        'start_time': _formatTime(_startTime!),
        'end_time': _formatTime(_endTime!),
      };

      if (_hasScheduleChanged()) {
        requestBody['schedule_change_type'] = _scheduleChangeType == 'permanent'
            ? 'permanent'
            : 'temporary';
      }

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 401) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
        return;
      }

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Groupe modifié avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onGroupUpdated();
        }
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
        _showError('Erreur de validation');
      } else {
        _showError('Erreur de serveur');
      }
    } catch (e) {
      _showError('Erreur de connexion');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Modifier le groupe',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 20),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group name
                    const Text(
                      'Nom',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorText: _nameError,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le nom du groupe est requis';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Week day
                    const Text(
                      'Jour de la semaine',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedDayEnglish,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: _weekDays.map((day) {
                        return DropdownMenuItem<String>(
                          value: day['value'],
                          child: Text(day['name']!),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          _selectedDayEnglish = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez sélectionner un jour';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Time range
                    const Text(
                      'Plage horaire',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectTime(context, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _startTime != null
                                    ? _formatTime(_startTime!)
                                    : 'Heure de début',
                                style: TextStyle(
                                  color: _startTime != null
                                      ? Colors.black
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('à'),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectTime(context, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _endTime != null
                                    ? _formatTime(_endTime!)
                                    : 'Heure de fin',
                                style: TextStyle(
                                  color: _endTime != null
                                      ? Colors.black
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_timeError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _timeError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],

                    // Schedule change type (only if schedule changed)
                    if (_hasScheduleChanged()) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Le changement d\'horaire est permanent ou seulement pour cette semaine',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _scheduleChangeType,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'temporary',
                            child: Text('Seulement cette semaine'),
                          ),
                          DropdownMenuItem(
                            value: 'permanent',
                            child: Text('Permanent'),
                          ),
                        ],
                        onChanged: (String? value) {
                          setState(() {
                            _scheduleChangeType = value;
                          });
                        },
                        validator: (value) {
                          if (_hasScheduleChanged() &&
                              (value == null || value.isEmpty)) {
                            return 'Veuillez spécifier le type de changement';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: !_isLoading ? _editGroup : null,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Modifier'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
