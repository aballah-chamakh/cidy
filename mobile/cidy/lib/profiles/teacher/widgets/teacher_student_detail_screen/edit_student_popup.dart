import 'dart:convert';
import 'dart:io';
import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:cidy/authentication/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class EditStudentPopup extends StatefulWidget {
  final int studentId;
  final String initialFullname;
  final String initialPhoneNumber;
  final String initialGender;
  final String initialLevel;
  final String? initialSection;
  final String? initialImage;
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
    required this.initialImage,
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
  File? _selectedImage;
  late final String _defaultStudentImageUrl;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _fullNameController.text = widget.initialFullname;
    _phoneController.text = widget.initialPhoneNumber;
    _selectedGender = widget.initialGender.isNotEmpty
        ? widget.initialGender
        : 'M';
    _defaultStudentImageUrl = '${Config.backendUrl}/media/defaults/student.png';
    _currentImageUrl = _resolveImageUrl(widget.initialImage);
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

  String? _resolveImageUrl(String? raw) {
    if (raw == null) {
      return null;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.toLowerCase() == 'null') {
      return null;
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return '${Config.backendUrl}$trimmed';
    }
    return '${Config.backendUrl}/$trimmed';
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (!mounted) return;

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Erreur lors de la sélection de l\'image',
            style: TextStyle(fontSize: mediumFontSize),
          ),
        ),
      );
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galerie'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Caméra'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_selectedImage != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Supprimer l\'image',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _selectedImage = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
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

      final request = http.MultipartRequest('PUT', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['fullname'] = _fullNameController.text.trim();
      request.fields['phone_number'] = _phoneController.text.trim();
      request.fields['gender'] = _selectedGender;

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
          request.fields['level'] = levelToSend;
          request.fields['section'] = sectionToSend;
        }
      }

      if (_selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', _selectedImage!.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

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
                        _buildProfileImageSection(),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Nom complet',
                            errorMaxLines: 3,
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
                            errorMaxLines: 3,
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
                        _buildGenderSegment(),
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
        errorMaxLines: 3,
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
        errorMaxLines: 3,
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

  Widget _buildGenderSegment() {
    final Set<String> selectedGender = _selectedGender.isNotEmpty
        ? {_selectedGender}
        : <String>{};

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        segments: <ButtonSegment<String>>[
          ButtonSegment<String>(
            value: 'M',
            label: Padding(
              padding: buttonSegmentPadding,
              child: Text(
                'Masculin',
                style: TextStyle(fontSize: mediumFontSize),
              ),
            ),
            icon: const Icon(Icons.male),
          ),
          ButtonSegment<String>(
            value: 'F',
            label: Padding(
              padding: buttonSegmentPadding,
              child: Text(
                'Féminin',
                style: TextStyle(fontSize: mediumFontSize),
              ),
            ),
            icon: const Icon(Icons.female),
          ),
        ],
        selected: selectedGender,
        onSelectionChanged: _isLoading
            ? null
            : (Set<String> newSelection) {
                if (newSelection.isEmpty) {
                  return;
                }
                setState(() {
                  _selectedGender = newSelection.first;
                });
              },
        emptySelectionAllowed: false,
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: primaryColor,
          selectedForegroundColor: Colors.white,
          selectedBackgroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonSegmentBorderRadius),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    final String imageUrl = _selectedImage != null
        ? ''
        : (_currentImageUrl ?? _defaultStudentImageUrl);

    final ImageProvider imageProvider = _selectedImage != null
        ? FileImage(_selectedImage!)
        : NetworkImage(imageUrl);

    return Center(
      child: Stack(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade200,
              backgroundImage: imageProvider,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                onPressed: _isLoading ? null : _showImagePickerOptions,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
