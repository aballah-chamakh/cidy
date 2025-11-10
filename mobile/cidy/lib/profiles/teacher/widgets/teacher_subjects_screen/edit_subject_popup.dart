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
  final VoidCallback onServerError;

  const EditSubjectPopup({
    super.key,
    required this.subjectName,
    required this.teacherSubjectId,
    required this.initialPrice,
    required this.onSubjectUpdated,
    required this.onServerError,
  });

  @override
  State<EditSubjectPopup> createState() => _EditSubjectPopupState();
}

class _EditSubjectPopupState extends State<EditSubjectPopup> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _priceController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _priceController.text = _formatInitialPrice(widget.initialPrice);
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

      final response = await http.put(
        Uri.parse(
          '${Config.backendUrl}/api/teacher/subject/edit/${widget.teacherSubjectId}/',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'price_per_class':
              double.tryParse(_priceController.text.replaceAll(',', '.')) ??
              0.0,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        widget.onSubjectUpdated();
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      } else {
        widget.onServerError();
      }
    } catch (e) {
      if (!mounted) return;
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
                      children: [SizedBox(height: 10), _buildPriceInput()],
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
            'Modifier ${widget.subjectName}',
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
            onPressed: _isLoading ? null : _updateSubjectPrice,
            child: _isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Enregistrer',
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
                      'Enregistrer',
                      style: TextStyle(fontSize: mediumFontSize),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceInput() {
    return TextFormField(
      controller: _priceController,
      enabled: !_isLoading,
      decoration: InputDecoration(
        labelText: 'Prix par séance (DT)',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: inputContentPadding,
      ),
      style: const TextStyle(fontSize: mediumFontSize),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+[,.]?\d{0,2}')),
      ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer un prix';
        }
        final price = double.tryParse(value.replaceAll(',', '.'));
        if (price == null) {
          return 'Veuillez entrer un prix valide';
        }
        if (price <= 0) {
          return 'Le prix doit être supérieur à zéro';
        }
        return null;
      },
    );
  }

  String _formatInitialPrice(double price) {
    final bool isWhole = price % 1 == 0;
    return isWhole ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
  }
}
