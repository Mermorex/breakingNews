import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:news_app/data/grok_service.dart';
import 'package:news_app/data/models/rss_item_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_fonts.dart';

class ExpandableCompactCard extends StatefulWidget {
  final RssItemModel article;
  final Color accentColor;
  final bool isArabic;
  final bool isSummaryArabic;
  final String Function(RssItemModel) getDisplayTitle;
  final String Function(RssItemModel) getDisplaySource;
  final Future<void> Function(String) onLaunchUrl;

  const ExpandableCompactCard({
    super.key,
    required this.article,
    required this.accentColor,
    required this.isArabic,
    required this.isSummaryArabic,
    required this.getDisplayTitle,
    required this.getDisplaySource,
    required this.onLaunchUrl,
  });

  @override
  State<ExpandableCompactCard> createState() => _ExpandableCompactCardState();
}

class _ExpandableCompactCardState extends State<ExpandableCompactCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isLoading = false;
  String? _summary;
  late AnimationController _controller;
  late Animation<double> _iconTurn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _iconTurn = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRecap() async {
    if (_isLoading) return;
    if (_isExpanded) {
      setState(() => _isExpanded = false);
      _controller.reverse();
      return;
    }
    setState(() {
      _isExpanded = true;
      _isLoading = true;
    });
    _controller.forward();

    if (_summary == null) {
      try {
        final result = await MistralService().summarizeArticle(
          widget.article.title,
          widget.article.description ?? '',
          isArabic: widget.isSummaryArabic,
        );
        if (mounted) {
          setState(() {
            _summary = result;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _summary = "Unable to generate summary.";
            _isLoading = false;
          });
        }
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return 'Just now';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return intl.DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final String displayTitle = widget.getDisplayTitle(widget.article);
    final String displaySource = widget.getDisplaySource(widget.article);
    final bool useArabicStyle = widget.isArabic;

    return GestureDetector(
      onTap: () => widget.onLaunchUrl(widget.article.link),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isExpanded
                ? widget.accentColor.withOpacity(0.4)
                : AppColors.borderSubtle,
            width: _isExpanded ? 1.5 : 1,
          ),
          boxShadow: _isExpanded
              ? [
                  BoxShadow(
                    color: AppColors.accentPurple.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: useArabicStyle
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Meta row ---
            Row(
              children: [
                if (useArabicStyle) const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    displaySource,
                    style: AppFonts.caption(
                      text: displaySource,
                      fontSize: 9,
                      color: widget.accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTimeAgo(widget.article.publishedAt),
                  style: AppFonts.caption(
                    text: _formatTimeAgo(widget.article.publishedAt),
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                // --- Full Recap button matching featured card ---
                GestureDetector(
                  onTap: _handleRecap,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.accentPurple.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 11, color: AppColors.accentPurple),
                        const SizedBox(width: 3),
                        Text(
                          'Recap',
                          style: AppFonts.caption(
                            text: 'Recap',
                            fontSize: 8,
                            color: AppColors.accentPurple,
                          ),
                        ),
                        RotationTransition(
                          turns: _iconTurn,
                          child: Icon(Icons.expand_more,
                              size: 12, color: AppColors.accentPurple),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // --- Title ---
            Text(
              displayTitle,
              style: AppFonts.body(
                text: displayTitle,
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: _isExpanded ? 4 : 2,
              overflow: TextOverflow.ellipsis,
              textAlign: useArabicStyle ? TextAlign.right : TextAlign.left,
            ),

            // --- Expanded AI Recap ---
            if (_isExpanded) ...[
              const SizedBox(height: 12),
              if (_isLoading)
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.accentPurple.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.accentPurple.withOpacity(0.15),
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentPurple,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.isSummaryArabic
                              ? 'جاري التلخيص...'
                              : 'Summarizing...',
                          style: AppFonts.body(
                            text: widget.isSummaryArabic
                                ? 'جاري التلخيص...'
                                : 'Summarizing...',
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_summary != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentPurple.withOpacity(0.1),
                        AppColors.cardBgElevated.withOpacity(0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.accentPurple.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: useArabicStyle
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      // --- Recap header ---
                      Row(
                        children: [
                          if (useArabicStyle) const Spacer(),
                          Icon(Icons.auto_awesome,
                              size: 11, color: AppColors.accentPurple),
                          const SizedBox(width: 4),
                          Text(
                            widget.isSummaryArabic ? 'ملخص ذكي' : 'AI Recap',
                            style: AppFonts.caption(
                              text: widget.isSummaryArabic
                                  ? 'ملخص ذكي'
                                  : 'AI Recap',
                              fontSize: 9,
                              color: AppColors.accentPurple,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // --- Summary text ---
                      Text(
                        _summary!,
                        style: AppFonts.body(
                          text: _summary!,
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ).copyWith(height: 1.6),
                        textAlign:
                            useArabicStyle ? TextAlign.right : TextAlign.left,
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
