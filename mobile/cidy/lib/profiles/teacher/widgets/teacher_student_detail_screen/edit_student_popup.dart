import 'dart:convert';
import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:cidy/authentication/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class EditStudentPopup extends StatefulWidget {
  final int studentId;
  final String initialFullname;
  final String initialPhoneNumber;
  final String initialGender;
  final String initialLevel;
  final String? initialSection;
  final Map<String, dynamic> filterOptions;
  final bool canEditLevelSection;
  final VoidCallback onStudentUpdated;
  final VoidCallback onServerError;

  const EditStudentPopup({
    super.key,
    required this.studentId,
    required this.initialFullname,
    required this.initialPhoneNumber,
    required this.initialGender,
    required this.initialLevel,
    required this.initialSection,
    required this.filterOptions,
    required this.canEditLevelSection,
    required this.onStudentUpdated,
    required this.onServerError,
  });

  @override
  State<EditStudentPopup> createState() => _EditStudentPopupState();
}

class _EditStudentPopupState extends State<EditStudentPopup> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = false;
  String? _phoneErrorMessage;
  String? _genericErrorMessage;
  late String _selectedGender;
  Map<String, dynamic> _levels = {};
  Map<String, dynamic> _sections = {};
  String? _selectedLevelName;
  String? _selectedSectionName;

  @override
  void initState() {
    super.initState();
    _fullNameController.text = widget.initialFullname;
    _phoneController.text = widget.initialPhoneNumber;
    _selectedGender = widget.initialGender.isNotEmpty
        ? widget.initialGender
        : 'M';
    _initializeLevelSectionData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _initializeLevelSectionData() {
    _levels = _normalizeMap(widget.filterOptions);
    final initialLevel = widget.initialLevel.trim();
    _selectedLevelName =
        initialLevel.isNotEmpty && _levels.containsKey(initialLevel)
        ? initialLevel
        : null;

    if (_selectedLevelName == null && initialLevel.isNotEmpty) {
      _levels[initialLevel] = _normalizeMap(_levels[initialLevel]);
      _selectedLevelName = initialLevel;
    }

    Map<String, dynamic> levelData = {};
    if (_selectedLevelName != null) {
      levelData = _normalizeMap(_levels[_selectedLevelName]);
      _levels[_selectedLevelName!] = levelData;
    }
    _sections = _normalizeMap(levelData['sections']);

    final initialSection = widget.initialSection?.trim();
    if (_sections.isNotEmpty &&
        initialSection != null &&
        initialSection.isNotEmpty) {
      if (!_sections.containsKey(initialSection)) {
        _sections[initialSection] = _normalizeMap(_sections[initialSection]);
      }
      _selectedSectionName = initialSection;
    } else {
      _selectedSectionName = null;
    }
  }

  Map<String, dynamic> _normalizeMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }

  Future<void> _updateStudent() async {
    if (_isLoading) return;

    setState(() {
      _phoneErrorMessage = null;
      _genericErrorMessage = null;
    });

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
          (route) => false,
        );
        return;
      }

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/students/${widget.studentId}/edit/',
      );

      final Map<String, dynamic> payload = {
        'fullname': _fullNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'gender': _selectedGender,
      };

      if (widget.canEditLevelSection) {
        final levelToSend = (_selectedLevelName ?? widget.initialLevel).trim();
        String sectionToSend;

        if (_sections.isEmpty) {
          final fallbackSection = (widget.initialSection ?? '').trim();
          sectionToSend = (_selectedSectionName ?? '').isNotEmpty
              ? _selectedSectionName!
              : (levelToSend == widget.initialLevel ? fallbackSection : '');
        } else {
          sectionToSend = _selectedSectionName ?? '';
        }

        if (levelToSend.isNotEmpty) {
          payload['level'] = levelToSend;
          payload['section'] = sectionToSend;
        }
      }

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(payload),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        widget.onStudentUpdated();
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else if (response.statusCode == 400) {
        try {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          if (responseData.containsKey('phone_number') &&
              responseData['phone_number'][0] ==
                  'student with this phone number already exists.') {
            setState(() {
              _phoneErrorMessage =
                  'Un étudiant avec ce numéro de téléphone existe déjà.';
            });
          } else {
            widget.onServerError();
          }
        } catch (e) {
          widget.onServerError();
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
          maxHeight: MediaQuery.of(context).size.height * 0.6,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Modifier l\'élève',
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
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.of(context).pop(false);
                            },
                    ),
                  ],
                ),
                const Divider(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Nom complet',
                          ),
                          enabled: !_isLoading,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Veuillez saisir le nom de l\'élève';
                            }
                            if (value.trim().length < 3) {
                              return 'Le nom doit contenir au moins 3 caractères';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildLevelDropdown(),
                        const SizedBox(height: 12),
                        _buildSectionDropdown(),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: 'Numéro de téléphone',
                            errorText: _phoneErrorMessage,
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(8),
                          ],
                          enabled: !_isLoading,
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.isEmpty) {
                              return 'Veuillez saisir le numéro de téléphone';
                            }
                            if (trimmed.length != 8) {
                              return 'Le numéro doit contenir 8 chiffres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedGender,
                          decoration: const InputDecoration(labelText: 'Genre'),
                          items: const [
                            DropdownMenuItem(
                              value: 'M',
                              child: Text('Masculin'),
                            ),
                            DropdownMenuItem(
                              value: 'F',
                              child: Text('Féminin'),
                            ),
                          ],
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _selectedGender = value;
                                  });
                                },
                        ),
                        if (_genericErrorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _genericErrorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),
                if (!widget.canEditLevelSection)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      'Important : le niveau et la section ne peuvent pas être modifiés lorsque l\'élève est inscrit dans un groupe.',
                      style: const TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: secondaryButtonStyle,
                        onPressed: _isLoading
                            ? null
                            : () {
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
                        onPressed: _isLoading ? null : _updateStudent,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Enregistrer',
                              style: TextStyle(fontSize: mediumFontSize),
                            ),
                            if (_isLoading) ...[
                              const SizedBox(width: 12),
                              const SizedBox(
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedLevelName,
      style:
          Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16) ??
          const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Niveau',
        labelStyle: TextStyle(color: primaryColor),
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor),
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Sélectionner un niveau', style: TextStyle(fontSize: 16)),
        ),
        ..._levels.keys.map(
          (levelName) => DropdownMenuItem<String>(
            value: levelName,
            child: Text(levelName, style: const TextStyle(fontSize: 16)),
          ),
        ),
      ],
      onChanged: (!widget.canEditLevelSection || _isLoading)
          ? null
          : (value) {
              setState(() {
                _selectedLevelName = value;
                _selectedSectionName = null;
                if (value != null && _levels.containsKey(value)) {
                  final levelData = _normalizeMap(_levels[value]);
                  _levels[value] = levelData;
                  _sections = _normalizeMap(levelData['sections']);
                } else {
                  _sections = {};
                }
              });
            },
      validator: (value) {
        if (!widget.canEditLevelSection) {
          return null;
        }
        if (value == null) {
          return 'Veuillez sélectionner un niveau';
        }
        return null;
      },
    );
  }

  Widget _buildSectionDropdown() {
    final bool hasSections = _sections.isNotEmpty;
    final bool isEnabled =
        hasSections && widget.canEditLevelSection && !_isLoading;

    return DropdownButtonFormField<String>(
      value: _selectedSectionName,
      style:
          Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16) ??
          const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Section',
        labelStyle: TextStyle(color: primaryColor),
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor),
          borderRadius: BorderRadius.circular(8.0),
        ),
        filled: !isEnabled,
        fillColor: isEnabled ? null : Colors.grey[200],
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text(
            'Sélectionner une section',
            style: TextStyle(fontSize: 16),
          ),
        ),
        ..._sections.keys.map(
          (sectionName) => DropdownMenuItem<String>(
            value: sectionName,
            child: Text(sectionName, style: const TextStyle(fontSize: 16)),
          ),
        ),
      ],
      onChanged: isEnabled
          ? (value) {
              setState(() {
                _selectedSectionName = value;
              });
            }
          : null,
      validator: (value) {
        if (!widget.canEditLevelSection) {
          return null;
        }
        if (hasSections && value == null) {
          return 'Veuillez sélectionner une section';
        }
        return null;
      },
    );
  }
}
