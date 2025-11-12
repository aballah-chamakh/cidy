import 'dart:convert';
import 'package:cidy/app_styles.dart';
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
  bool _isSubmitting = false;

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

    setState(() {
      _isSubmitting = true;
    });

    Map<String, dynamic> requestBody = {
      'email': _emailController.text,
      'password': _passwordController.text,
    };

    try {
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

        if (!mounted) return;
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

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            settings: RouteSettings(name: profileRouteName),
            builder: (context) => profileScreen,
          ),
          (route) => false,
        );
      } else if (response.statusCode == 401) {
        //final error = jsonDecode(response.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur de connexion. Veuillez vérifier vos identifiants.',
              style: TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        //final error = jsonDecode(response.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur du serveur 500',
              style: TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const SizedBox(height: 30.0),
                      Text(
                        'Login',
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
                        height: 250.0,
                      ),
                      const SizedBox(height: 30.0),
                      TextFormField(
                        style: const TextStyle(fontSize: mediumFontSize),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(color: primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              inputBorderRadius,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              inputBorderRadius,
                            ),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
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
                        controller: _passwordController,
                        obscureText: _obscureText,
                        enabled: !_isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          labelStyle: TextStyle(color: primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              inputBorderRadius,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              inputBorderRadius,
                            ),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                          errorMaxLines: 3,
                          contentPadding: inputContentPadding,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: _isSubmitting
                                ? null
                                : () {
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
                        onPressed: _isSubmitting ? null : _loginUser,
                        style: primaryButtonStyle,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Se connecter',
                              style: TextStyle(fontSize: mediumFontSize),
                            ),
                            if (_isSubmitting) ...[
                              const SizedBox(width: 12),
                              SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
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
                              onPressed: _isSubmitting
                                  ? null
                                  : () {
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
                                style: TextStyle(
                                  fontSize: 16,
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
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
