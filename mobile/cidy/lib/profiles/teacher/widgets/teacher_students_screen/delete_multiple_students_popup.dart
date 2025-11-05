import 'dart:convert';
import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:cidy/authentication/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class DeleteMultipleStudentsPopup extends StatefulWidget {
  final int studentCount;
  final Set<int> studentIds;
  final VoidCallback onSuccess;
  final VoidCallback onError;

  const DeleteMultipleStudentsPopup({
    super.key,
    required this.studentCount,
    required this.studentIds,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<DeleteMultipleStudentsPopup> createState() =>
      _DeleteMultipleStudentsPopupState();
}

class _DeleteMultipleStudentsPopupState
    extends State<DeleteMultipleStudentsPopup> {
  bool _isLoading = false;

  Future<void> _deleteStudents() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (!mounted) return;

      if (token == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
        return;
      }

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/students/delete/',
      );
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'student_ids': widget.studentIds.toList()}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        widget.onSuccess();
      } else if (response.statusCode == 401) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        // Handle error
        widget.onError();
      }
    } catch (e) {
      if (!mounted) return;
      widget.onError();
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
          children: <Widget>[
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
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.of(context).pop(false);
                        },
                ),
              ],
            ),
            const Divider(height: 5),
            const SizedBox(height: 15.0),
            const Icon(Icons.delete, size: 100, color: primaryColor),
            const SizedBox(height: 15.0),
            widget.studentCount == 1
                ? Text(
                    "Êtes-vous sûr de vouloir supprimer l'étudiant sélectionné ? Cette action est irréversible.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: mediumFontSize),
                  )
                : Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: mediumFontSize),
                      children: [
                        const TextSpan(
                          text: 'Êtes-vous sûr de vouloir supprimer les ',
                        ),
                        TextSpan(
                          text: '${widget.studentCount}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(
                          text:
                              ' étudiants sélectionnés ? Cette action est irréversible.',
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
            const SizedBox(height: 20.0),
            const Divider(height: 30),
            Row(
              children: <Widget>[
                Expanded(
                  child: AbsorbPointer(
                    absorbing: _isLoading,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                      style: secondaryButtonStyle,
                      child: Text(
                        'Annuler',
                        style: TextStyle(
                          fontSize: mediumFontSize,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: AbsorbPointer(
                    absorbing: _isLoading,
                    child: ElevatedButton(
                      onPressed: _deleteStudents,
                      style: primaryButtonStyle,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Supprimer',
                            style: TextStyle(
                              fontSize: mediumFontSize,
                              color: Colors.white,
                            ),
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
