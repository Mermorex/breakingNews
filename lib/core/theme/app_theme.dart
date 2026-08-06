// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart'; // Make sure this import path is correct

class AppTheme {
  static ThemeData get dashboardTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light, // Changed to Light Mode

      // Light Color Scheme based on AppColors
      colorScheme: const ColorScheme.light(
        primary: AppColors.tunisianRed,
        secondary: AppColors.frenchBlue,
        surface: AppColors.surface, // White
        onSurface: AppColors.textPrimary, // Dark text
        background: AppColors.background, // Light gray/white background
        onBackground: AppColors.textPrimary,
        onError: AppColors.tunisianRed,
      ),

      // Light Background
      scaffoldBackgroundColor: AppColors.background,

      // Typography: Montserrat for Light Mode
      textTheme: GoogleFonts.montserratTextTheme(
        ThemeData.light().textTheme, // Use light base text theme
      ).copyWith(
        bodyLarge: GoogleFonts.montserrat(
            fontSize: 16, color: AppColors.textSecondary),
        bodyMedium: GoogleFonts.montserrat(
            fontSize: 14, color: AppColors.textSecondary),
        titleLarge: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary),
        titleMedium: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
      ),

      // Icon Theme for Light Mode
      iconTheme: const IconThemeData(
        color: AppColors.textSecondary, // Dark gray icons
      ),

      // Card and Divider themes
      cardColor: AppColors.surface,
      dividerColor: AppColors.border,
    );
  }
}
