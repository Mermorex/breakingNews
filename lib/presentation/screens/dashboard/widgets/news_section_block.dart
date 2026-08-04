import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:news_app/data/grok_service.dart';
import 'package:news_app/data/models/rss_item_model.dart';
import '../constants/app_colors.dart';
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
            child: CircularProgressIndicator(color: AppColors.accentOrange)),
      );
    }

    if (widget.articles.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: widget.accentColor.withOpacity(0.5), width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- JOURNAL HEADER ---
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 20),
            child: Row(
              children: [
                Text(widget.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Text(
                  widget.title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: widget.accentColor,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onViewAll,
                  child: Text(
                    'VIEW ALL',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- LEAD STORY (Full Width) ---
          _buildLeadArticle(0, isArabicSection),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(
                color: AppColors.borderSubtle,
                thickness: 1,
                indent: 10,
                endIndent: 10),
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
                      color: AppColors.borderSubtle.withOpacity(0.5),
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

    return GestureDetector(
      onTap: () => widget.onLaunchUrl(article.link),
      child: Column(
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            widget.getDisplayTitle(article),
            style: AppFonts.title(
              text: widget.getDisplayTitle(article),
              fontSize: 22,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment:
                isArabic ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              Text(
                widget.getDisplaySource(article),
                style: AppFonts.caption(
                  text: widget.getDisplaySource(article),
                  fontSize: 11,
                  color: widget.accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatTimeAgo(article.publishedAt),
                style: AppFonts.caption(
                  text: _formatTimeAgo(article.publishedAt),
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 12),

              // --- BIGGER AI RECAP BUTTON ---
              GestureDetector(
                onTap: () => _toggleRecap(index),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentPurple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.accentPurple.withOpacity(0.4),
                        width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 16, color: AppColors.accentPurple),
                      const SizedBox(width: 6),
                      Text(
                        'AI RECAP',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentPurple,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // --- BIGGER INLINE RECAP EXPANSION ---
          if (isExpanded) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20), // Increased padding
              decoration: BoxDecoration(
                color: AppColors.cardBgElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border(
                    left: BorderSide(
                        color: AppColors.accentPurple,
                        width: 4)), // Thicker border
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
                                  color: AppColors.accentPurple))))
                  : Text(
                      _summaries[index] ?? '',
                      style: AppFonts.body(
                        text: _summaries[index] ?? '',
                        fontSize: 15, // Bigger text
                        color: AppColors.textSecondary,
                        height: 1.7, // More line spacing
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    ),
            ),
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

    return GestureDetector(
      onTap: () => widget.onLaunchUrl(article.link),
      child: Container(
        padding: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                      color: AppColors.borderSubtle.withOpacity(0.3),
                      width: 1)),
        ),
        child: Column(
          crossAxisAlignment:
              isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              widget.getDisplayTitle(article),
              style: AppFonts.body(
                text: widget.getDisplayTitle(article),
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment:
                  isArabic ? MainAxisAlignment.start : MainAxisAlignment.end,
              children: [
                Text(
                  widget.getDisplaySource(article),
                  style: AppFonts.caption(
                    text: widget.getDisplaySource(article),
                    fontSize: 9,
                    color: widget.accentColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTimeAgo(article.publishedAt),
                  style: AppFonts.caption(
                    text: _formatTimeAgo(article.publishedAt),
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),

                // --- BIGGER AI RECAP BUTTON FOR COLUMNS ---
                GestureDetector(
                  onTap: () => _toggleRecap(index),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: AppColors.accentPurple.withOpacity(0.3),
                          width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 12, color: AppColors.accentPurple),
                        const SizedBox(width: 4),
                        Text(
                          'RECAP',
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentPurple,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // --- BIGGER INLINE RECAP EXPANSION FOR COLUMNS ---
            if (isExpanded) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16), // Increased padding
                decoration: BoxDecoration(
                  color: AppColors.cardBgElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                      left: BorderSide(
                          color: AppColors.accentPurple,
                          width: 3)), // Thicker border
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
                                    color: AppColors.accentPurple))))
                    : Text(
                        _summaries[index] ?? '',
                        style: AppFonts.body(
                          text: _summaries[index] ?? '',
                          fontSize: 13, // Bigger text
                          color: AppColors.textSecondary,
                          height: 1.6, // More line spacing
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
