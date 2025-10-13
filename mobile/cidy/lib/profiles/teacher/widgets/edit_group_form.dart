import 'dart:convert';

import 'package:cidy/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:cidy/authentication/login.dart';
import 'package:cidy/constants.dart';

class EditGroupForm extends StatefulWidget {
  final Map<String, dynamic> group;
  final VoidCallback onGroupUpdated;
  final Function onServerError;

  const EditGroupForm({
    super.key,
    required this.group,
    required this.onGroupUpdated,
    required this.onServerError,
  });

  @override
  State<EditGroupForm> createState() => _EditGroupFormState();
}

class _EditGroupFormState extends State<EditGroupForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();

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

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _startTimeController.text = _startTime != null
        ? _formatTime(_startTime!)
        : '';
    _endTimeController.text = _endTime != null ? _formatTime(_endTime!) : '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
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
      if (!mounted) return;

      if (token == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
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

      if (!mounted) return;

      if (response.statusCode == 200) {
        widget.onGroupUpdated();
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
          } else if (errorType == 'SCHEDULE_CONFLICT_DETECTED') {
            setState(() {
              _timeError = 'Cet horaire entre en conflit avec un autre groupe.';
            });
          } else {
            // For other 400 errors, show snackbar
            widget.onServerError('Erreur de validation (400)');
          }
        } else {
          widget.onServerError('Erreur de validation (400)');
        }
      } else {
        widget.onServerError('Erreur de serveur (500).');
      }
    } catch (e) {
      widget.onServerError('Erreur de serveur (500).');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Apply theme to make all cursors and dropdown icons use primary color
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(
          context,
        ).colorScheme.copyWith(primary: Theme.of(context).primaryColor),
      ),
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 0,
        ), // 👈 margins on left/right
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height *
                0.7, // 70% of screen height
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Modifier le groupe',
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
        onPressed: _isLoading ? null : _editGroup,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Modifier',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            cursorColor: Theme.of(context).primaryColor,
            decoration: InputDecoration(
              labelText: 'Nom du groupe',
              labelStyle: TextStyle(color: Theme.of(context).primaryColor),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).primaryColor),
                borderRadius: BorderRadius.circular(8.0),
              ),
              errorText: null,
              errorBorder: _nameError != null
                  ? OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                      borderRadius: BorderRadius.circular(8.0),
                    )
                  : null,
              focusedErrorBorder: _nameError != null
                  ? OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                      borderRadius: BorderRadius.circular(8.0),
                    )
                  : null,
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
          if (_nameError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _nameError!,
                style: const TextStyle(color: Colors.red, fontSize: 15),
                softWrap: true,
              ),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedDayEnglish,
            dropdownColor: Colors.white,
            iconEnabledColor: Theme.of(context).primaryColor,
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
          if (_hasScheduleChanged()) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _scheduleChangeType,
              dropdownColor: Colors.white,
              iconEnabledColor: Theme.of(context).primaryColor,
              decoration: InputDecoration(
                labelText: 'Type de changement d\'horaire',
                labelStyle: TextStyle(color: Theme.of(context).primaryColor),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'temporary',
                  child: Text('Seulement cette semaine'),
                ),
                DropdownMenuItem(value: 'permanent', child: Text('Permanent')),
              ],
              onChanged: (String? value) {
                setState(() {
                  _scheduleChangeType = value;
                });
              },
              validator: (value) {
                if (_hasScheduleChanged() && (value == null || value.isEmpty)) {
                  return 'Veuillez spécifier le type de changement';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _startTimeController,
                cursorColor: Theme.of(context).primaryColor,
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
                  hintText: 'HH:MM',
                ),
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
                cursorColor: Theme.of(context).primaryColor,
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
                  hintText: 'HH:MM',
                ),
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
              style: const TextStyle(color: Colors.red, fontSize: 15),
              softWrap: true,
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
