import 'dart:convert';
import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cidy/authentication/login.dart';

class ConfirmDeletePopup extends StatefulWidget {
  final String type;
  final String name;
  final int id;
  final VoidCallback onDeleteConfirmed;

  const ConfirmDeletePopup({
    super.key,
    required this.type,
    required this.name,
    required this.id,
    required this.onDeleteConfirmed,
  });

  @override
  State<ConfirmDeletePopup> createState() => _ConfirmDeletePopupState();
}

class _ConfirmDeletePopupState extends State<ConfirmDeletePopup> {
  bool _isLoading = false;
  String? _errorMessage;

  String _getConfirmationMessage() {
    switch (widget.type) {
      case 'level':
        return 'Are you sure you want to delete the level ${widget.name}? This will delete all related sections, subjects, and groups.';
      case 'section':
        return 'Are you sure you want to delete the section ${widget.name}? This will delete all related subjects and groups.';
      case 'subject':
        return 'Are you sure you want to delete the subject ${widget.name}? This will delete all related groups.';
      default:
        return 'Are you sure you want to delete ${widget.name}?';
    }
  }

  Future<void> _deleteItem() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      const storage = FlutterSecureStorage();
      final accessToken = await storage.read(key: 'accessToken');
      if (accessToken == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
        return;
      }

      String url;
      switch (widget.type) {
        case 'level':
        case 'section':
        case 'subject':
          url = '${Config.backendUrl}/api/teacher/subject/delete/${widget.id}/';
          break;
        default:
          throw Exception('Invalid delete type');
      }

      final response = await http.delete(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 204) {
        widget.onDeleteConfirmed();
        Navigator.of(context).pop();
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _errorMessage = errorData['detail'] ?? 'Failed to delete item.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Confirm Delete', style: AppStyles.title),
            const SizedBox(height: 20),
            const Icon(Icons.delete_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _getConfirmationMessage(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('No'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isLoading ? null : _deleteItem,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Yes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
