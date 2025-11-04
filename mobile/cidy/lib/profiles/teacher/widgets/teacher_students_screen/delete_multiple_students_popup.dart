import 'package:cidy/app_styles.dart';
import 'package:flutter/material.dart';

class DeleteMultipleStudentsPopup extends StatelessWidget {
  final int studentCount;

  const DeleteMultipleStudentsPopup({super.key, required this.studentCount});

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
            const Icon(Icons.delete, size: 100, color: primaryColor),
            const SizedBox(height: 15.0),
            studentCount == 1
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
                          text: '$studentCount',
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
                const SizedBox(width: 5),
                Expanded(
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
