import 'dart:convert';

import 'package:cidy/app_styles.dart';
import 'package:cidy/authentication/login.dart';
import 'package:cidy/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class UnmarkAttendancePopup extends StatefulWidget {
  final int studentCount;
  final int groupId;
  final VoidCallback onSuccess;
  final VoidCallback onError;
  final Set<int> studentIds;

  const UnmarkAttendancePopup({
    super.key,
    required this.groupId,
    required this.studentCount,
    required this.onSuccess,
    required this.onError,
    required this.studentIds,
  });

  @override
  State<UnmarkAttendancePopup> createState() => _UnmarkAttendancePopupState();
}

class _UnmarkAttendancePopupState extends State<UnmarkAttendancePopup> {
  int numberOfClasses = 1;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numberOfClassesController;

  @override
  void initState() {
    super.initState();
    _numberOfClassesController = TextEditingController(
      text: numberOfClasses.toString(),
    );
  }

  @override
  void dispose() {
    _numberOfClassesController.dispose();
    super.dispose();
  }

  Future<void> _unmarkAttendance() async {
    if (!mounted) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }
    numberOfClasses = int.parse(_numberOfClassesController.text);

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
        '${Config.backendUrl}/api/teacher/groups/${widget.groupId}/students/unmark_attendance/',
      );
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'student_ids': widget.studentIds.toList(),
          'number_of_classes': numberOfClasses,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        widget.onSuccess();
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        widget.onError();
      }
    } catch (e) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Annuler la présence',
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
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(color: primaryColor),
                ),
              )
            else
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Icon(
                      Icons.event_busy,
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
                          const TextSpan(text: 'Annuler la présence de '),
                          TextSpan(
                            text: '${widget.studentCount}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text:
                                ' ${widget.studentCount > 1 ? 'étudiants' : 'étudiant'} pour le nombre de séances indiqué.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _numberOfClassesController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de seances à annuler',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un nombre';
                        }
                        final n = int.tryParse(value);
                        if (n == null) {
                          return 'Veuillez entrer un nombre valide';
                        }
                        if (n <= 0) {
                          return 'Le nombre doit être supérieur à zéro';
                        }
                        return null;
                      },
                    ),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: TextButton(
                            style: secondaryButtonStyle,
                            onPressed: () {
                              if (!mounted) return;
                              Navigator.of(context).pop(false);
                            },
                            child: const Text(
                              'Annuler',
                              style: TextStyle(fontSize: mediumFontSize),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: ElevatedButton(
                            style: primaryButtonStyle,
                            onPressed: _unmarkAttendance,
                            child: const Text(
                              'Confirmer',
                              style: TextStyle(fontSize: mediumFontSize),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
