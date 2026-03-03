import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class StatsRow extends StatelessWidget {
  final int tunisianCount;
  final int frenchCount;
  final int moroccanCount; // NEW
  final int algerianCount; // NEW
  final int internationalCount;
  final int totalArticles;

  const StatsRow({
    super.key,
    required this.tunisianCount,
    required this.frenchCount,
    required this.moroccanCount, // NEW
    required this.algerianCount, // NEW
    required this.internationalCount,
    required this.totalArticles,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          icon: Icons.flag_rounded,
          iconColor: AppColors.tunisianRed,
          label: 'Tunisian Sources',
          value: tunisianCount.toString(),
          trend: '+2 this week',
          trendUp: true,
        ),
        const SizedBox(width: 16),
        _StatCard(
          icon: Icons.flag_rounded,
          iconColor: AppColors.frenchBlue,
          label: 'French Sources',
          value: frenchCount.toString(),
          trend: 'Stable',
          trendUp: null,
        ),
        const SizedBox(width: 16),
        _StatCard(
          icon: Icons.flag_rounded,
          iconColor: Colors.green.shade700,
          label: 'Moroccan Sources',
          value: moroccanCount.toString(),
          trend: '+3 new',
          trendUp: true,
        ),
        const SizedBox(width: 16),
        _StatCard(
          icon: Icons.flag_rounded, // NEW
          iconColor: Colors.green.shade600, // Algerian green
          label: 'Algerian Sources', // NEW
          value: algerianCount.toString(),
          trend: '+4 new',
          trendUp: true,
        ),
        const SizedBox(width: 16),
        _StatCard(
          icon: Icons.language_rounded,
          iconColor: AppColors.internationalGreen,
          label: 'International',
          value: internationalCount.toString(),
          trend: '+1 new',
          trendUp: true,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String trend;
  final bool? trendUp;
  final bool isLive;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.trend,
    this.trendUp,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                if (isLive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.internationalGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.internationalGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.internationalGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (trendUp != null) ...[
                  Icon(
                    trendUp! ? Icons.trending_up : Icons.trending_down,
                    size: 14,
                    color: trendUp!
                        ? AppColors.internationalGreen
                        : AppColors.tunisianRed,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  trend,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: trendUp == null
                        ? AppColors.textSecondary
                        : trendUp!
                            ? AppColors.internationalGreen
                            : AppColors.tunisianRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
