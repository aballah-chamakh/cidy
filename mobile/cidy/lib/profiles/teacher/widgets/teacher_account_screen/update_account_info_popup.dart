import 'dart:convert';
import 'dart:io';
import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:cidy/authentication/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class UpdateAccountInfoPopup extends StatefulWidget {
  final String fullName;
  final String email;
  final String phoneNumber;
  final String gender;
  final File? imageFile;
  final VoidCallback onSuccess;
  final VoidCallback onServerError;
  final void Function(Map<String, String> fieldErrors) onValidationError;

  const UpdateAccountInfoPopup({
    super.key,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.gender,
    this.imageFile,
    required this.onSuccess,
    required this.onServerError,
    required this.onValidationError,
  });

  @override
  State<UpdateAccountInfoPopup> createState() => _UpdateAccountInfoPopupState();
}

class _UpdateAccountInfoPopupState extends State<UpdateAccountInfoPopup> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPasswordObscured = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _updateAccountInfo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (!mounted) return;

      if (token == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
        return;
      }

      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('${Config.backendUrl}/api/teacher/account/update/'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['fullname'] = widget.fullName;
      request.fields['email'] = widget.email;
      request.fields['phone_number'] = widget.phoneNumber;
      request.fields['gender'] = widget.gender;
      request.fields['current_password'] = _passwordController.text;

      if (widget.imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', widget.imageFile!.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200) {
        widget.onSuccess();
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        final dynamic passwordErrors = responseData['current_password'];
        if (passwordErrors is List &&
            passwordErrors.isNotEmpty &&
            passwordErrors.first == 'Incorrect current password.') {
          setState(() {
            _errorMessage = 'Le mot de passe actuel est incorrect.';
          });
          return;
        }

        final Map<String, String> fieldErrors = {};
        final dynamic emailErrors = responseData['email'];
        if (emailErrors is List && emailErrors.isNotEmpty) {
          final dynamic firstError = emailErrors.first;
          if (firstError == 'This email is already in use.') {
            fieldErrors['email'] = 'Cet e-mail est déjà utilisé.';
          }
        }

        final dynamic phoneErrors = responseData['phone_number'];
        if (phoneErrors is List && phoneErrors.isNotEmpty) {
          final dynamic firstError = phoneErrors.first;
          if (firstError == 'This phone number is already in use.') {
            fieldErrors['phone_number'] =
                'Ce numéro de téléphone est déjà utilisé.';
          }
        }

        if (fieldErrors.isNotEmpty) {
          widget.onValidationError(fieldErrors);
          if (mounted) {
            Navigator.of(context).pop();
          }
          return;
        }
      } else {
        widget.onServerError();
      }
    } catch (e) {
      if (!mounted) return;
      widget.onServerError();
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                const Divider(height: 16),
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        _buildPasswordInput(),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          _buildErrorMessage(),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(height: 30),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Confirmez votre autorisation',
            style: TextStyle(
              fontSize: headerFontSize,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.close,
            weight: 2.0,
            color: primaryColor,
            size: headerIconSize,
          ),
          onPressed: _isLoading
              ? null
              : () {
                  Navigator.of(context).pop();
                },
        ),
      ],
    );
  }

  Widget _buildPasswordInput() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _isPasswordObscured,
      enabled: !_isLoading,
      decoration: InputDecoration(
        labelText: 'Mot de passe actuel',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: inputContentPadding,
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordObscured ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _isPasswordObscured = !_isPasswordObscured;
                  });
                },
        ),
      ),
      style: const TextStyle(fontSize: mediumFontSize),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Le mot de passe est requis';
        }
        return null;
      },
    );
  }

  Widget _buildErrorMessage() {
    return Text(
      _errorMessage!,
      style: const TextStyle(color: Colors.red, fontSize: mediumFontSize),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            style: secondaryButtonStyle,
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
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
            onPressed: _isLoading ? null : _updateAccountInfo,
            child: _isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Confirmer',
                        style: TextStyle(fontSize: mediumFontSize),
                      ),
                      SizedBox(width: 10),
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                : const FittedBox(
                    child: Text(
                      'Confirmer',
                      style: TextStyle(fontSize: mediumFontSize),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
