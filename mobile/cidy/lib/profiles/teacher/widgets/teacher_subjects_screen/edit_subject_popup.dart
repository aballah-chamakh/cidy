import 'dart:convert';
import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cidy/authentication/login.dart';

class EditSubjectPopup extends StatefulWidget {
  final String subjectName;
  final int teacherSubjectId;
  final double initialPrice;
  final VoidCallback onSubjectUpdated;

  const EditSubjectPopup({
    super.key,
    required this.subjectName,
    required this.teacherSubjectId,
    required this.initialPrice,
    required this.onSubjectUpdated,
  });

  @override
  State<EditSubjectPopup> createState() => _EditSubjectPopupState();
}

class _EditSubjectPopupState extends State<EditSubjectPopup> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _priceController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _priceController.text = widget.initialPrice.toString();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _updateSubjectPrice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      const storage = FlutterSecureStorage();
      final accessToken = await storage.read(key: 'accessToken');
      if (accessToken == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
        return;
      }

      final response = await http.put(
        Uri.parse(
          '${Config.backendUrl}/api/teacher/subject/edit/${widget.teacherSubjectId}/',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'price_per_class': _priceController.text}),
      );

      if (response.statusCode == 200) {
        widget.onSubjectUpdated();
        Navigator.of(context).pop();
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _errorMessage = errorData['detail'] ?? 'Failed to update price.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Edit the ${widget.subjectName}',
                      style: AppStyles.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price per class (DT)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a price.';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price < 1) {
                    return 'Please enter a valid price (min: 1).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: primaryButtonStyle,
                    onPressed: _isLoading ? null : _updateSubjectPrice,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Save'),
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
