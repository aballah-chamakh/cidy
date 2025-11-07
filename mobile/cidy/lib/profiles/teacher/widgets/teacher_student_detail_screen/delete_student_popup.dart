import 'dart:convert';
import 'package:cidy/config.dart';
import 'package:cidy/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cidy/authentication/login.dart';
import 'package:http/http.dart' as http;

class DeleteStudentPopup extends StatefulWidget {
  final String studentName;
  final int studentId;
  final VoidCallback onStudentDeleted;
  final VoidCallback onServerError;

  const DeleteStudentPopup({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.onStudentDeleted,
    required this.onServerError,
  });

  @override
  State<DeleteStudentPopup> createState() => _DeleteStudentPopupState();
}

class _DeleteStudentPopupState extends State<DeleteStudentPopup> {
  bool _isLoading = false;

  Future<bool> _deleteStudent() async {
    setState(() {
      _isLoading = true;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (!mounted) return false;

      if (token == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return false;
      }

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/students/delete/',
      );

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'student_ids': [widget.studentId],
        }),
      );

      if (!mounted) return false;

      if (response.statusCode == 200) {
        widget.onStudentDeleted();
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        widget.onServerError();
      }
    } catch (e) {
      if (!mounted) return false;
      widget.onServerError();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    return false;
  }

  void _handleCancel() {
    if (_isLoading) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: popupHorizontalMargin,
        vertical: 0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(popupBorderRadius),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(popupPadding),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(popupBorderRadius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Confirmer la suppression',
                  style: TextStyle(
                    fontSize: headerFontSize,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: headerIconSize,
                    color: primaryColor,
                  ),
                  onPressed: _isLoading ? null : _handleCancel,
                ),
              ],
            ),
            const Divider(height: 5),
            const SizedBox(height: 15.0),
            Icon(Icons.delete, color: primaryColor, size: 100),
            const SizedBox(height: 15.0),
            Text(
              'Êtes-vous sûr de vouloir supprimer l\'élève : ${widget.studentName} ?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: mediumFontSize),
            ),
            const Divider(height: 30),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: secondaryButtonStyle,
                    onPressed: _isLoading ? null : _handleCancel,
                    child: const Text(
                      'Annuler',
                      style: TextStyle(fontSize: mediumFontSize),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: primaryButtonStyle,
                    onPressed: _isLoading ? null : _deleteStudent,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Supprimer',
                          style: TextStyle(fontSize: mediumFontSize),
                        ),
                        if (_isLoading) ...[
                          const SizedBox(width: 12),
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
