import 'dart:convert';
import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cidy/authentication/login.dart';

class AddSubjectPopup extends StatefulWidget {
  final VoidCallback onSubjectAdded;
  final VoidCallback onServerError;
  final Map<String, dynamic> tesLevels;
  final Map<String, dynamic> teacherLevels;

  const AddSubjectPopup({
    super.key,
    required this.onSubjectAdded,
    required this.onServerError,
    required this.tesLevels,
    required this.teacherLevels,
  });

  @override
  State<AddSubjectPopup> createState() => _AddSubjectPopupState();
}

class _AddSubjectPopupState extends State<AddSubjectPopup> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  String? _selectedLevel;
  String? _selectedSection;
  String? _selectedSubject;
  String? _subjectExistsError;
  final TextEditingController _priceController = TextEditingController();

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  bool _subjectExists() {
    if (_selectedLevel == null || _selectedSubject == null) {
      return false;
    }

    if (widget.teacherLevels.containsKey(_selectedLevel)) {
      final levelData = widget.teacherLevels[_selectedLevel];
      if (_selectedSection != null) {
        if (levelData.containsKey('sections') &&
            levelData['sections'].containsKey(_selectedSection)) {
          final sectionData = levelData['sections'][_selectedSection];
          if (sectionData.containsKey('subjects')) {
            final subjects = sectionData['subjects'] as List;
            return subjects.any((s) => s['name'] == _selectedSubject);
          }
        }
      } else {
        if (levelData.containsKey('subjects')) {
          final subjects = levelData['subjects'] as List;
          return subjects.any((s) => s['name'] == _selectedSubject);
        }
      }
    }
    return false;
  }

  Future<void> _addSubject() async {
    setState(() {
      _subjectExistsError = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_subjectExists()) {
      setState(() {
        _subjectExistsError = 'Cette matière existe déjà.';
      });
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

      final response = await http.post(
        Uri.parse('${Config.backendUrl}/api/teacher/subject/add/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'level': _selectedLevel,
          'section': _selectedSection ?? '',
          'subject': _selectedSubject,
          'price_per_class':
              double.tryParse(_priceController.text.replaceAll(',', '.')) ??
              0.0,
        }),
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        widget.onSubjectAdded();
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
                SizedBox(height: 8),
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(child: _buildContent()),
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
        Text(
          'Ajouter une matière',
          style: TextStyle(
            fontSize: headerFontSize,
            fontWeight: FontWeight.bold,
            color: primaryColor,
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

  Widget _buildContent() {
    return Column(
      children: [
        _buildLevelDropdown(),
        const SizedBox(height: 10),
        _buildSectionDropdown(),
        const SizedBox(height: 10),
        _buildSubjectDropdown(),
        const SizedBox(height: 10),
        _buildPriceInput(),
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
            onPressed: _isLoading ? null : _addSubject,
            child: _isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Ajouter',
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
                      'Ajouter',
                      style: TextStyle(fontSize: mediumFontSize),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Niveau',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: inputContentPadding,
      ),
      value: _selectedLevel,
      items: widget.tesLevels.keys.map((String level) {
        return DropdownMenuItem<String>(
          value: level,
          child: Text(level, style: const TextStyle(fontSize: mediumFontSize)),
        );
      }).toList(),
      onChanged: _isLoading
          ? null
          : (value) {
              setState(() {
                _selectedLevel = value;
                _selectedSection = null;
                _selectedSubject = null;
              });
            },
      validator: (value) =>
          value == null ? 'Veuillez sélectionner un niveau' : null,
    );
  }

  Widget _buildSectionDropdown() {
    final levelData = _selectedLevel != null
        ? widget.tesLevels[_selectedLevel]
        : null;
    final sections = levelData != null && levelData.containsKey('sections')
        ? levelData['sections'] as Map<String, dynamic>
        : null;
    final bool isEnabled = sections != null;

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Section',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: inputContentPadding,
        filled: !isEnabled,
        fillColor: Colors.grey[200],
      ),
      value: _selectedSection,
      items: isEnabled
          ? sections.keys.map((String section) {
              return DropdownMenuItem<String>(
                value: section,
                child: Text(
                  section,
                  style: const TextStyle(fontSize: mediumFontSize),
                ),
              );
            }).toList()
          : [],
      onChanged: isEnabled && !_isLoading
          ? (value) {
              setState(() {
                _selectedSection = value;
                _selectedSubject = null;
              });
            }
          : null,
      validator: (value) {
        if (isEnabled && value == null) {
          return 'Veuillez sélectionner une section';
        }
        return null;
      },
    );
  }

  Widget _buildSubjectDropdown() {
    List<String> subjects = [];
    bool isEnabled = false;

    if (_selectedLevel != null) {
      final levelData = widget.tesLevels[_selectedLevel];
      if (levelData.containsKey('subjects')) {
        subjects = List<String>.from(levelData['subjects']);
        isEnabled = true;
      } else if (levelData.containsKey('sections') &&
          _selectedSection != null) {
        final sectionData = levelData['sections'][_selectedSection];
        if (sectionData != null) {
          subjects = List<String>.from(sectionData);
          isEnabled = true;
        }
      }
    }

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Matière',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: inputContentPadding,
        filled: !isEnabled,
        fillColor: Colors.grey[200],
        errorText: _subjectExistsError,
      ),
      value: _selectedSubject,
      items: subjects.map((String subject) {
        return DropdownMenuItem<String>(
          value: subject,
          child: Text(
            subject,
            style: const TextStyle(fontSize: mediumFontSize),
          ),
        );
      }).toList(),
      onChanged: isEnabled && !_isLoading
          ? (value) {
              setState(() {
                _selectedSubject = value;
                _subjectExistsError = null;
              });
            }
          : null,
      validator: (value) => isEnabled && value == null
          ? 'Veuillez sélectionner une matière'
          : null,
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
}
