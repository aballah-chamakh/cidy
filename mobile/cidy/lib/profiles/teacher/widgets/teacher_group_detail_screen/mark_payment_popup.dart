import 'dart:convert';

import 'package:cidy/app_styles.dart';
import 'package:cidy/authentication/login.dart';
import 'package:cidy/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class MarkPaymentPopup extends StatefulWidget {
  final int studentCount;
  final Set<int> studentIds;
  final int groupId;
  final VoidCallback onSuccess;
  final VoidCallback onError;

  const MarkPaymentPopup({
    super.key,
    required this.studentCount,
    required this.groupId,
    required this.studentIds,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<MarkPaymentPopup> createState() => _MarkPaymentPopupState();
}

class _MarkPaymentPopupState extends State<MarkPaymentPopup> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late final TextEditingController _numberOfClassesController;
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _numberOfClassesController = TextEditingController(text: '1');
    _dateController = TextEditingController(
      text:
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
    );
    _timeController = TextEditingController(
      text:
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
    );
  }

  @override
  void dispose() {
    _numberOfClassesController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _markPayment() async {
    if (!mounted) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final numberOfClasses = int.parse(_numberOfClassesController.text);

      final dateParts = _dateController.text.split('/');
      final parsedDate = DateTime(
        int.parse(dateParts[2]),
        int.parse(dateParts[1]),
        int.parse(dateParts[0]),
      );

      final timeParts = _timeController.text.split(':');
      final parsedTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );

      final paymentDateTime = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
        parsedTime.hour,
        parsedTime.minute,
      );

      final formattedPaymentDateTime = DateFormat(
        'HH:mm:ss-dd/MM/yyyy',
      ).format(paymentDateTime);

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
        '${Config.backendUrl}/api/teacher/groups/${widget.groupId}/students/mark_payment/',
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
          'payment_datetime': formattedPaymentDateTime,
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
                  'Marquer le paiement',
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
                    const Icon(Icons.payment, size: 100, color: primaryColor),
                    const SizedBox(height: 20),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: mediumFontSize,
                          color: Colors.black,
                        ),
                        children: <TextSpan>[
                          const TextSpan(text: 'Marquer le paiement de '),
                          TextSpan(
                            text: '${widget.studentCount}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text:
                                ' ${widget.studentCount > 1 ? 'étudiants' : 'étudiant'} '
                                'pour le nombre de séances, la date et l’heure spécifiés.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _numberOfClassesController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de séances',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez saisir le nombre de séances';
                        }
                        final count = int.tryParse(value);
                        if (count == null || count <= 0) {
                          return 'Nombre de séances invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dateController,
                      decoration: const InputDecoration(
                        labelText: 'Date du paiement (jj/mm/aaaa)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.datetime,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                        _DateTextInputFormatter(),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez saisir une date';
                        }
                        try {
                          final parts = value.split('/');
                          if (parts.length != 3) throw FormatException();
                          final day = int.parse(parts[0]);
                          final month = int.parse(parts[1]);
                          final year = int.parse(parts[2]);
                          if (day < 1 || day > 31 || month < 1 || month > 12) {
                            return 'Date invalide';
                          }
                          if (year < 2020) {
                            return 'L\'année doit être 2020 ou plus';
                          }
                        } catch (e) {
                          return 'Format invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _timeController,
                      decoration: const InputDecoration(
                        labelText: 'Heure du paiement (HH:mm)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.datetime,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                        _TimeTextInputFormatter(),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez saisir l\'heure';
                        }
                        try {
                          final parts = value.split(':');
                          if (parts.length != 2) throw FormatException();
                          final hour = int.parse(parts[0]);
                          final minute = int.parse(parts[1]);
                          if (hour < 0 ||
                              hour > 23 ||
                              minute < 0 ||
                              minute > 59) {
                            return 'Heure invalide';
                          }
                        } catch (e) {
                          return 'Format invalide';
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
                            onPressed: _markPayment,
                            child: const Text(
                              'Marquer',
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
        if (year != null && year < 2020) {
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
