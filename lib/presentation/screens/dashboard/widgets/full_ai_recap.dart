import 'package:flutter/material.dart';
import 'package:news_app/core/theme/app_colors.dart' as theme;
import '../constants/app_fonts.dart';

class FullAiRecap extends StatelessWidget {
  final String summary;
  final bool isArabic;
  final bool isLoading;
  final VoidCallback onClose;

  const FullAiRecap({
    super.key,
    required this.summary,
    required this.isArabic,
    required this.isLoading,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: theme.AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.AppColors.border,
            width: 1,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      theme.AppColors.accentPurple),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                isArabic ? 'جاري التلخيص...' : 'Generating summary...',
                style: AppFonts.body(
                  text: isArabic ? 'جاري التلخيص...' : 'Generating summary...',
                  fontSize: 15,
                  color: theme.AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.AppColors.surface, // Clean white background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.AppColors.border, // Subtle gray border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.AppColors.textPrimary
                .withOpacity(0.05), // Very soft shadow
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Clean Header bar ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.AppColors.background, // Light gray header bg
                border: Border(
                  bottom: BorderSide(
                    color: theme.AppColors.border,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.AppColors.accentPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 16, color: theme.AppColors.accentPurple),
                        const SizedBox(width: 8),
                        Text(
                          isArabic ? 'ملخص ذكي' : 'AI Recap',
                          style: AppFonts.body(
                            text: isArabic ? 'ملخص ذكي' : 'AI Recap',
                            fontSize: 14,
                            color: theme.AppColors.accentPurple,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onClose,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.close,
                          size: 20, color: theme.AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            // --- Readable Summary body ---
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  summary,
                  style: AppFonts.body(
                    text: summary,
                    fontSize: 16, // Bigger text for readability
                    color: theme.AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    height: 1.6, // Better line spacing
                  ),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
