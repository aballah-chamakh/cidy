import 'package:flutter/material.dart';
import 'package:cidy/app_styles.dart';

class DeleteGroupPopup extends StatelessWidget {
  final String groupName;

  const DeleteGroupPopup({super.key, required this.groupName});

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
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
              ],
            ),
            const Divider(height: 5),
            const SizedBox(height: 15.0),
            Icon(Icons.delete, color: primaryColor, size: 100),
            const SizedBox(height: 15.0),
            Text(
              'Êtes-vous sûr de vouloir supprimer le groupe : $groupName ?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: mediumFontSize),
            ),
            const SizedBox(height: 20.0),
            Column(
              children: <Widget>[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    style: primaryButtonStyle,
                    child: const Text(
                      'Supprimer',
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
        ),
      ),
    );
  }
}
