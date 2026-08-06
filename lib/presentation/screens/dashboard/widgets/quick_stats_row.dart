import 'package:flutter/material.dart';
import 'package:news_app/core/theme/app_colors.dart' as theme;
import 'package:news_app/core/utils/responsive.dart';
import '../constants/app_fonts.dart';

class QuickStatsRow extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onCategoryTap;
  final String currentLangMode;
  final VoidCallback onToggleLanguage;

  const QuickStatsRow({
    super.key,
    required this.selectedIndex,
    required this.onCategoryTap,
    required this.currentLangMode,
    required this.onToggleLanguage,
  });

  final List<Map<String, dynamic>> categories = const [
    {'emoji': '🌍', 'label': 'World'},
    {'emoji': '🇹🇳', 'label': 'Tunisia'},
    {'emoji': '🇲🇦', 'label': 'Morocco'},
    {'emoji': '🇩🇿', 'label': 'Algeria'},
    {'emoji': '🇫🇷', 'label': 'France'},
    {'emoji': '🇮🇷', 'label': 'Iran'},
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      margin:
          EdgeInsets.fromLTRB(isMobile ? 16 : 32, 24, isMobile ? 16 : 32, 8),
      child: Row(
        children: [
          // Horizontal Pills
          Expanded(
            child: SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final isSelected = index == selectedIndex;
                  final cat = categories[index];
                  final label = cat['label'] as String;

                  return GestureDetector(
                    onTap: () => onCategoryTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.AppColors.textPrimary
                            : theme.AppColors.surface,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: isSelected
                              ? theme.AppColors.textPrimary
                              : theme.AppColors.border,
                          width: 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color: theme.AppColors.textPrimary
                                        .withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4))
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cat['emoji'] as String,
                              style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Text(
                            label,
                            style: AppFonts.body(
                              text: label,
                              fontSize: 15,
                              color: isSelected
                                  ? Colors.white
                                  : theme.AppColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Language Toggle
          _buildLangToggle(),
        ],
      ),
    );
  }

  Widget _buildLangToggle() {
    String displayText = currentLangMode == 'arabic'
        ? 'AR'
        : currentLangMode == 'english'
            ? 'EN'
            : 'ORIG';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggleLanguage,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: theme.AppColors.surface,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: theme.AppColors.border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.translate,
                  color: theme.AppColors.textPrimary, size: 18),
              const SizedBox(width: 8),
              Text(
                displayText,
                style: AppFonts.caption(
                  text: displayText,
                  fontSize: 14,
                  color: theme.AppColors.textPrimary,
                ).copyWith(letterSpacing: 0.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
