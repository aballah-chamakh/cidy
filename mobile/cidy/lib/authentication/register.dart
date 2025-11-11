import 'dart:convert';
import 'package:cidy/app_styles.dart';
import 'package:cidy/profiles/parent/parent_entry.dart';
import 'package:cidy/profiles/student/student_entry.dart';
import 'package:cidy/profiles/teacher/screens/teacher_dashboard_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'login.dart';
import 'package:cidy/config.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedProfileType = "teacher";
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedGender = "M";
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _selectedLevel;
  String? _selectedSection;
  List<String> _sections = [];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    bool isFormValid = _formKey.currentState!.validate();

    if (!isFormValid ||
        _selectedProfileType == null ||
        _selectedGender == null ||
        (_selectedProfileType == 'student' && _selectedLevel == null) ||
        (_selectedProfileType == 'student' &&
            _sections.isNotEmpty &&
            _selectedSection == null)) {
      return;
    }

    Map<String, dynamic> requestBody = {
      'fullname': _nameController.text,
      'email': _emailController.text,
      'phone_number': _phoneController.text,
      'gender': _selectedGender,
      'password': _passwordController.text,
      'profile_type': _selectedProfileType,
    };

    if (_selectedProfileType == 'student') {
      requestBody.addAll({'level': _selectedLevel});
      if (_selectedSection != null) {
        requestBody['section'] = _selectedSection;
      }
    }

    final url = Uri.parse('${Config.backendUrl}/api/auth/register/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (!mounted) return;
    if (response.statusCode == 200) {
      if (!mounted) return;
      final data = jsonDecode(response.body);
      const storage = FlutterSecureStorage();
      await storage.write(key: 'access_token', value: data['token']);
      await storage.write(key: 'email', value: data['user']['email']);
      await storage.write(key: 'fullname', value: data['user']['fullname']);
      await storage.write(key: 'image_url', value: data['user']['image_url']);
      await storage.write(
        key: 'profile_type',
        value: data['user']['profile_type'],
      );

      Widget profileScreen;
      String profileRouteName;
      switch (data['user']['profile_type']) {
        case 'student':
          profileScreen = const StudentEntry();
          profileRouteName = '/student';
          break;
        case 'teacher':
          profileScreen = const TeacherDashboardScreen();
          profileRouteName = '/teacher_dashboard';
          break;
        case 'parent':
          profileScreen = const ParentEntry();
          profileRouteName = '/parent';
          break;
        default:
          profileScreen = const LoginScreen();
          profileRouteName = '/login';
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          settings: RouteSettings(name: profileRouteName),
          builder: (context) => profileScreen,
        ),
        (route) => false,
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur du server 500')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 30.0),
                  Text(
                    'S\'inscrire',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  Image.asset(
                    'assets/login_teacher_illustration.png',
                    height: 200.0,
                  ),

                  const SizedBox(height: 30.0),
                  TextFormField(
                    style: const TextStyle(fontSize: mediumFontSize),
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nom complet',
                      labelStyle: TextStyle(color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(inputBorderRadius),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(inputBorderRadius),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      errorMaxLines: 3,
                      contentPadding: inputContentPadding,
                    ),
                    validator: (value) {
                      print("validate the fullname field : $value");
                      if (value == null || value.isEmpty) {
                        print("fullname field is empty");
                        return 'Veuillez entrer votre nom complet';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    style: const TextStyle(fontSize: mediumFontSize),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(inputBorderRadius),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(inputBorderRadius),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      errorMaxLines: 3,
                      contentPadding: inputContentPadding,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer votre email';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Veuillez entrer un email valide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    style: const TextStyle(fontSize: mediumFontSize),
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Numéro de téléphone',
                      labelStyle: TextStyle(color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(inputBorderRadius),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(inputBorderRadius),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      errorMaxLines: 3,
                      contentPadding: inputContentPadding,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer votre numéro de téléphone';
                      }
                      if (!RegExp(r'^\d{8}$').hasMatch(value)) {
                        return 'Le numéro de téléphone doit contenir 8 chiffres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10.0),
                  const Text(
                    'Genre',
                    style: TextStyle(
                      fontSize: mediumFontSize,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 5.0),
                  SegmentedButton<String>(
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
                    selected: _selectedGender != null
                        ? {_selectedGender!}
                        : <String>{},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedGender = newSelection.isEmpty
                            ? null
                            : newSelection.first;
                      });
                    },
                    emptySelectionAllowed: true,
                    style: SegmentedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryColor,
                      selectedForegroundColor: Colors.white,
                      selectedBackgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          buttonSegmentBorderRadius,
                        ),
                      ),
                    ),
                  ),
                  if (_selectedProfileType == 'student') ...[
                    const SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedLevel,
                      decoration: InputDecoration(
                        labelText: 'Niveau',
                        labelStyle: TextStyle(color: primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        errorMaxLines: 3,
                      ),
                      items: Config.levelsSectionsSubjects.keys
                          .map(
                            (level) => DropdownMenuItem(
                              value: level,
                              child: Text(level),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedLevel = value;
                          _selectedSection = null;
                          if (value != null &&
                              Config.levelsSectionsSubjects[value]!.containsKey(
                                'sections',
                              )) {
                            _sections =
                                (Config.levelsSectionsSubjects[value]!['sections']
                                        as Map<String, dynamic>)
                                    .keys
                                    .toList();
                          } else {
                            _sections = [];
                          }
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Veuillez sélectionner un niveau';
                        }
                        return null;
                      },
                    ),
                    if (_sections.isNotEmpty) ...[
                      const SizedBox(height: 16.0),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedSection,
                        decoration: InputDecoration(
                          labelText: 'Section',
                          labelStyle: TextStyle(color: primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          errorMaxLines: 3,
                        ),
                        items: _sections
                            .map(
                              (section) => DropdownMenuItem(
                                value: section,
                                child: Text(section),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSection = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Veuillez sélectionner une section';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 16.0),
                  TextFormField(
                    style: const TextStyle(fontSize: mediumFontSize),
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      labelStyle: TextStyle(color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(inputBorderRadius),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(inputBorderRadius),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      errorMaxLines: 3,
                      contentPadding: inputContentPadding,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer votre mot de passe';
                      }
                      if (value.length < 8) {
                        return 'Le mot de passe doit contenir au moins 8 caractères';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: _registerUser,
                    style: primaryButtonStyle,
                    child: const Text(
                      'S\'inscrire',
                      style: TextStyle(fontSize: mediumFontSize),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Text(
                        "Vous avez déjà un compte ?",
                        style: TextStyle(fontSize: mediumFontSize - 2),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          'Se connecter',
                          style: TextStyle(
                            fontSize: mediumFontSize - 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0, top: 16.0),
                    child: Image.asset(
                      'assets/blue_cidy_logo.png',
                      height: 40.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
