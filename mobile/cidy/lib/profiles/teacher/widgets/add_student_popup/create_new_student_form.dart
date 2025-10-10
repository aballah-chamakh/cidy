import 'dart:io';
import 'package:cidy/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cidy/authentication/login.dart';

class CreateNewStudentForm extends StatefulWidget {
  final int groupId;
  final Function onStudentAdded;
  final VoidCallback onServerError;
  final VoidCallback? onBack;

  const CreateNewStudentForm({
    super.key,
    required this.groupId,
    required this.onStudentAdded,
    required this.onServerError,
    this.onBack,
  });

  @override
  State<CreateNewStudentForm> createState() => _CreateNewStudentFormState();
}

class _CreateNewStudentFormState extends State<CreateNewStudentForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedGender;
  bool _isLoading = false;
  String? _errorMessage;
  File? _selectedImage;

  @override
  void dispose() {
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

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        print('Error picking image: $e');
        print('Stack trace: $stackTrace');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Erreur lors de la sélection de l\'image',
              style: TextStyle(fontSize: 16.0),
            ),
          ),
        );
      }
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

  Future<void> _createAndAddStudent() async {
    if (!_formKey.currentState!.validate()) {
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
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');

      if (token == null) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
        return;
      }

      // First create the student
      final createUrl = Uri.parse(
        '${Config.backendUrl}/api/teacher/groups/${widget.groupId}/students/create/',
      );

      var request = http.MultipartRequest('PUT', createUrl);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['fullname'] = _fullNameController.text.trim();
      request.fields['phone_number'] = _phoneController.text.trim();
      request.fields['gender'] = _selectedGender!;

      // Add image if selected
      if (_selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', _selectedImage!.path),
        );
      }

      final streamedResponse = await request.send();
      final createResponse = await http.Response.fromStream(streamedResponse);
      if (!mounted) return;

      if (createResponse.statusCode == 201) {
        widget.onStudentAdded();
      } else if (createResponse.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        widget.onServerError();
      }
    } catch (e) {
      widget.onServerError();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Container(
          padding: const EdgeInsets.all(15.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(16.0),
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
                        const SizedBox(height: 10),
                        _buildPhoneField(),
                        const SizedBox(height: 10),
                        _buildGenderSection(),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 20),
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
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.close,
            weight: 2.0,
            color: Theme.of(context).primaryColor,
            size: 30,
          ),
          onPressed: () {
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
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: _selectedImage != null
                ? FileImage(_selectedImage!)
                : null,
            child: _selectedImage == null
                ? Icon(Icons.person, size: 50, color: Colors.grey.shade600)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                onPressed: _showImagePickerOptions,
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
        segments: const <ButtonSegment<String>>[
          ButtonSegment<String>(
            value: 'M',
            label: Text('Masculin', style: TextStyle(fontSize: 18.0)),
            icon: Icon(Icons.male),
          ),
          ButtonSegment<String>(
            value: 'F',
            label: Text('Féminin', style: TextStyle(fontSize: 18.0)),
            icon: Icon(Icons.female),
          ),
        ],
        selected: _selectedGender != null ? {_selectedGender!} : <String>{},
        onSelectionChanged: (Set<String> newSelection) {
          setState(() {
            _selectedGender = newSelection.isEmpty ? null : newSelection.first;
          });
        },
        emptySelectionAllowed: true,
        style: SegmentedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          foregroundColor: Theme.of(context).primaryColor,
          selectedForegroundColor: Colors.white,
          selectedBackgroundColor: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildFullNameField() {
    return TextFormField(
      controller: _fullNameController,
      style: const TextStyle(
        fontSize: 18, // 👈 sets the input text size
      ),
      decoration: InputDecoration(
        labelText: 'Nom complet',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
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
      style: const TextStyle(
        fontSize: 18, // 👈 sets the input text size
      ),
      decoration: InputDecoration(
        labelText: 'Numéro de téléphone',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
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

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            style: TextButton.styleFrom(
              side: BorderSide(color: Theme.of(context).primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),

            onPressed: _isLoading
                ? null
                : () {
                    if (widget.onBack != null) {
                      widget.onBack!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
            child: const Text('Retour', style: TextStyle(fontSize: 18.0)),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: _isLoading ? null : _createAndAddStudent,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Ajouter', style: TextStyle(fontSize: 18.0)),
          ),
        ),
      ],
    );
  }
}
