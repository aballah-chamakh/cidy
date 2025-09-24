import 'dart:convert';
import 'package:cidy/authentication/register.dart';
import 'package:cidy/profiles/parent/parent_entry.dart';
import 'package:cidy/profiles/student/student_entry.dart';
import 'package:cidy/profiles/teacher/screens/teacher_dashboard_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cidy/config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscureText = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Map<String, dynamic> requestBody = {
      'email': _emailController.text,
      'password': _passwordController.text,
    };

    final url = Uri.parse('${Config.backendUrl}/api/auth/token/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (!context.mounted) return;
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      const storage = FlutterSecureStorage();
      await storage.write(key: 'access_token', value: data['access']);
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
      final error = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : ${error['detail'] ?? 'Erreur de connexion'}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const SizedBox(height: 48.0),
                      Text(
                        'Login',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 24.0),
                      Image.asset(
                        'assets/login_teacher_illustration.png',
                        height: 250.0,
                      ),
                      const SizedBox(height: 48.0),
                      TextFormField(
                        style: Theme.of(context).textTheme.bodyLarge,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: Theme.of(context).inputDecorationTheme.border,
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
                        style: Theme.of(context).textTheme.bodyLarge,
                        controller: _passwordController,
                        obscureText: _obscureText,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer votre mot de passe';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24.0),
                      ElevatedButton(
                        onPressed: _loginUser,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: const Text(
                          'Se connecter',
                          style: TextStyle(fontSize: 18.0),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Text(
                              "Vous n'avez pas de compte ?",
                              style: TextStyle(fontSize: 16.0),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const RegisterScreen(),
                                  ),
                                  (route) => false,
                                );
                              },
                              child: const Text(
                                'S\'inscrire',
                                style: TextStyle(fontSize: 16.0),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0, top: 16.0),
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
        ),
      ),
    );
  }
}
