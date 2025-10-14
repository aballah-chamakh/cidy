import 'dart:convert';

import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:flutter/material.dart';
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

  Future<void> _markAttendance() async {
    if (selectedStartTime == null || selectedEndTime == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) {
        // Handle token absence
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
              "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
          'start_time':
              '${selectedStartTime!.hour.toString().padLeft(2, '0')}:${selectedStartTime!.minute.toString().padLeft(2, '0')}',
          'end_time':
              '${selectedEndTime!.hour.toString().padLeft(2, '0')}:${selectedEndTime!.minute.toString().padLeft(2, '0')}',
        }),
      );

      if (response.statusCode == 200) {
        widget.onSuccess();
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Échec du marquage de la présence')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Erreur de connexion')));
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Marquer présence (${widget.studentCount})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Icon(
                    Icons.check_circle_outline,
                    size: 60,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    title: const Text('Date'),
                    subtitle: Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('Heure de début'),
                    subtitle: Text(
                      selectedStartTime != null
                          ? selectedStartTime!.format(context)
                          : 'Sélectionner l\'heure',
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: selectedStartTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedStartTime = picked;
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('Heure de fin'),
                    subtitle: Text(
                      selectedEndTime != null
                          ? selectedEndTime!.format(context)
                          : 'Sélectionner l\'heure',
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: selectedEndTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedEndTime = picked;
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
                          onPressed:
                              selectedStartTime != null &&
                                  selectedEndTime != null
                              ? _markAttendance
                              : null,
                          child: const Text('Marquer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
