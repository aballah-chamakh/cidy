import 'dart:convert';

import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class UnmarkPaymentPopup extends StatefulWidget {
  final int studentCount;
  final VoidCallback onSuccess;
  final Set<int> studentIds;

  const UnmarkPaymentPopup({
    super.key,
    required this.studentCount,
    required this.onSuccess,
    required this.studentIds,
  });

  @override
  State<UnmarkPaymentPopup> createState() => _UnmarkPaymentPopupState();
}

class _UnmarkPaymentPopupState extends State<UnmarkPaymentPopup> {
  int numberOfClasses = 1;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  Future<void> _unmarkPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

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
        '${Config.backendUrl}/api/teacher/groups/unmark-payment/',
      );
      final response = await http.post(
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
        widget.onSuccess();
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Échec de l\'annulation du paiement')),
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
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Annuler paiement (${widget.studentCount})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    const Icon(Icons.money_off, size: 60, color: Colors.red),
                    const SizedBox(height: 20),
                    TextFormField(
                      initialValue: numberOfClasses.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Nombre de cours à annuler le paiement',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
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
                      onSaved: (value) {
                        numberOfClasses = int.parse(value!);
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: TextButton(
                            style: secondaryButtonStyle,
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: primaryButtonStyle,
                            onPressed: _unmarkPayment,
                            child: const Text('Confirmer'),
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
