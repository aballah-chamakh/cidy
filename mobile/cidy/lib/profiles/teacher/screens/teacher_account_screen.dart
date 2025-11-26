import 'dart:convert';
import 'dart:io';
import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:cidy/authentication/login.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_layout.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_account_screen/change_password_popup.dart';
import 'package:cidy/profiles/teacher/widgets/teacher_account_screen/update_account_info_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class TeacherAccountScreen extends StatefulWidget {
  const TeacherAccountScreen({super.key});

  @override
  State<TeacherAccountScreen> createState() => _TeacherAccountScreenState();
}

class _TeacherAccountScreenState extends State<TeacherAccountScreen> {
  final _accountInfoFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  String? _emailErrorMessage;
  String? _phoneErrorMessage;
  Map<String, dynamic>? _teacher;
  String? _selectedGender;
  File? _selectedImage;
  String? _currentImageUrl;
  Future<void> Function()? _reloadSidebarInfo;

  bool _isNewPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  @override
  void initState() {
    super.initState();
    _fetchTeacherData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fetchTeacherData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

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

      final response = await http.get(
        Uri.parse('${Config.backendUrl}/api/teacher/account/info/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final teacherAccountInfo = json.decode(
          utf8.decode(response.bodyBytes),
        )['teacher_account_data'];
        setState(() {
          _teacher = teacherAccountInfo;
          _fullNameController.text = _teacher?['fullname'] ?? '';
          _emailController.text = _teacher?['email'] ?? '';
          _phoneController.text = _teacher?['phone_number'] ?? '';
          _selectedGender = _teacher?['gender'] ?? 'M';
          _currentImageUrl = _resolveImageUrl(_teacher?['image']);
          _emailErrorMessage = null;
          _phoneErrorMessage = null;
        });
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      } else {
        setState(() {
          _errorMessage =
              'Une erreur est survenue lors du chargement des informations de votre compte.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Une erreur est survenue lors du chargement des informations de votre compte.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _resolveImageUrl(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return '${Config.backendUrl}$trimmed';
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
        const SnackBar(content: Text('Impossible de sélectionner la photo.')),
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
                title: const Text('Choisir une photo dans la galerie'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Prendre une photo avec la caméra'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showUpdateAccountInfoPopup() {
    if (!_accountInfoFormKey.currentState!.validate()) {
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return UpdateAccountInfoPopup(
          fullName: _fullNameController.text.trim(),
          email: _emailController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          gender: _selectedGender ?? 'M',
          imageFile: _selectedImage,
          onSuccess: () async {
            if (!mounted) return;
            Navigator.of(context).pop();
            _showSuccess(
              "Les informations de votre compte ont été mises à jour avec succès",
            );
            await _fetchTeacherData(showLoading: true);
            const storage = FlutterSecureStorage();
            await storage.write(key: 'email', value: _teacher?['email']);
            await storage.write(key: 'fullname', value: _teacher?['fullname']);
            await storage.write(key: 'image_url', value: _teacher?['image']);
            _reloadSidebarInfo?.call();
          },
          onServerError: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            _showError("Erreur du serveur 500");
          },
          onValidationError: (errors) {
            if (!mounted) {
              return;
            }
            setState(() {
              _emailErrorMessage = errors['email'];
              _phoneErrorMessage = errors['phone_number'];
            });
          },
        );
      },
    );
  }

  void _showChangePasswordPopup() {
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ChangePasswordPopup(
          newPassword: _newPasswordController.text,
          onSuccess: () {
            Navigator.of(context).pop();
            _newPasswordController.clear();
            _confirmPasswordController.clear();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mot de passe modifié avec succès !'),
                backgroundColor: Colors.green,
              ),
            );
          },
          onServerError: () {
            Navigator.of(context).pop();
            _showError("Erreur du serveur 500");
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    const storage = FlutterSecureStorage();
    await storage.deleteAll();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TeacherLayout(
      title: 'Compte',
      bodyBuilder: ({reloadTeacherInfo}) {
        _reloadSidebarInfo = reloadTeacherInfo;
        return _buildBodyContent();
      },
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }
    return RefreshIndicator(
      color: primaryColor,
      onRefresh: () => _fetchTeacherData(showLoading: false),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: _errorMessage != null
                  ? Center(
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: mediumFontSize,
                          color: Colors.red,
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildAccountInfoSection(),
                        const SizedBox(height: 12),
                        _buildChangePasswordSection(),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            onPressed: _logout,
                            icon: const Icon(Icons.logout),
                            label: const Text(
                              'Se déconnecter',
                              style: TextStyle(fontSize: mediumFontSize),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    String label, {
    Widget? suffixIcon,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      suffixIcon: suffixIcon,
      errorMaxLines: 3,
      errorText: errorText,
      fillColor: Colors.white,
      filled: true,
      focusColor: Colors.white,
      hoverColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputBorderRadius),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputBorderRadius),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputBorderRadius),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      contentPadding: inputContentPadding,
      labelStyle: TextStyle(color: primaryColor),
      floatingLabelStyle: TextStyle(color: primaryColor),
    );
  }

  Widget _buildAccountInfoSection() {
    return Card(
      color: Color(0xFFF5F7FA),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _accountInfoFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(context, 'Informations du compte'),
              const SizedBox(height: 24),
              _buildProfileImageSection(),
              const SizedBox(height: 24),
              TextFormField(
                controller: _fullNameController,
                decoration: _buildInputDecoration('Nom complet'),
                validator: (value) =>
                    value!.isEmpty ? 'Le nom complet est requis' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                decoration: _buildInputDecoration(
                  'E-mail',
                  errorText: _emailErrorMessage,
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) {
                  if (_emailErrorMessage != null) {
                    setState(() {
                      _emailErrorMessage = null;
                    });
                  }
                },
                validator: (value) {
                  if (value!.isEmpty) return 'L\'e-mail est requis';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Entrez un e-mail valide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                decoration: _buildInputDecoration(
                  'Numéro de téléphone',
                  errorText: _phoneErrorMessage,
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                onChanged: (_) {
                  if (_phoneErrorMessage != null) {
                    setState(() {
                      _phoneErrorMessage = null;
                    });
                  }
                },
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Le numéro de téléphone est requis';
                  }
                  if (value.length != 8) {
                    return 'Le numéro de téléphone doit contenir 8 chiffres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 4.0, bottom: 0.0),
                child: Text(
                  'Genre',
                  style: TextStyle(fontSize: mediumFontSize),
                ),
              ),
              _buildGenderSegment(),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: primaryButtonStyle,
                  onPressed: _showUpdateAccountInfoPopup,
                  child: const Text(
                    'Enregistrer',
                    style: TextStyle(fontSize: mediumFontSize),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangePasswordSection() {
    return Card(
      color: Color(0xFFF5F7FA),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _passwordFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(context, 'Modifier le mot de passe'),
              const SizedBox(height: 15),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _isNewPasswordObscured,
                decoration: _buildInputDecoration(
                  'Nouveau mot de passe',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isNewPasswordObscured
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isNewPasswordObscured = !_isNewPasswordObscured;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Le nouveau mot de passe est requis';
                  }
                  if (value.length < 8) {
                    return 'Le mot de passe doit contenir au moins 8 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _isConfirmPasswordObscured,
                decoration: _buildInputDecoration(
                  'Confirmer le nouveau mot de passe',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordObscured
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordObscured =
                            !_isConfirmPasswordObscured;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value != _newPasswordController.text) {
                    return 'Les mots de passe ne correspondent pas';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: primaryButtonStyle,
                  onPressed: _showChangePasswordPopup,
                  child: const Text(
                    'Modifier le mot de passe',
                    style: TextStyle(fontSize: mediumFontSize),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    final imageUrl = _currentImageUrl;
    final ImageProvider<Object> imageProvider = _selectedImage != null
        ? FileImage(_selectedImage!) as ImageProvider<Object>
        : NetworkImage(imageUrl!) as ImageProvider<Object>;

    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage: imageProvider,
            onBackgroundImageError:
                (_selectedImage == null && imageUrl!.isNotEmpty)
                ? (exception, stackTrace) {
                    // Handle network image error if needed
                  }
                : null,
            child: _selectedImage == null && imageUrl!.isEmpty
                ? const Icon(Icons.person, size: 60)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Material(
              color: primaryColor,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _showImagePickerOptions,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(Icons.edit, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSegment() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        style: ButtonStyle(
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(inputBorderRadius),
            ),
          ),
          side: MaterialStateProperty.all(
            BorderSide(color: Colors.grey.shade300),
          ),
          padding: MaterialStateProperty.all(buttonSegmentPadding),
          backgroundColor: MaterialStateProperty.resolveWith((states) {
            return states.contains(MaterialState.selected)
                ? primaryColor
                : Colors.white;
          }),
          foregroundColor: MaterialStateProperty.resolveWith((states) {
            return states.contains(MaterialState.selected)
                ? Colors.white
                : Colors.black87;
          }),
        ),
        segments: const [
          ButtonSegment<String>(
            value: 'M',
            label: Padding(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 4.0),
              child: Text('Homme', style: TextStyle(fontSize: mediumFontSize)),
            ),
            icon: Padding(
              padding: EdgeInsets.only(right: 4.0),
              child: Icon(Icons.male),
            ),
          ),
          ButtonSegment<String>(
            value: 'F',
            label: Padding(
              padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 4.0),
              child: Text('Femme', style: TextStyle(fontSize: mediumFontSize)),
            ),
            icon: Padding(
              padding: EdgeInsets.only(right: 4.0),
              child: Icon(Icons.female),
            ),
          ),
        ],
        selected: _selectedGender != null ? {_selectedGender!} : {},
        onSelectionChanged: (Set<String> newSelection) {
          setState(() {
            _selectedGender = newSelection.first;
          });
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Text(
        title,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }
}
