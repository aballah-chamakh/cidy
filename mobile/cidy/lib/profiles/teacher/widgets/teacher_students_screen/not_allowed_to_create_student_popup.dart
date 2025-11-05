import 'package:cidy/app_styles.dart';
import 'package:flutter/material.dart';

class NotAllowedToCreateStudentPopup extends StatelessWidget {
  const NotAllowedToCreateStudentPopup({super.key});

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
                  'Information',
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
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const Divider(height: 5),
            const SizedBox(height: 20.0),
            const Icon(Icons.info_outline, size: 100, color: primaryColor),
            const SizedBox(height: 15.0),
            const Text(
              'Vous devez ajouter au moins un niveau pour pouvoir créer un étudiant.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: mediumFontSize),
            ),
            const SizedBox(height: 15.0),
            const Divider(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: primaryButtonStyle,
              child: const Text(
                'OK',
                style: TextStyle(fontSize: mediumFontSize, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
