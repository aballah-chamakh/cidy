import 'dart:convert';
import 'dart:io';
import 'package:cidy/config.dart';
import 'package:cidy/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cidy/authentication/login.dart';

class CreateStudentPopup extends StatefulWidget {
  final Function onStudentAdded;
  final VoidCallback onServerError;
  final VoidCallback? onBack;
  final Map<String, dynamic> filterOptions;

  const CreateStudentPopup({
    super.key,
    required this.onStudentAdded,
    required this.onServerError,
    this.onBack,
    required this.filterOptions,
  });

  @override
  State<CreateStudentPopup> createState() => _CreateStudentPopupState();
}

class _CreateStudentPopupState extends State<CreateStudentPopup> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedGender;
  String? _selectedLevelName;
  String? _selectedSectionName;
  String? _errorMessage;
  String? _phoneErrorMessage;
  bool _isLoading = false;
  File? _selectedImage;
  Map<String, dynamic> _levels = {};
  Map<String, dynamic> _sections = {};

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_clearPhoneError);
    _processFilterOptions();
  }

  void _processFilterOptions() {
    _levels = widget.filterOptions;
    if (_selectedLevelName != null && _levels.containsKey(_selectedLevelName)) {
      _sections = _levels[_selectedLevelName]['sections'] ?? {};
    }
  }

  void _clearPhoneError() {
    if (_phoneErrorMessage != null) {
      setState(() {
        _phoneErrorMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_clearPhoneError);
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
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

  Future<void> _createStudent() async {
    if (!_formKey.currentState!.validate()) {
      if (_selectedGender == null) {
        setState(() {
          _errorMessage = 'Veuillez sélectionner le genre de l\'élève.';
        });
      }
      return;
    }

    if (_selectedGender == null) {
      setState(() {
        _errorMessage = 'Veuillez sélectionner le genre de l\'élève.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _phoneErrorMessage = null;
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

      final createUrl = Uri.parse(
        '${Config.backendUrl}/api/teacher/students/create/',
      );

      var request = http.MultipartRequest('POST', createUrl);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['fullname'] = _fullNameController.text.trim();
      request.fields['phone_number'] = _phoneController.text.trim();
      request.fields['gender'] = _selectedGender!;
      request.fields['level'] = _selectedLevelName!;
      request.fields['section'] = _selectedSectionName ?? '';

      if (_selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', _selectedImage!.path),
        );
      }

      final streamedResponse = await request.send();
      final createResponse = await http.Response.fromStream(streamedResponse);
      if (!mounted) return;

      if (createResponse.statusCode == 200) {
        widget.onStudentAdded();
      } else if (createResponse.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else if (createResponse.statusCode == 400) {
        try {
          final Map<String, dynamic> responseData = jsonDecode(
            createResponse.body,
          );
          if (responseData.containsKey('phone_number') &&
              responseData['phone_number'][0] ==
                  'student with this phone number already exists.') {
            setState(() {
              _phoneErrorMessage =
                  'Un élève avec ce numéro de téléphone existe déjà.';
            });
          } else {
            widget.onServerError();
          }
        } catch (e, stackTrace) {
          print("Exception during processing 400 response:");
          print(e);
          print(stackTrace);
          widget.onServerError();
        }
      } else {
        widget.onServerError();
      }
    } catch (e, stackTrace) {
      print("Exception during student creation:");
      print(e);
      print(stackTrace);
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
                      children: [
                        const SizedBox(height: 20),
                        _buildProfileImageSection(),
                        const SizedBox(height: 30),
                        _buildFullNameField(),
                        const SizedBox(height: 12),
                        _buildLevelDropdown(),
                        const SizedBox(height: 12),
                        _buildSectionDropdown(),
                        const SizedBox(height: 12),
                        _buildPhoneField(),
                        if (_phoneErrorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 5.0),
                            child: Text(
                              _phoneErrorMessage!,
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 15.0,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        _buildGenderSection(),
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 5.0),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 15.0,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 30),
                _buildActionButtons(),
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
          'Créer un nouvel élève',
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

  Widget _buildProfileImageSection() {
    return Center(
      child: Stack(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: _selectedImage != null
                  ? FileImage(_selectedImage!)
                  : NetworkImage(
                      "${Config.backendUrl}/media/defaults/student.png",
                    ),
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

  Widget _buildGenderSection() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        segments: <ButtonSegment<String>>[
          ButtonSegment<String>(
            value: 'M',
            label: Padding(
              padding: buttonSegmentPadding, // vertical padding
              child: Text(
                'Masculin',
                style: TextStyle(fontSize: mediumFontSize),
              ),
            ),
            icon: Icon(Icons.male),
          ),
          ButtonSegment<String>(
            value: 'F',
            label: Padding(
              padding: buttonSegmentPadding, // vertical padding
              child: Text(
                'Féminin',
                style: TextStyle(fontSize: mediumFontSize),
              ),
            ),
            icon: Icon(Icons.female),
          ),
        ],
        selected: _selectedGender != null ? {_selectedGender!} : <String>{},
        onSelectionChanged: _isLoading
            ? null
            : (Set<String> newSelection) {
                setState(() {
                  _selectedGender = newSelection.isEmpty
                      ? null
                      : newSelection.first;
                });
              },
        emptySelectionAllowed: true,
        style: SegmentedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          foregroundColor: primaryColor,
          selectedForegroundColor: Colors.white,
          selectedBackgroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              buttonSegmentBorderRadius,
            ), // <-- borderRadius here
          ),
        ),
      ),
    );
  }

  Widget _buildFullNameField() {
    return TextFormField(
      controller: _fullNameController,
      enabled: !_isLoading,
      style: TextStyle(
        fontSize: mediumFontSize, // 👈 sets the input text size
      ),
      cursorColor: primaryColor,
      decoration: InputDecoration(
        labelText: 'Nom complet',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: inputContentPadding,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Veuillez entrer le nom complet de l\'élève';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      enabled: !_isLoading,
      cursorColor: primaryColor,
      style: const TextStyle(
        fontSize: mediumFontSize, // 👈 sets the input text size
      ),
      decoration: InputDecoration(
        labelText: 'Numéro de téléphone',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: inputContentPadding,
      ),
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Veuillez entrer le numéro de téléphone';
        }
        if (value.length != 8) {
          return 'Le numéro de téléphone doit contenir exactement 8 chiffres';
        }
        return null;
      },
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
      onChanged: (value) {
        setState(() {
          _selectedLevelName = value;
          _selectedSectionName = null;
          _sections = (value != null && _levels.containsKey(value))
              ? _levels[value]['sections'] ?? {}
              : {};
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Veuillez sélectionner un niveau';
        }
        return null;
      },
    );
  }

  Widget _buildSectionDropdown() {
    final bool isEnabled = _sections.isNotEmpty;

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
        fillColor: Colors.grey[200],
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
        if (isEnabled && value == null) {
          return 'Veuillez sélectionner une section';
        }
        return null;
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: AbsorbPointer(
            absorbing: _isLoading,
            child: TextButton(
              style: secondaryButtonStyle,
              onPressed: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: const Text(
                'Retour',
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
              onPressed: _createStudent,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Ajouter',
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
        ),
      ],
    );
  }
}
