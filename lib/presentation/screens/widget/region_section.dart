import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/rss_item_model.dart';
import 'source_card.dart';

class RegionSection extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final List<Map<String, String>> sources;
  final Map<String, List<RssItemModel>> data;
  final String regionPrefix;
  final VoidCallback onViewAll;
  final Future<void> Function(String) onArticleTap;

  const RegionSection({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.sources,
    required this.data,
    required this.regionPrefix,
    required this.onViewAll,
    required this.onArticleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 20),
        _buildGrid(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accentColor.withOpacity(0.2)),
          ),
          child: Center(
            child: Text(
              icon,
              style: const TextStyle(fontSize: 26),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: onViewAll,
          icon: const Text(
            'View All',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          label: const Icon(Icons.arrow_forward_rounded, size: 16),
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1400 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.25,
          ),
          itemCount: sources.length,
          itemBuilder: (context, index) {
            final source = sources[index];
            final key = '${regionPrefix}_${source['name']}';
            final items = data[key] ?? [];
            return SourceCard(
              sourceName: source['name']!,
              items: items,
              accentColor: accentColor,
              onArticleTap: onArticleTap,
            );
          },
        );
      },
    );
  }
}
