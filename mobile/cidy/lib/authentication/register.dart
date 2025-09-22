import 'dart:convert';
import 'package:cidy/profiles/parent/parent_entry.dart';
import 'package:cidy/profiles/student/student_entry.dart';
import 'package:cidy/profiles/teacher/screens/teacher_dashboard_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Inscription réussie !')));

      Widget entryWidget;
      switch (_selectedProfileType) {
        case 'student':
          entryWidget = const StudentEntry();
          break;
        case 'teacher':
          entryWidget = const TeacherDashboardScreen();
          break;
        case 'parent':
          entryWidget = const ParentEntry();
          break;
        default:
          entryWidget = const LoginScreen();
      }
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => entryWidget));
    } else {
      if (!mounted) return;
      final error = jsonDecode(response.body);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : ${error['message']}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 24.0),
                  Text(
                    'Register',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12.0),
                  Image.asset(
                    'assets/login_teacher_illustration.png',
                    height: 200.0,
                  ),
                  const SizedBox(height: 24.0),
                  Text(
                    'Profile Type',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8.0),
                  SegmentedButton<String>(
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment<String>(
                        value: 'teacher',
                        label: Text(
                          'Professeur',
                          style: TextStyle(fontSize: 16.0),
                        ),
                      ),
                      ButtonSegment<String>(
                        value: 'student',
                        label: Text(
                          'Etudiant',
                          style: TextStyle(fontSize: 16.0),
                        ),
                      ),
                      ButtonSegment<String>(
                        value: 'parent',
                        label: Text('Parent', style: TextStyle(fontSize: 16.0)),
                      ),
                    ],
                    selected: _selectedProfileType != null
                        ? {_selectedProfileType!}
                        : <String>{},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedProfileType = newSelection.isEmpty
                            ? null
                            : newSelection.first;
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
                  const SizedBox(height: 16.0),
                  TextFormField(
                    style: const TextStyle(fontSize: 16.0),
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nom complet',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
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
                    style: const TextStyle(fontSize: 16.0),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
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
                    style: const TextStyle(fontSize: 16.0),
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Numéro de téléphone',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer votre numéro de téléphone';
                      }
                      if (value.length != 8) {
                        return 'Le numéro de téléphone doit contenir 8 chiffres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  const Text('Genre', style: TextStyle(fontSize: 16.0)),
                  const SizedBox(height: 8.0),
                  SegmentedButton<String>(
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment<String>(
                        value: 'M',
                        label: Text('Homme', style: TextStyle(fontSize: 16.0)),
                        icon: Icon(Icons.male),
                      ),
                      ButtonSegment<String>(
                        value: 'F',
                        label: Text('Femme', style: TextStyle(fontSize: 16.0)),
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
                      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                      foregroundColor: Theme.of(context).primaryColor,
                      selectedForegroundColor: Colors.white,
                      selectedBackgroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                  if (_selectedProfileType == 'student') ...[
                    const SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      value: _selectedLevel,
                      decoration: InputDecoration(
                        labelText: 'Niveau',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
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
                        value: _selectedSection,
                        decoration: InputDecoration(
                          labelText: 'Section',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
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
                    style: const TextStyle(fontSize: 16.0),
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
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
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text(
                      'S\'inscrire',
                      style: TextStyle(fontSize: 18.0),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Text(
                        "Vous avez déjà un compte ?",
                        style: TextStyle(fontSize: 16.0),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Se connecter',
                          style: TextStyle(fontSize: 16.0),
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
