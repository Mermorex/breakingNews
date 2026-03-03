import 'package:flutter/material.dart';

class AppColors {
  // Primary palette
  static const Color tunisianRed = Color(0xFFE53935);
  static const Color frenchBlue = Color(0xFF1E88E5);
  static const Color internationalGreen = Color(0xFF43A047);
  static const Color accentPurple = Color(0xFF8E24AA);

  // Neutrals
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  // Gradients
  static const LinearGradient brandGradient = LinearGradient(
    colors: [tunisianRed, frenchBlue, internationalGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
