import 'package:flutter/material.dart';
import 'package:news_app/data/models/rss_item_model.dart';
import 'package:news_app/core/theme/app_colors.dart' as theme;
import '../constants/app_fonts.dart';

class DashboardHeader extends StatelessWidget {
  final RssItemModel? topArticle;
  final String Function(RssItemModel) getDisplayTitle;
  final String Function(RssItemModel) getDisplaySource;
  final Future<void> Function(String) onLaunchUrl;

  const DashboardHeader({
    super.key,
    required this.topArticle,
    required this.getDisplayTitle,
    required this.getDisplaySource,
    required this.onLaunchUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (topArticle == null) {
      return Container(
        margin:
            EdgeInsets.fromLTRB(isMobile ? 16 : 32, 32, isMobile ? 16 : 32, 0),
        height: isMobile ? 200 : 280,
        child: Center(
          child: CircularProgressIndicator(
              color: theme.AppColors.tunisianRed.withOpacity(0.5)),
        ),
      );
    }

    final displayTitle = getDisplayTitle(topArticle!);
    final displaySource = getDisplaySource(topArticle!);
    final isArabic = AppFonts.containsArabic(displayTitle);

    return GestureDetector(
      onTap: () => onLaunchUrl(topArticle!.link),
      child: Container(
        margin:
            EdgeInsets.fromLTRB(isMobile ? 16 : 32, 32, isMobile ? 16 : 32, 0),
        padding: EdgeInsets.all(isMobile ? 0 : 16),
        child: Column(
          crossAxisAlignment:
              isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Clean Text Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.AppColors.tunisianRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'TOP STORY • $displaySource',
                style: AppFonts.caption(
                  text: 'TOP STORY • $displaySource',
                  fontSize: 12,
                  color: theme.AppColors.tunisianRed,
                ).copyWith(letterSpacing: 1.0, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 20),

            // Massive, Readable Title
            Text(
              displayTitle,
              style: AppFonts.title(
                text: displayTitle,
                fontSize: isMobile ? 28 : 38,
                color: theme.AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                height: 1.15, // Tighter line height for large headlines
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
            ),
            const SizedBox(height: 24),

            // Read more indicator
            Row(
              mainAxisAlignment:
                  isArabic ? MainAxisAlignment.start : MainAxisAlignment.end,
              children: [
                Text(
                  isArabic ? 'اقرأ الخبر كاملاً' : 'Read full story',
                  style: AppFonts.body(
                    text: isArabic ? 'اقرأ الخبر كاملاً' : 'Read full story',
                    fontSize: 15,
                    color: theme.AppColors.frenchBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isArabic
                      ? Icons.arrow_back_rounded
                      : Icons.arrow_forward_rounded,
                  color: theme.AppColors.frenchBlue,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(color: theme.AppColors.border, thickness: 1, height: 1),
          ],
        ),
      ),
    );
  }
}
