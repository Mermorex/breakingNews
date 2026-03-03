import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/rss_item_model.dart';
import '../../../../utils/date_time_extension.dart';

class SourceCard extends StatelessWidget {
  final String sourceName;
  final List<RssItemModel> items;
  final Color accentColor;
  final Future<void> Function(String) onArticleTap;

  const SourceCard({
    super.key,
    required this.sourceName,
    required this.items,
    required this.accentColor,
    required this.onArticleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          _buildHeader(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.03),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          bottom: BorderSide(color: accentColor.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sourceName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${items.length} new',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rss_feed_outlined,
              color: AppColors.textSecondary.withOpacity(0.3),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'No updates yet',
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: AppColors.border.withOpacity(0.5),
        indent: 8,
        endIndent: 8,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _ArticleTile(
          item: item,
          accentColor: accentColor,
          onTap: () => onArticleTap(item.link),
        );
      },
    );
  }
}

class _ArticleTile extends StatelessWidget {
  final RssItemModel item;
  final Color accentColor;
  final VoidCallback onTap;

  const _ArticleTile({
    required this.item,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: accentColor.withOpacity(0.03),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 12,
                    color: AppColors.textSecondary.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.publishedAt?.toTimeAgo() ?? 'Just now',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 12,
                    color: accentColor.withOpacity(0.6),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
