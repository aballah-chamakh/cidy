import 'package:flutter/material.dart';
import 'package:cidy/app_styles.dart';

class DeleteGroupPopup extends StatefulWidget {
  final String groupName;
  final Future<void> Function() onDelete;

  const DeleteGroupPopup({
    super.key,
    required this.groupName,
    required this.onDelete,
  });

  @override
  State<DeleteGroupPopup> createState() => _DeleteGroupPopupState();
}

class _DeleteGroupPopupState extends State<DeleteGroupPopup> {
  bool _isLoading = false;

  Future<void> _handleDelete() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onDelete();
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    final ButtonStyle deleteButtonStyle = primaryButtonStyle.copyWith(
      backgroundColor: MaterialStateProperty.resolveWith<Color>(
        (states) => primaryColor,
      ),
      foregroundColor: MaterialStateProperty.resolveWith<Color>(
        (states) => Colors.white,
      ),
    );

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
                  onPressed: _isLoading ? null : _handleCancel,
                ),
              ],
            ),
            const Divider(height: 5),
            const SizedBox(height: 15.0),
            Icon(Icons.delete, color: primaryColor, size: 100),
            const SizedBox(height: 15.0),
            Text(
              'Êtes-vous sûr de vouloir supprimer le groupe : ${widget.groupName} ?',
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
                const SizedBox(width: 5),
                Expanded(
                  child: ElevatedButton(
                    style: deleteButtonStyle,
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
