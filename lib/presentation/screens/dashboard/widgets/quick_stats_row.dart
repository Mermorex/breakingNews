import 'package:flutter/material.dart';
import 'package:news_app/core/utils/responsive.dart';
import '../constants/app_colors.dart';
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
          EdgeInsets.fromLTRB(isMobile ? 16 : 32, 20, isMobile ? 16 : 32, 8),
      child: Row(
        children: [
          // Horizontal Pills
          Expanded(
            child: SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final isSelected = index == selectedIndex;
                  final cat = categories[index];

                  return GestureDetector(
                    onTap: () => onCategoryTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accentOrange.withOpacity(0.15)
                            : AppColors.cardBg,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accentOrange
                              : AppColors.borderSubtle,
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color:
                                        AppColors.accentOrange.withOpacity(0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4))
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cat['emoji'] as String,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            cat['label'] as String,
                            style: AppFonts.caption(
                              text: cat['label'] as String,
                              fontSize: 13,
                              color: isSelected
                                  ? AppColors.accentOrange
                                  : AppColors.textSecondary,
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

          const SizedBox(width: 12),

          // Language Toggle (compacted to fit the row)
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: AppColors.borderSubtle, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.translate, color: AppColors.textSecondary, size: 16),
              const SizedBox(width: 6),
              Text(
                displayText,
                style: AppFonts.caption(
                  text: displayText,
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ).copyWith(letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
