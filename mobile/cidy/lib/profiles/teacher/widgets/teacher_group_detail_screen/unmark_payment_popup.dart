import 'dart:convert';

import 'package:cidy/app_styles.dart';
import 'package:cidy/authentication/login.dart';
import 'package:cidy/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class UnmarkPaymentPopup extends StatefulWidget {
  final int groupId;
  final int studentCount;
  final Set<int> studentIds;
  final void Function({
    required int requestedClasses,
    required int fullyUnmarkedCount,
    required List studentsWithMissingClasses,
  })
  onSuccess;
  final VoidCallback onError;

  const UnmarkPaymentPopup({
    super.key,
    required this.groupId,
    required this.studentCount,
    required this.onSuccess,
    required this.onError,
    required this.studentIds,
  });

  @override
  State<UnmarkPaymentPopup> createState() => _UnmarkPaymentPopupState();
}

class _UnmarkPaymentPopupState extends State<UnmarkPaymentPopup> {
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

  Future<void> _unmarkPayment() async {
    if (!mounted) return;
    if (_isLoading) return;
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
        '${Config.backendUrl}/api/teacher/groups/${widget.groupId}/students/unmark_payment/',
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

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final fullyUnmarkedCount =
            responseData['students_unmarked_completely_count'];
        final studentsWithMissingClasses =
            responseData['students_without_enough_paid_classes_to_unmark'];

        widget.onSuccess(
          requestedClasses: numberOfClasses,
          fullyUnmarkedCount: fullyUnmarkedCount,
          studentsWithMissingClasses: studentsWithMissingClasses,
        );
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
                  'Annuler le paiement',
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
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.attach_money,
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
                        const TextSpan(text: 'Annuler le paiement de '),
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
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de séances à annuler',
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
                        child: AbsorbPointer(
                          absorbing: _isLoading,
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
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: AbsorbPointer(
                          absorbing: _isLoading,
                          child: ElevatedButton(
                            style: primaryButtonStyle,
                            onPressed: _unmarkPayment,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Confirmer',
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
            ),
          ],
        ),
      ),
    );
  }
}
