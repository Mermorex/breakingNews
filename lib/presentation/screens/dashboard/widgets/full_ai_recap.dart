import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
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
          gradient: LinearGradient(
            colors: [
              AppColors.accentPurple.withOpacity(0.2),
              AppColors.accentEmerald.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accentPurple.withOpacity(0.3),
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
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.accentPurple),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isArabic ? 'جاري التلخيص...' : 'Generating summary...',
                style: AppFonts.body(
                  text: isArabic ? 'جاري التلخيص...' : 'Generating summary...',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentPurple.withOpacity(0.15),
            AppColors.cardBgElevated.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentPurple.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentPurple.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Header bar ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.accentPurple.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 14, color: AppColors.accentPurple),
                        const SizedBox(width: 6),
                        Text(
                          isArabic ? 'ملخص ذكي' : 'AI Recap',
                          style: AppFonts.caption(
                            text: isArabic ? 'ملخص ذكي' : 'AI Recap',
                            fontSize: 11,
                            color: AppColors.accentPurple,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close,
                          size: 16, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            // --- Summary body ---
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text(
                  summary,
                  style: AppFonts.body(
                    text: summary,
                    fontSize: isArabic ? 14 : 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ).copyWith(height: 1.7, letterSpacing: 0.2),
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
