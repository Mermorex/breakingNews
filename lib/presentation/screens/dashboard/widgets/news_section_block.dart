import 'package:flutter/material.dart';
import 'package:news_app/core/utils/responsive.dart';
import 'package:news_app/data/models/rss_item_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_fonts.dart';
import 'expandable_featured_card.dart';
import 'expandable_compact_card.dart';

class NewsSectionBlock extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final List<RssItemModel> articles;
  final VoidCallback onViewAll;
  final Color accentColor;
  final bool isLoading;
  final bool hasAnyArticles;
  final String currentLangMode;
  final String Function(RssItemModel) getDisplayTitle;
  final String Function(RssItemModel) getDisplaySource;
  final Future<void> Function(String) onLaunchUrl;

  const NewsSectionBlock({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.articles,
    required this.onViewAll,
    required this.accentColor,
    required this.isLoading,
    required this.hasAnyArticles,
    required this.currentLangMode,
    required this.getDisplayTitle,
    required this.getDisplaySource,
    required this.onLaunchUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(isMobile ? 16 : 32, 28, isMobile ? 16 : 32, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Section header ---
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accentColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppFonts.title(
                          text: title,
                          fontSize: 20,
                          color: Colors.white,
                        ).copyWith(letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppFonts.body(
                          text: subtitle,
                          fontSize: 13,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildViewAllButton(),
              ],
            ),
            const SizedBox(height: 20),

            // --- Section content ---
            if (isLoading && articles.isEmpty)
              _buildLoadingState()
            else if (articles.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 700) {
                    return Column(
                      children: [
                        ExpandableFeaturedCard(
                          article: articles.first,
                          accentColor: accentColor,
                          isArabic: _isArabic(articles.first),
                          isSummaryArabic: currentLangMode != 'english',
                          getDisplayTitle: getDisplayTitle,
                          getDisplaySource: getDisplaySource,
                          onLaunchUrl: onLaunchUrl,
                        ),
                        const SizedBox(height: 12),
                        ...articles
                            .skip(1)
                            .take(2)
                            .map((article) => ExpandableCompactCard(
                                  article: article,
                                  accentColor: accentColor,
                                  isArabic: _isArabic(article),
                                  isSummaryArabic: currentLangMode != 'english',
                                  getDisplayTitle: getDisplayTitle,
                                  getDisplaySource: getDisplaySource,
                                  onLaunchUrl: onLaunchUrl,
                                )),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: ExpandableFeaturedCard(
                          article: articles.first,
                          accentColor: accentColor,
                          isArabic: _isArabic(articles.first),
                          isSummaryArabic: currentLangMode != 'english',
                          getDisplayTitle: getDisplayTitle,
                          getDisplaySource: getDisplaySource,
                          onLaunchUrl: onLaunchUrl,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            if (articles.length > 1)
                              ExpandableCompactCard(
                                article: articles[1],
                                accentColor: accentColor,
                                isArabic: _isArabic(articles[1]),
                                isSummaryArabic: currentLangMode != 'english',
                                getDisplayTitle: getDisplayTitle,
                                getDisplaySource: getDisplaySource,
                                onLaunchUrl: onLaunchUrl,
                              ),
                            if (articles.length > 2) const SizedBox(height: 12),
                            if (articles.length > 2)
                              ExpandableCompactCard(
                                article: articles[2],
                                accentColor: accentColor,
                                isArabic: _isArabic(articles[2]),
                                isSummaryArabic: currentLangMode != 'english',
                                getDisplayTitle: getDisplayTitle,
                                getDisplaySource: getDisplaySource,
                                onLaunchUrl: onLaunchUrl,
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              )
            else if (!hasAnyArticles)
              _buildLoadingState()
            else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  bool _isArabic(RssItemModel article) {
    return currentLangMode == 'arabic' ||
        AppFonts.containsArabic(article.title);
  }

  Widget _buildViewAllButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onViewAll,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accentColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View All',
                style: AppFonts.caption(
                  text: 'View All',
                  fontSize: 12,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, size: 14, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: AppColors.accentOrange,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading articles...',
              style: AppFonts.body(
                text: 'Loading articles...',
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'No articles found',
              style: AppFonts.title(
                text: 'No articles found',
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
