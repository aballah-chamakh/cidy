import 'dart:convert';

import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class MarkAttendancePopup extends StatefulWidget {
  final int studentCount;
  final VoidCallback onSuccess;
  final Set<int> studentIds;

  const MarkAttendancePopup({
    super.key,
    required this.studentCount,
    required this.onSuccess,
    required this.studentIds,
  });

  @override
  State<MarkAttendancePopup> createState() => _MarkAttendancePopupState();
}

class _MarkAttendancePopupState extends State<MarkAttendancePopup> {
  DateTime selectedDate = DateTime.now();
  TimeOfDay? selectedStartTime;
  TimeOfDay? selectedEndTime;
  bool _isLoading = false;

  late final TextEditingController _dateController;
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;

  String? _dateError;
  String? _startTimeError;
  String? _endTimeError;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text:
          '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
    );
    _startTimeController = TextEditingController();
    _endTimeController = TextEditingController();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  Future<void> _markAttendance() async {
    // Validate all fields and collect errors
    String? dateError;
    String? startTimeError;
    String? endTimeError;

    // Validate date
    if (_dateController.text.isEmpty) {
      dateError = 'Veuillez saisir une date';
    } else {
      try {
        final parts = _dateController.text.split('/');
        if (parts.length != 3 ||
            parts[0].length != 2 ||
            parts[1].length != 2 ||
            parts[2].length != 4) throw FormatException();
        int day = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int year = int.parse(parts[2]);
        if (day < 1 || day > 31 || month < 1 || month > 12 || year < 2024) {
          dateError = 'Date invalide';
        }
      } catch (e) {
        dateError = 'Format invalide';
      }
    }

    // Validate start time
    if (_startTimeController.text.isEmpty) {
      startTimeError = 'Veuillez saisir l\'heure de début';
    } else {
      try {
        final parts = _startTimeController.text.split(':');
        if (parts.length != 2 || parts[0].length != 2 || parts[1].length != 2) {
          throw FormatException();
        }
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
          startTimeError = 'Heure invalide';
        }
      } catch (e) {
        startTimeError = 'Format invalide';
      }
    }

    // Validate end time
    if (_endTimeController.text.isEmpty) {
      endTimeError = 'Veuillez saisir l\'heure de fin';
    } else {
      try {
        final parts = _endTimeController.text.split(':');
        if (parts.length != 2 || parts[0].length != 2 || parts[1].length != 2) {
          throw FormatException();
        }
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
          endTimeError = 'Heure invalide';
        }
      } catch (e) {
        endTimeError = 'Format invalide';
      }
    }

    // Update the UI with all errors at once
    setState(() {
      _dateError = dateError;
      _startTimeError = startTimeError;
      _endTimeError = endTimeError;
    });

    // If there are any errors, stop processing
    if (dateError != null || startTimeError != null || endTimeError != null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Parse date and time from controllers
      final dateParts = _dateController.text.split('/');
      final parsedDate = DateTime(
        int.parse(dateParts[2]),
        int.parse(dateParts[1]),
        int.parse(dateParts[0]),
      );

      final startTimeParts = _startTimeController.text.split(':');
      final parsedStartTime = TimeOfDay(
        hour: int.parse(startTimeParts[0]),
        minute: int.parse(startTimeParts[1]),
      );

      final endTimeParts = _endTimeController.text.split(':');
      final parsedEndTime = TimeOfDay(
        hour: int.parse(endTimeParts[0]),
        minute: int.parse(endTimeParts[1]),
      );

      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) {
        // Handle token absence
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur d\'authentification')),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/groups/mark-attendance/',
      );
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'student_ids': widget.studentIds.toList(),
          'date':
              "${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}",
          'start_time':
              '${parsedStartTime.hour.toString().padLeft(2, '0')}:${parsedStartTime.minute.toString().padLeft(2, '0')}',
          'end_time':
              '${parsedEndTime.hour.toString().padLeft(2, '0')}:${parsedEndTime.minute.toString().padLeft(2, '0')}',
        }),
      );

      if (response.statusCode == 200) {
        widget.onSuccess();
        if (mounted) Navigator.of(context).pop();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Échec du marquage de la présence')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Format de date/heure invalide')),
        );
      }
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
      child: Container(
        padding: const EdgeInsets.all(popupPadding),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(popupBorderRadius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Confirmer le retrait',
                  style: TextStyle(
                    fontSize: headerFontSize,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: headerIconSize,
                    color: primaryColor,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
              ],
            ),
            const Divider(height: 5),
            const SizedBox(height: 20.0),
            if (_isLoading)
              Padding(
                padding: EdgeInsetsGeometry.all(40),
                child: const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                ),
              )
            else ...[
              const Icon(Icons.event_available, size: 100, color: primaryColor),
              const SizedBox(height: 20),
              TextFormField(
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: 'Date (jj/mm/aaaa) *',
                  border: const OutlineInputBorder(),
                  errorText: _dateError,
                  errorBorder: _dateError != null
                      ? OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.red),
                          borderRadius: BorderRadius.circular(4.0),
                        )
                      : null,
                  focusedErrorBorder: _dateError != null
                      ? OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.red),
                          borderRadius: BorderRadius.circular(4.0),
                        )
                      : null,
                ),
                keyboardType: TextInputType.datetime,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                  _DateTextInputFormatter(),
                ],
                onChanged: (value) {
                  if (_dateError != null) {
                    setState(() {
                      _dateError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _startTimeController,
                decoration: InputDecoration(
                  labelText: 'Heure de début (HH:mm) *',
                  border: const OutlineInputBorder(),
                  errorText: _startTimeError,
                  errorBorder: _startTimeError != null
                      ? OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.red),
                          borderRadius: BorderRadius.circular(4.0),
                        )
                      : null,
                  focusedErrorBorder: _startTimeError != null
                      ? OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.red),
                          borderRadius: BorderRadius.circular(4.0),
                        )
                      : null,
                ),
                keyboardType: TextInputType.datetime,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                  _TimeTextInputFormatter(),
                ],
                onChanged: (value) {
                  if (_startTimeError != null) {
                    setState(() {
                      _startTimeError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _endTimeController,
                decoration: InputDecoration(
                  labelText: 'Heure de fin (HH:mm) *',
                  border: const OutlineInputBorder(),
                  errorText: _endTimeError,
                  errorBorder: _endTimeError != null
                      ? OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.red),
                          borderRadius: BorderRadius.circular(4.0),
                        )
                      : null,
                  focusedErrorBorder: _endTimeError != null
                      ? OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.red),
                          borderRadius: BorderRadius.circular(4.0),
                        )
                      : null,
                ),
                keyboardType: TextInputType.datetime,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                  _TimeTextInputFormatter(),
                ],
                onChanged: (value) {
                  if (_endTimeError != null) {
                    setState(() {
                      _endTimeError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: TextButton(
                      style: secondaryButtonStyle,
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: primaryButtonStyle,
                      onPressed: _markAttendance,
                      child: const Text('Marquer'),
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

class _DateTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text;
    if (newText.length > 10) {
      return oldValue;
    }

    String text = newText.replaceAll('/', '');

    if (text.length == 2) {
      final day = int.tryParse(text);
      if (day != null && day > 31) {
        if (oldValue.text.length == 1 && int.tryParse(oldValue.text) != null) {
          final firstDigit = oldValue.text;
          final secondDigit = text.substring(1);
          text = '0$firstDigit/$secondDigit';
          return TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }
      }
    } else if (text.length == 4) {
      final month = int.tryParse(text.substring(2, 4));
      if (month != null && month > 12) {
        if (oldValue.text.length == 4 &&
            int.tryParse(oldValue.text.substring(3, 4)) != null) {
          final day = text.substring(0, 2);
          final firstDigit = oldValue.text.substring(3, 4);
          final secondDigit = text.substring(3, 4);
          text = '$day/0$firstDigit/$secondDigit';
          return TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }
      }
    }

    if (text.length > 4) {
      text =
          '${text.substring(0, 2)}/${text.substring(2, 4)}/${text.substring(4)}';
    } else if (text.length > 2) {
      text = '${text.substring(0, 2)}/${text.substring(2)}';
    }

    // Validate day and month
    if (text.contains('/')) {
      final parts = text.split('/');
      if (parts.isNotEmpty && parts[0].length == 2) {
        final day = int.tryParse(parts[0]);
        if (day != null && day > 31) {
          return oldValue;
        }
      }
      if (parts.length > 1 && parts[1].length == 2) {
        final month = int.tryParse(parts[1]);
        if (month != null && month > 12) {
          return oldValue;
        }
      }
      if (parts.length == 3 && parts[2].length == 4) {
        final year = int.tryParse(parts[2]);
        if (year != null && year < 2025) {
          return oldValue;
        }
      }
    } else {
      if (text.length == 2) {
        final day = int.tryParse(text);
        if (day != null && day > 31) {
          return oldValue;
        }
      }
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
