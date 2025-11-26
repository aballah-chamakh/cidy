import 'dart:convert';
import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:cidy/authentication/login.dart';
import 'package:cidy/constants.dart';

class EditGroupPopup extends StatefulWidget {
  final Map<String, dynamic> group;
  final VoidCallback onGroupUpdated;
  final Function onServerError;

  const EditGroupPopup({
    super.key,
    required this.group,
    required this.onGroupUpdated,
    required this.onServerError,
  });

  @override
  State<EditGroupPopup> createState() => _EditGroupPopupState();
}

class _EditGroupPopupState extends State<EditGroupPopup> {
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
    if (!mounted) return;
    if (_isLoading) return;
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

    /*
    if (_hasScheduleChanged() && _scheduleChangeType == null) {
      setState(() {
        _timeError =
            'Veuillez spécifier si le changement d\'horaire est permanent ou temporaire';
      });
      return;
    }*/

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
      /*
      if (_hasScheduleChanged()) {
        requestBody['schedule_change_type'] = _scheduleChangeType == 'permanent'
            ? 'permanent'
            : 'temporary';
      }
      */

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
            widget.onServerError('Erreur de validation (400)');
          }
        } else {
          widget.onServerError('Erreur de validation (400)');
        }
      } else {
        widget.onServerError('Erreur de serveur (500).');
      }
    } catch (e) {
      if (!mounted) return;
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
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: popupHorizontalMargin,
        vertical: 0,
      ),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(popupBorderRadius),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Container(
          padding: const EdgeInsets.all(popupPadding),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(popupBorderRadius),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const Divider(height: 5),
                const SizedBox(height: 5.0),
                Flexible(child: _buildFormContent()),
                const Divider(height: 30),
                _buildFooter(),
              ],
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
            fontSize: headerFontSize,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
          textAlign: TextAlign.left,
        ),
        IconButton(
          icon: Icon(Icons.close, size: headerIconSize, color: primaryColor),
          padding: EdgeInsets.zero, // 👈 removes default padding
          constraints: const BoxConstraints(), // 👈 removes default constraints
          onPressed: _isLoading
              ? null
              : () {
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Expanded(
          child: AbsorbPointer(
            absorbing: _isLoading,
            child: TextButton(
              style: secondaryButtonStyle,
              onPressed: () {
                if (!mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text(
                'Annuler',
                style: TextStyle(fontSize: mediumFontSize),
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: AbsorbPointer(
            absorbing: _isLoading,
            child: ElevatedButton(
              onPressed: _editGroup,
              style: primaryButtonStyle,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Modifier',
                    style: TextStyle(
                      fontSize: mediumFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isLoading) ...[
                    const SizedBox(width: 12),
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
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
            enabled: !_isLoading,
            cursorColor: primaryColor,
            style: TextStyle(
              fontSize: mediumFontSize, // 👈 sets the input text size
            ),
            decoration: InputDecoration(
              labelText: 'Nom du groupe',
              labelStyle: TextStyle(color: primaryColor),
              contentPadding: inputContentPadding,
              errorMaxLines: 3,
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: primaryColor),
                borderRadius: BorderRadius.circular(inputBorderRadius),
              ),
              errorText: null,
              errorBorder: _nameError != null
                  ? OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                      borderRadius: BorderRadius.circular(inputBorderRadius),
                    )
                  : null,
              focusedErrorBorder: _nameError != null
                  ? OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                      borderRadius: BorderRadius.circular(inputBorderRadius),
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
            iconEnabledColor: primaryColor,

            decoration: InputDecoration(
              labelText: 'Jour de la semaine',
              labelStyle: TextStyle(color: primaryColor),
              contentPadding: inputContentPadding,
              errorMaxLines: 3,
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: primaryColor),
                borderRadius: BorderRadius.circular(inputBorderRadius),
              ),
            ),
            items: [
              ...weekDays.map(
                (d) => DropdownMenuItem<String>(
                  value: d['value']!,
                  child: Text(
                    d['name']!,
                    style: TextStyle(fontSize: mediumFontSize),
                  ),
                ),
              ),
            ],
            onChanged: _isLoading
                ? null
                : (value) {
                    if (!mounted) return;
                    setState(() {
                      _selectedDayEnglish = value;
                    });
                  },
            validator: (value) => value == null ? 'Sélectionnez un jour' : null,
          ),
          const SizedBox(height: 16),
          _buildTimeRangeSelector(),
          /*
          if (_hasScheduleChanged()) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _scheduleChangeType,
              dropdownColor: Colors.white,
              iconEnabledColor: primaryColor,
              decoration: InputDecoration(
                labelText: 'Type de changement d\'horaire',
                contentPadding: inputContentPadding,
                labelStyle: TextStyle(color: primaryColor),
                errorMaxLines: 3,
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor),
                  borderRadius: BorderRadius.circular(inputBorderRadius),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'temporary',
                  child: Text(
                    'Seulement cette semaine',
                    style: TextStyle(
                      fontSize: mediumFontSize, // 👈 sets the input text size
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'permanent',
                  child: Text(
                    'Permanent',
                    style: TextStyle(
                      fontSize: mediumFontSize, // 👈 sets the input text size
                    ),
                  ),
                ),
              ],
              onChanged: _isLoading
                  ? null
                  : (String? value) {
                      if (!mounted) return;
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
      
          ],*/
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
                enabled: !_isLoading,
                cursorColor: primaryColor,
                style: TextStyle(
                  fontSize: mediumFontSize, // 👈 sets the input text size
                ),
                decoration: InputDecoration(
                  contentPadding: inputContentPadding,
                  labelText: 'Heure de début',
                  labelStyle: TextStyle(color: primaryColor),
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: primaryColor),
                    borderRadius: BorderRadius.circular(inputBorderRadius),
                  ),
                  hintText: 'HH:MM',
                  hintStyle: TextStyle(
                    fontSize: mediumFontSize, // 👈 sets the input text size
                  ),
                  errorMaxLines: 3,
                ),
                keyboardType: TextInputType.datetime,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                  _TimeTextInputFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Requis";
                  }
                  final time = _parseTime(value);
                  if (time == null) return 'Format invalide';
                  if (time.hour < 8) return 'Min 08:00';
                  return null;
                },
                onChanged: (value) {
                  if (!mounted) return;
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
                enabled: !_isLoading,
                cursorColor: primaryColor,
                decoration: InputDecoration(
                  contentPadding: inputContentPadding,
                  labelText: 'Heure de fin',
                  labelStyle: TextStyle(color: primaryColor),
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: primaryColor),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  hintText: 'HH:MM',
                  hintStyle: TextStyle(
                    fontSize: mediumFontSize, // 👈 sets the input text size
                  ),
                  errorMaxLines: 3,
                ),
                keyboardType: TextInputType.datetime,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                  _TimeTextInputFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Requis";
                  }
                  final time = _parseTime(value);
                  final startTime = _parseTime(_startTimeController.text);
                  if (time == null) return 'Format invalide';
                  if (time.hour == 0 && time.minute > 0) return 'Max 00:00';
                  if (time.hour > 0 && time.hour < 8) return 'Max 00:00';
                  if (time.hour == 8 && time.minute == 0) return 'Max 00:00';

                  if (time.hour != 0 &&
                      startTime != null &&
                      (time.hour < startTime.hour ||
                          (time.hour == startTime.hour &&
                              time.minute < startTime.minute))) {
                    return 'Début > Fin';
                  }
                  if (startTime != null &&
                      time.hour == startTime.hour &&
                      time.minute == startTime.minute) {
                    return 'Début == Fin';
                  }
                  return null;
                },
                onChanged: (value) {
                  if (!mounted) return;
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
                onPressed: _isLoading
                    ? null
                    : () {
                        if (!mounted) return;
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

    if (text.length == 2) {
      final hour = int.tryParse(text);
      if (hour != null && hour > 23) {
        if (oldValue.text.length == 1 && int.tryParse(oldValue.text) != null) {
          final firstDigit = oldValue.text;
          final secondDigit = text.substring(1);
          text = '0$firstDigit:$secondDigit';

          final minuteDigit = int.tryParse(secondDigit);
          if (minuteDigit != null && minuteDigit > 5) {
            text = '0$firstDigit:0$secondDigit';
          }

          return TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }
      }
    }

    if (text.length > 2) {
      text = '${text.substring(0, 2)}:${text.substring(2)}';
    }

    // Validate hour and minute
    if (text.contains(':')) {
      final parts = text.split(':');
      final hour = int.tryParse(parts[0]);

      if (parts.length > 1 &&
          parts[1].length == 1 &&
          newValue.text.length > oldValue.text.length) {
        final m = int.tryParse(parts[1]);
        if (m != null && m > 5) {
          text = '${parts[0]}:0$m';
          return TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }
      }

      final minute = int.tryParse(parts[1]);

      if (hour != null && hour > 23) {
        return oldValue;
      }
      if (minute != null && minute > 59) {
        return oldValue;
      }
    } else if (text.length == 2) {
      final hour = int.tryParse(text);
      if (hour != null && hour > 23) {
        return oldValue;
      }
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
