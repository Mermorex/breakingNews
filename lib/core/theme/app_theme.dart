// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get dashboardTheme {
    // Crypto / Tech Dark Palette
    const Color darkBg = Color(0xFF0B0E14); // Deep dark background
    const Color cardBg = Color(0xFF151A25); // Slightly lighter card
    const Color primaryGlow = Color(0xFFFF8C00); // Dark Orange
    const Color secondaryGlow = Color(0xFFFFD700); // Gold

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Dark Color Scheme with Orange/Yellow seeds
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGlow,
        brightness: Brightness.dark,
        surface: cardBg,
        onSurface: Colors.white70,
        background: darkBg,
        onBackground: Colors.white,
        primary: primaryGlow,
        secondary: secondaryGlow,
      ),

      // FORCE Dark Background
      scaffoldBackgroundColor: darkBg,

      // Typography: Montserrat (Tech/Modern) and Noto Kufi (Arabic)
      textTheme: GoogleFonts.montserratTextTheme(
        ThemeData.dark().textTheme,
      ).copyWith(
        bodyLarge: GoogleFonts.montserrat(fontSize: 16, color: Colors.white70),
        bodyMedium: GoogleFonts.montserrat(fontSize: 14, color: Colors.white70),
        titleLarge: GoogleFonts.montserrat(
            fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        titleMedium: GoogleFonts.montserrat(
            fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: Colors.white70,
      ),
    );
  }
}
