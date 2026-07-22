import 'package:flutter/material.dart';
import 'package:news_app/core/utils/responsive.dart';
import 'package:news_app/data/models/news_source.dart';
import '../constants/app_colors.dart';
import '../constants/app_fonts.dart';

class QuickStatsRow extends StatelessWidget {
  final int tunisianCount;
  final int moroccanCount;
  final int algerianCount;
  final int frenchCount;
  final int iranianCount;
  final VoidCallback onViewTunisia;
  final VoidCallback onViewMorocco;
  final VoidCallback onViewAlgeria;
  final VoidCallback onViewFrance;
  final VoidCallback onViewIran;

  const QuickStatsRow({
    super.key,
    required this.tunisianCount,
    required this.moroccanCount,
    required this.algerianCount,
    required this.frenchCount,
    required this.iranianCount,
    required this.onViewTunisia,
    required this.onViewMorocco,
    required this.onViewAlgeria,
    required this.onViewFrance,
    required this.onViewIran,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Container(
      margin:
          EdgeInsets.fromLTRB(isMobile ? 16 : 32, 20, isMobile ? 16 : 32, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatChip('🇹🇳', tunisianCount, onViewTunisia,
                AppColors.tunisiaAccent, NewsSources.tunisian.length),
            const SizedBox(width: 10),
            _buildStatChip('🇲🇦', moroccanCount, onViewMorocco,
                AppColors.moroccoAccent, NewsSources.moroccan.length),
            const SizedBox(width: 10),
            _buildStatChip('🇩🇿', algerianCount, onViewAlgeria,
                AppColors.algeriaAccent, NewsSources.algerian.length),
            const SizedBox(width: 10),
            _buildStatChip('🇫🇷', frenchCount, onViewFrance,
                AppColors.franceAccent, NewsSources.french.length),
            const SizedBox(width: 10),
            _buildStatChip('🇮🇷', iranianCount, onViewIran,
                AppColors.iranAccent, NewsSources.iranian.length),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String emoji, int count, VoidCallback onTap,
      Color color, int sourceCount) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: AppFonts.title(
                    text: count.toString(),
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$sourceCount sources',
                  style: AppFonts.caption(
                    text: '$sourceCount sources',
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
