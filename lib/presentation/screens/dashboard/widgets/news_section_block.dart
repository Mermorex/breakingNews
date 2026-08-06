import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:news_app/data/grok_service.dart';
import 'package:news_app/data/models/rss_item_model.dart';
import 'package:news_app/core/theme/app_colors.dart' as theme;
import '../constants/app_fonts.dart';

class NewsSectionBlock extends StatefulWidget {
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
  State<NewsSectionBlock> createState() => _NewsSectionBlockState();
}

class _NewsSectionBlockState extends State<NewsSectionBlock> {
  final Set<int> _expandedRecaps = {};
  final Map<int, String> _summaries = {};
  final Set<int> _loadingSummaries = {};

  Future<void> _toggleRecap(int index) async {
    if (_loadingSummaries.contains(index)) return;

    if (_expandedRecaps.contains(index)) {
      setState(() => _expandedRecaps.remove(index));
      return;
    }

    setState(() {
      _expandedRecaps.add(index);
      _loadingSummaries.add(index);
    });

    try {
      final article = widget.articles[index];
      final result = await MistralService().summarizeArticle(
        article.title,
        article.description ?? '',
        isArabic: widget.currentLangMode != 'english',
      );
      if (mounted) {
        setState(() {
          _summaries[index] = result;
          _loadingSummaries.remove(index);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _summaries[index] = "Could not generate summary.";
          _loadingSummaries.remove(index);
        });
      }
    }
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return intl.DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isArabicSection = widget.currentLangMode == 'arabic';

    if (widget.isLoading && widget.articles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
            child:
                CircularProgressIndicator(color: theme.AppColors.tunisianRed)),
      );
    }

    if (widget.articles.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.AppColors.border, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- JOURNAL HEADER ---
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            child: Row(
              children: [
                Text(widget.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Text(
                  widget.title.toUpperCase(),
                  style: AppFonts.title(
                    text: widget.title.toUpperCase(),
                    fontSize: 20,
                    color: theme.AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ).copyWith(letterSpacing: 1.2),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onViewAll,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'View All',
                      style: AppFonts.body(
                        text: 'View All',
                        fontSize: 13,
                        color: theme.AppColors.frenchBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- LEAD STORY ---
          _buildLeadArticle(0, isArabicSection),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child:
                Divider(color: theme.AppColors.border, thickness: 1, height: 1),
          ),

          // --- TWO COLUMN GRID ---
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 500) {
                return Column(
                  children: [
                    for (int i = 1; i < widget.articles.length; i++)
                      _buildColumnArticle(i, isArabicSection,
                          isLast: i == widget.articles.length - 1),
                  ],
                );
              }

              final int midPoint = (1 + widget.articles.length) ~/ 2;
              final leftColumnArticles = widget.articles.sublist(1, midPoint);
              final rightColumnArticles = widget.articles.sublist(midPoint);

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          for (int i = 0; i < leftColumnArticles.length; i++)
                            _buildColumnArticle(
                              1 + i,
                              isArabicSection,
                              isLast: i == leftColumnArticles.length - 1 &&
                                  rightColumnArticles.isEmpty,
                            ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      color: theme.AppColors.border,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          for (int i = 0; i < rightColumnArticles.length; i++)
                            _buildColumnArticle(
                              midPoint + i,
                              isArabicSection,
                              isLast: i == rightColumnArticles.length - 1,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- LEAD ARTICLE WIDGET ---
  Widget _buildLeadArticle(int index, bool isArabicSection) {
    final article = widget.articles[index];
    final isArabic = isArabicSection || AppFonts.containsArabic(article.title);
    final isExpanded = _expandedRecaps.contains(index);
    final isLoading = _loadingSummaries.contains(index);
    final titleText = widget.getDisplayTitle(article);
    final sourceText = widget.getDisplaySource(article);
    final timeText = _formatTimeAgo(article.publishedAt);

    return GestureDetector(
      onTap: () => widget.onLaunchUrl(article.link),
      child: Column(
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            titleText,
            style: AppFonts.title(
              text: titleText,
              fontSize: 26,
              color: theme.AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment:
                isArabic ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              Text(
                sourceText,
                style: AppFonts.caption(
                  text: sourceText,
                  fontSize: 13,
                  color: widget.accentColor,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 16),
              Text(
                timeText,
                style: AppFonts.body(
                  text: timeText,
                  fontSize: 13,
                  color: theme.AppColors.textSecondary,
                ),
              ),
              const Spacer(),

              // --- AI RECAP BUTTON ---
              GestureDetector(
                onTap: () => _toggleRecap(index),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.AppColors.accentPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: theme.AppColors.accentPurple.withOpacity(0.3),
                        width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 16, color: theme.AppColors.accentPurple),
                      const SizedBox(width: 8),
                      Text(
                        'AI Recap',
                        style: AppFonts.body(
                          text: 'AI Recap',
                          fontSize: 13,
                          color: theme.AppColors.accentPurple,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (isExpanded) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border(
                    left: BorderSide(
                        color: theme.AppColors.accentPurple, width: 4)),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 40,
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: theme.AppColors.accentPurple),
                        ),
                      ),
                    )
                  : Text(
                      _summaries[index] ?? '',
                      style: AppFonts.body(
                        text: _summaries[index] ?? '',
                        fontSize: 16,
                        color: theme.AppColors.textSecondary,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    ),
            )
          ]
        ],
      ),
    );
  }

  // --- COLUMN ARTICLE WIDGET ---
  Widget _buildColumnArticle(int index, bool isArabicSection,
      {required bool isLast}) {
    final article = widget.articles[index];
    final isArabic = isArabicSection || AppFonts.containsArabic(article.title);
    final isExpanded = _expandedRecaps.contains(index);
    final isLoading = _loadingSummaries.contains(index);
    final titleText = widget.getDisplayTitle(article);
    final sourceText = widget.getDisplaySource(article);
    final timeText = _formatTimeAgo(article.publishedAt);

    return GestureDetector(
      onTap: () => widget.onLaunchUrl(article.link),
      child: Container(
        padding: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                      color: theme.AppColors.border.withOpacity(0.5),
                      width: 1)),
        ),
        child: Column(
          crossAxisAlignment:
              isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              titleText,
              style: AppFonts.title(
                text: titleText,
                fontSize: 17,
                color: theme.AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment:
                  isArabic ? MainAxisAlignment.start : MainAxisAlignment.end,
              children: [
                Text(
                  sourceText,
                  style: AppFonts.caption(
                    text: sourceText,
                    fontSize: 12,
                    color: widget.accentColor,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Text(
                  timeText,
                  style: AppFonts.body(
                    text: timeText,
                    fontSize: 12,
                    color: theme.AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _toggleRecap(index),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.AppColors.accentPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: theme.AppColors.accentPurple.withOpacity(0.3),
                          width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 12, color: theme.AppColors.accentPurple),
                        const SizedBox(width: 6),
                        Text(
                          'Recap',
                          style: AppFonts.body(
                            text: 'Recap',
                            fontSize: 11,
                            color: theme.AppColors.accentPurple,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                      left: BorderSide(
                          color: theme.AppColors.accentPurple, width: 3)),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 30,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.AppColors.accentPurple),
                          ),
                        ),
                      )
                    : Text(
                        _summaries[index] ?? '',
                        style: AppFonts.body(
                          text: _summaries[index] ?? '',
                          fontSize: 14,
                          color: theme.AppColors.textSecondary,
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
