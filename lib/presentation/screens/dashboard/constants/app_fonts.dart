import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppFonts {
  static bool containsArabic(String text) {
    return RegExp(
            r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]')
        .hasMatch(text);
  }

  static TextStyle getTextStyle({
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.normal,
    double height = 1.0,
    double letterSpacing = 0,
    String? text,
    bool forceArabic = false,
  }) {
    final bool isArabic = forceArabic || (text != null && containsArabic(text));

    if (isArabic) {
      return GoogleFonts.notoKufiArabic(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }

    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle title({
    required String text,
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.w700,
    double height = 1.3,
  }) {
    return getTextStyle(
      text: text,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      height: height,
    );
  }

  static TextStyle body({
    required String text,
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.normal,
    double height = 1.5,
  }) {
    return getTextStyle(
      text: text,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      height: height,
    );
  }

  static TextStyle caption({
    required String text,
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return getTextStyle(
      text: text,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: 0.5,
    );
  }
}
