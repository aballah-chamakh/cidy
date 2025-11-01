import 'dart:convert';
import 'package:cidy/authentication/login.dart';
import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class MarkAttendancePopup extends StatefulWidget {
  final int studentCount;
  final int groupId;
  final Set<int> studentIds;
  final String groupStartTime;
  final String groupEndTime;
  final String weekDay;
  final VoidCallback onSuccess;
  final VoidCallback onError;
  final void Function(int studentsMarkedCount, List overlappingStudents)
  onOverlapDetected;

  const MarkAttendancePopup({
    super.key,
    required this.studentCount,
    required this.groupId,
    required this.studentIds,
    required this.groupStartTime,
    required this.groupEndTime,
    required this.weekDay,
    required this.onSuccess,
    required this.onError,
    required this.onOverlapDetected,
  });

  @override
  State<MarkAttendancePopup> createState() => _MarkAttendancePopupState();
}

class _MarkAttendancePopupState extends State<MarkAttendancePopup> {
  final _formKey = GlobalKey<FormState>();
  DateTime selectedDate = DateTime.now();
  TimeOfDay? selectedStartTime;
  TimeOfDay? selectedEndTime;
  bool _isLoading = false;

  late final TextEditingController _dateController;
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;

  @override
  void initState() {
    super.initState();
    selectedDate = _getDateForWeekday(widget.weekDay);
    _dateController = TextEditingController(
      text:
          '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
    );
    _startTimeController = TextEditingController(text: widget.groupStartTime);
    _endTimeController = TextEditingController(text: widget.groupEndTime);
  }

  DateTime _getDateForWeekday(String weekday) {
    final now = DateTime.now();
    final englishWeekdays = {
      'Monday': DateTime.monday,
      'Tuesday': DateTime.tuesday,
      'Wednesday': DateTime.wednesday,
      'Thursday': DateTime.thursday,
      'Friday': DateTime.friday,
      'Saturday': DateTime.saturday,
      'Sunday': DateTime.sunday,
    };

    final targetWeekday = englishWeekdays[weekday];
    if (targetWeekday == null) {
      return now; // fallback to today
    }

    // Go back to the beginning of the week (Monday)
    var resultDate = now.subtract(Duration(days: now.weekday - 1));
    // Go forward to the target weekday
    resultDate = resultDate.add(Duration(days: targetWeekday - 1));

    return resultDate;
  }

  @override
  void dispose() {
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  Future<void> _markAttendance() async {
    if (!mounted) return;
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) {
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
      if (!mounted) return;

      if (token == null) {
        // Handle token absence
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
        return;
      }

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/groups/${widget.groupId}/students/mark_attendance/',
      );
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'student_ids': widget.studentIds.toList(),
          'date':
              "${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year}",
          'start_time':
              '${parsedStartTime.hour.toString().padLeft(2, '0')}:${parsedStartTime.minute.toString().padLeft(2, '0')}',
          'end_time':
              '${parsedEndTime.hour.toString().padLeft(2, '0')}:${parsedEndTime.minute.toString().padLeft(2, '0')}',
        }),
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final studentsMarkedCount = responseData['students_marked_count'];
        final overlappingStudents =
            responseData['students_with_overlapping_classes'];
        print(overlappingStudents);
        if (overlappingStudents.isNotEmpty) {
          if (!mounted) return;
          widget.onOverlapDetected(studentsMarkedCount, overlappingStudents);
        } else {
          widget.onSuccess();
        }
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        widget.onError();
      }
    } catch (e, stackTrace) {
      print("Error occurred while marking attendance: $e");
      print(stackTrace);
      if (!mounted) return;
      widget.onError();
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxDialogHeight = MediaQuery.of(context).size.height * 0.8;

            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxDialogHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Marquer la présence',
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
                          if (!mounted) return;
                          Navigator.of(context).pop(false);
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 5),
                  const SizedBox(height: 20.0),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.zero,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const Icon(
                              Icons.event_available,
                              size: 100,
                              color: primaryColor,
                            ),
                            const SizedBox(height: 20),
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: mediumFontSize,
                                  color: Colors.black,
                                ),
                                children: <TextSpan>[
                                  const TextSpan(
                                    text: 'Marquer la présence de ',
                                  ),
                                  TextSpan(
                                    text: '${widget.studentCount}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        ' ${widget.studentCount > 1 ? 'étudiants' : 'étudiant'} '
                                        'pour la date et la plage horaire spécifiées.',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _dateController,
                              enabled: !_isLoading,
                              decoration: const InputDecoration(
                                labelText: 'Date (jj/mm/aaaa) *',
                                border: OutlineInputBorder(),
                                errorMaxLines: 3,
                              ),
                              keyboardType: TextInputType.datetime,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9/]'),
                                ),
                                _DateTextInputFormatter(),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez saisir une date';
                                }
                                try {
                                  final parts = value.split('/');
                                  if (parts.length != 3)
                                    throw FormatException();
                                  int day = int.parse(parts[0]);
                                  int month = int.parse(parts[1]);
                                  int year = int.parse(parts[2]);
                                  if (day < 1 ||
                                      day > 31 ||
                                      month < 1 ||
                                      month > 12 ||
                                      year < 2025) {
                                    return 'Date invalide';
                                  }
                                } catch (e) {
                                  return 'Format invalide';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _startTimeController,
                              enabled: !_isLoading,
                              decoration: const InputDecoration(
                                labelText: 'Heure de début (HH:mm) *',
                                border: OutlineInputBorder(),
                                errorMaxLines: 3,
                              ),
                              keyboardType: TextInputType.datetime,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9:]'),
                                ),
                                _TimeTextInputFormatter(),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez saisir l\'heure de début';
                                }
                                try {
                                  final parts = value.split(':');
                                  if (parts.length != 2)
                                    throw FormatException();
                                  int hour = int.parse(parts[0]);
                                  int minute = int.parse(parts[1]);
                                  if (hour < 0 ||
                                      hour > 23 ||
                                      minute < 0 ||
                                      minute > 59) {
                                    return 'Heure invalide';
                                  }
                                  if (hour < 8) {
                                    return 'L\'heure doit être entre 8:00 et 00:00';
                                  }
                                } catch (e) {
                                  return 'Format invalide';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _endTimeController,
                              enabled: !_isLoading,
                              decoration: const InputDecoration(
                                labelText: 'Heure de fin (HH:mm) *',
                                border: OutlineInputBorder(),
                                errorMaxLines: 3,
                              ),
                              keyboardType: TextInputType.datetime,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9:]'),
                                ),
                                _TimeTextInputFormatter(),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez saisir l\'heure de fin';
                                }
                                try {
                                  final parts = value.split(':');
                                  if (parts.length != 2)
                                    throw FormatException();
                                  int hour = int.parse(parts[0]);
                                  int minute = int.parse(parts[1]);
                                  if (hour < 0 ||
                                      hour > 23 ||
                                      minute < 0 ||
                                      minute > 59) {
                                    return 'Heure invalide';
                                  }
                                  if (hour < 8 && hour != 0) {
                                    return 'L\'heure doit être entre 8:00 et 00:00';
                                  }

                                  if (_startTimeController.text.isNotEmpty) {
                                    final startParts = _startTimeController.text
                                        .split(':');
                                    if (startParts.length == 2) {
                                      int startHour = int.parse(startParts[0]);
                                      int startMinute = int.parse(
                                        startParts[1],
                                      );
                                      if (hour < startHour ||
                                          (hour == startHour &&
                                              minute < startMinute)) {
                                        return 'L\'heure de fin doit être après l\'heure de début';
                                      }
                                      if (hour == startHour &&
                                          minute == startMinute) {
                                        return 'L\'heure de fin doit être différente de l\'heure de début';
                                      }
                                    }
                                  }
                                } catch (e) {
                                  return 'Format invalide';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                            style: primaryButtonStyle,
                            onPressed: _markAttendance,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Marquer',
                                  style: TextStyle(fontSize: mediumFontSize),
                                ),
                                if (_isLoading) ...[
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
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
