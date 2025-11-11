import 'package:flutter/material.dart';

const Color primaryColor = Color(0xFF384059);
const double popupHorizontalMargin = 10.0;
const double popupPadding = 15.0;
const double popupBorderRadius = 16.0;

const double headerFontSize = 20.0;
const double headerIconSize = 30.0;
const double mediumFontSize = 18.0;

ButtonStyle primaryButtonStyle =
    ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(vertical: 15),
    ).copyWith(
      // Force the primary colors for every material state, including disabled.
      backgroundColor: MaterialStateProperty.resolveWith(
        (states) => primaryColor,
      ),
      foregroundColor: MaterialStateProperty.resolveWith(
        (states) => Colors.white,
      ),
      overlayColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.disabled)) {
          return Colors.transparent;
        }
        if (states.contains(MaterialState.pressed)) {
          return primaryColor.withOpacity(0.85);
        }
        return primaryColor;
      }),
    );

ButtonStyle secondaryButtonStyle = TextButton.styleFrom(
  side: BorderSide(color: primaryColor),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  padding: const EdgeInsets.symmetric(vertical: 15),
);

EdgeInsets inputContentPadding = EdgeInsets.symmetric(
  vertical: 15.0,
  horizontal: 10.0,
);

EdgeInsets buttonSegmentPadding = EdgeInsets.symmetric(vertical: 10.0);

double inputBorderRadius = 8.0;
double buttonSegmentBorderRadius = 8.0;
