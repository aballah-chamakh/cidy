import 'dart:convert';

import 'package:cidy/config.dart';
import 'package:cidy/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cidy/authentication/login.dart';
import 'package:http/http.dart' as http;

class DeleteSubjectPopup extends StatefulWidget {
  final String type;
  final String name;
  final int id;
  final VoidCallback onDeleteConfirmed;

  const DeleteSubjectPopup({
    super.key,
    required this.type,
    required this.name,
    required this.id,
    required this.onDeleteConfirmed,
  });

  @override
  State<DeleteSubjectPopup> createState() => _DeleteSubjectPopupState();
}

class _DeleteSubjectPopupState extends State<DeleteSubjectPopup> {
  bool _isLoading = false;
  String? _errorMessage;

  String _buildConfirmationMessage() {
    switch (widget.type) {
      case 'level':
        return 'Êtes-vous sûr de vouloir supprimer le niveau ${widget.name} ? Cela supprimera toutes les sections, matières et groupes associés.';
      case 'section':
        return 'Êtes-vous sûr de vouloir supprimer la section ${widget.name} ? Cela supprimera toutes les matières et groupes associés.';
      case 'subject':
        return 'Êtes-vous sûr de vouloir supprimer la matière ${widget.name} ? Cela supprimera tous les groupes associés.';
      default:
        return 'Êtes-vous sûr de vouloir supprimer ${widget.name} ?';
    }
  }

  Future<void> _deleteItem() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (!mounted) return;

      if (token == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;
      }

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/subject/delete/${widget.id}/',
      );

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 204) {
        widget.onDeleteConfirmed();
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        String? serverMessage;
        if (response.bodyBytes.isNotEmpty) {
          final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
          if (decodedBody is Map<String, dynamic>) {
            final detail = decodedBody['detail'];
            if (detail is String) {
              serverMessage = detail;
            }
          }
        }

        setState(() {
          _errorMessage =
              serverMessage ?? 'Suppression impossible. Veuillez réessayer.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Une erreur est survenue. Veuillez réessayer.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
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
              _buildConfirmationMessage(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: mediumFontSize),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.red),
              ),
            ],
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
                    onPressed: _isLoading ? null : _deleteItem,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
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
