import 'package:flutter/material.dart';
import 'login.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedProfileType;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedGender;
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                      const SizedBox(height: 24.0),
                      const Text(
                        'Register',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Nunito',
                          color: Color(0xFFF54E1E),
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      Image.asset(
                        'assets/login_teacher_illustration.png',
                        height: 200.0,
                      ),
                      const SizedBox(height: 24.0),
                      const Text(
                        'Profile Type',
                        style: TextStyle(fontSize: 16.0),
                      ),
                      const SizedBox(height: 8.0),
                      SegmentedButton<String>(
                        segments: const <ButtonSegment<String>>[
                          ButtonSegment<String>(
                            value: 'Teacher',
                            label: Text(
                              'Teacher',
                              style: TextStyle(fontSize: 16.0),
                            ),
                          ),
                          ButtonSegment<String>(
                            value: 'Student',
                            label: Text(
                              'Student',
                              style: TextStyle(fontSize: 16.0),
                            ),
                          ),
                          ButtonSegment<String>(
                            value: 'Parent',
                            label: Text(
                              'Parent',
                              style: TextStyle(fontSize: 16.0),
                            ),
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
                          backgroundColor: const Color.fromARGB(
                            255,
                            255,
                            255,
                            255,
                          ),
                          foregroundColor: const Color(0xFFF54E1E),
                          selectedForegroundColor: Colors.white,
                          selectedBackgroundColor: const Color(0xFFF54E1E),
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
                          if (value == null || value.isEmpty) {
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
                            value: 'Male',
                            label: Text(
                              'Homme',
                              style: TextStyle(fontSize: 16.0),
                            ),
                            icon: Icon(Icons.male),
                          ),
                          ButtonSegment<String>(
                            value: 'Female',
                            label: Text(
                              'Femme',
                              style: TextStyle(fontSize: 16.0),
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
                          backgroundColor: const Color.fromARGB(
                            255,
                            255,
                            255,
                            255,
                          ),
                          foregroundColor: const Color(0xFFF54E1E),
                          selectedForegroundColor: Colors.white,
                          selectedBackgroundColor: const Color(0xFFF54E1E),
                        ),
                      ),
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
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            if (_selectedGender == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Veuillez sélectionner un genre',
                                  ),
                                ),
                              );
                              return;
                            }
                            // TODO: Implement registration functionality
                          }
                        },
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
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0, top: 16.0),
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
