import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryColor = Color(0xFFF54E1E);
  static const Color backgroundColor = Colors.white;
  static const Color textColor = Colors.black;
  static const Color whiteColor = Colors.white;
  static const Color errorColor = Colors.red;

  // Font Sizes
  static const double headlineLargeSize = 60.0;
  static const double headlineMediumSize = 24.0;
  static const double bodyLargeSize = 18.0;
  static const double bodyMediumSize = 16.0;
  static const double bodySmallSize = 14.0;

  // Spacing and Padding
  static const double screenPaddingHorizontal = 24.0;
  static const double screenPaddingVertical = 16.0;
  static const double contentPadding = 16.0;
  static const double smallSpacing = 8.0;
  static const double mediumSpacing = 16.0;
  static const double largeSpacing = 24.0;
  static const double extraLargeSpacing = 48.0;

  // Button Styles
  static const double buttonHeight = 56.0;
  static const double buttonPaddingVertical = 16.0;
  static const double buttonBorderRadius = 8.0;

  // Input Field Styles
  static const double inputBorderRadius = 8.0;

  // Image Heights
  static const double splashLogoHeight = 100.0;
  static const double loginImageHeight = 250.0;
  static const double registerImageHeight = 200.0;
  static const double brandLogoHeight = 40.0;

  // Font Weights
  static const FontWeight boldWeight = FontWeight.bold;
  static const FontWeight normalWeight = FontWeight.normal;

  // Text Styles
  static const TextStyle headlineLarge = TextStyle(
    fontSize: headlineLargeSize,
    fontFamily: 'Nunito',
    fontWeight: boldWeight,
    color: primaryColor,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: headlineMediumSize,
    fontWeight: boldWeight,
    color: textColor,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: bodyLargeSize,
    color: textColor,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: bodyMediumSize,
    color: textColor,
  );

  static const TextStyle bodyBold = TextStyle(
    fontSize: bodyMediumSize,
    fontWeight: boldWeight,
    color: textColor,
  );

  static final TextStyle buttonText = bodyLarge.copyWith(
    color: whiteColor,
    fontWeight: boldWeight,
  );

  // Button Styles
  static ButtonStyle get elevatedButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: whiteColor,
    minimumSize: const Size.fromHeight(buttonHeight),
    padding: const EdgeInsets.symmetric(vertical: buttonPaddingVertical),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonBorderRadius),
    ),
  );

  static ButtonStyle get textButtonStyle =>
      TextButton.styleFrom(foregroundColor: primaryColor);

  // Input Decoration
  static InputDecoration getInputDecoration(String labelText) =>
      InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: primaryColor),
          borderRadius: BorderRadius.circular(inputBorderRadius),
        ),
      );

  // Segmented Button Style
  static ButtonStyle get segmentedButtonStyle => SegmentedButton.styleFrom(
    backgroundColor: backgroundColor,
    foregroundColor: primaryColor,
    selectedForegroundColor: whiteColor,
    selectedBackgroundColor: primaryColor,
  );

  // Common Padding
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: screenPaddingHorizontal,
    vertical: screenPaddingVertical,
  );

  static const EdgeInsets contentPaddingAll = EdgeInsets.all(contentPadding);

  static const EdgeInsets registerScreenPadding = EdgeInsets.symmetric(
    horizontal: 10.0,
  );

  // Common SizedBoxes
  static const Widget smallVerticalSpace = SizedBox(height: smallSpacing);
  static const Widget mediumVerticalSpace = SizedBox(height: mediumSpacing);
  static const Widget largeVerticalSpace = SizedBox(height: largeSpacing);
  static const Widget extraLargeVerticalSpace = SizedBox(
    height: extraLargeSpacing,
  );
}
