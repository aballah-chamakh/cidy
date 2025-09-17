import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TeacherEntry extends StatefulWidget {
  const TeacherEntry({super.key});

  @override
  State<TeacherEntry> createState() => _TeacherEntryState();
}

class _TeacherEntryState extends State<TeacherEntry> {
  String? _accessToken;
  String? _refreshToken;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    const storage = FlutterSecureStorage();
    final accessToken = await storage.read(key: 'access_token');
    final refreshToken = await storage.read(key: 'refresh_token');
    if (mounted) {
      setState(() {
        _accessToken = accessToken;
        _refreshToken = refreshToken;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Dashboard')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome, Teacher!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Access Token:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(_accessToken ?? 'Not found'),
                    const SizedBox(height: 10),
                    const Text(
                      'Refresh Token:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(_refreshToken ?? 'Not found'),
                  ],
                ),
              ),
            ),
    );
  }
}
