import 'package:cidy/app_styles.dart';
import 'package:flutter/material.dart';

class DeleteStudentPopup extends StatefulWidget {
  final String studentName;
  final Future<bool> Function() onDelete;

  const DeleteStudentPopup({
    super.key,
    required this.studentName,
    required this.onDelete,
  });

  @override
  State<DeleteStudentPopup> createState() => _DeleteStudentPopupState();
}

class _DeleteStudentPopupState extends State<DeleteStudentPopup> {
  bool _isLoading = false;

  Future<void> _handleDelete() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await widget.onDelete();
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
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
                    onPressed: _isLoading ? null : _handleDelete,
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
