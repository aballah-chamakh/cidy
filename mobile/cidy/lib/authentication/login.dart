import 'dart:convert';
import 'package:cidy/authentication/register.dart';
import 'package:cidy/parent/parent_entry.dart';
import 'package:cidy/student/student_entry.dart';
import 'package:cidy/teacher/teacher_entry.dart';
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

    if (!mounted) return;
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      const storage = FlutterSecureStorage();
      await storage.write(key: 'access_token', value: data['access']);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Connexion réussie !')));

      // Decode the access token to get the profile type
      final accessToken = data['access'];
      final parts = accessToken.split('.');
      if (parts.length == 3) {
        final payload = parts[1];
        // Add padding if needed
        String normalizedPayload = base64.normalize(payload);
        final decodedPayload = utf8.decode(base64.decode(normalizedPayload));
        final tokenData = jsonDecode(decodedPayload);
        final profileType = tokenData['profile_type'];

        Widget entryWidget;
        switch (profileType) {
          case 'student':
            entryWidget = const StudentEntry();
            break;
          case 'teacher':
            entryWidget = const TeacherEntry();
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
      }
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
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const RegisterScreen(),
                                  ),
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
                          'assets/orange_cidy_logo.png',
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
