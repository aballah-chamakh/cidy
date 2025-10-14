import 'dart:convert';

import 'package:cidy/app_styles.dart';
import 'package:cidy/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cidy/authentication/login.dart';

class RemoveStudentsPopup extends StatefulWidget {
  final int studentCount;
  final VoidCallback onSuccess;
  final VoidCallback onError;
  final int groupId;
  final Set<int> studentIds;

  const RemoveStudentsPopup({
    super.key,
    required this.studentCount,
    required this.onSuccess,
    required this.onError,
    required this.groupId,
    required this.studentIds,
  });

  @override
  State<RemoveStudentsPopup> createState() => _RemoveStudentsPopupState();
}

class _RemoveStudentsPopupState extends State<RemoveStudentsPopup> {
  bool _isLoading = false;

  Future<void> _removeStudentsFromGroup() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
        return;
      }

      final url = Uri.parse(
        '${Config.backendUrl}/api/teacher/groups/${widget.groupId}/remove-students/',
      );
      final response = await http.put(
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Confirmer le retrait',
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
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
              ],
            ),
            const Divider(height: 5),
            const SizedBox(height: 15.0),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              const Icon(Icons.person_remove, size: 100, color: primaryColor),
              const SizedBox(height: 15.0),
              Text(
                widget.studentCount == 1
                    ? 'Êtes-vous sûr de vouloir retirer l’élève sélectionné du groupe ?'
                    : 'Êtes-vous sûr de vouloir retirer les ${widget.studentCount} élèves sélectionnés du groupe ?',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: mediumFontSize),
              ),
              const SizedBox(height: 20),
              Column(
                children: <Widget>[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _removeStudentsFromGroup,
                      style: primaryButtonStyle,
                      child: const Text(
                        'Retirer',
                        style: TextStyle(
                          fontSize: mediumFontSize,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: double.infinity,
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
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
