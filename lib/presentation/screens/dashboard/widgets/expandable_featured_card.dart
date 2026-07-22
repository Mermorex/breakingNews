import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:news_app/core/utils/responsive.dart';
import 'package:news_app/data/grok_service.dart';
import 'package:news_app/data/models/rss_item_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_fonts.dart';
import '../utils/source_extractor.dart';
import 'full_ai_recap.dart';

class ExpandableFeaturedCard extends StatefulWidget {
  final RssItemModel article;
  final Color accentColor;
  final bool isArabic;
  final bool isSummaryArabic;
  final String Function(RssItemModel) getDisplayTitle;
  final String Function(RssItemModel) getDisplaySource;
  final Future<void> Function(String) onLaunchUrl;

  const ExpandableFeaturedCard({
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
  State<ExpandableFeaturedCard> createState() => _ExpandableFeaturedCardState();
}

class _ExpandableFeaturedCardState extends State<ExpandableFeaturedCard>
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

  String _getSnippet(String? description) {
    if (description == null || description.isEmpty) return '';
    return description
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final String displayTitle = widget.getDisplayTitle(widget.article);
    final String displaySource = widget.getDisplaySource(widget.article);
    final bool useArabicStyle = widget.isArabic;
    final snippet = _getSnippet(widget.article.description);

    return GestureDetector(
      onTap: () => widget.onLaunchUrl(widget.article.link),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
        height: _isExpanded ? (isMobile ? 480 : 500) : (isMobile ? 260 : 280),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isExpanded
                ? widget.accentColor.withOpacity(0.5)
                : AppColors.borderSubtle,
            width: _isExpanded ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _isExpanded
                  ? widget.accentColor.withOpacity(0.15)
                  : Colors.black.withOpacity(0.2),
              blurRadius: _isExpanded ? 20 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Left accent bar
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.accentColor,
                        widget.accentColor.withOpacity(0.3),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    isMobile ? 20 : 24, 20, isMobile ? 16 : 20, 16),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            displaySource,
                            style: AppFonts.caption(
                              text: displaySource,
                              fontSize: 10,
                              color: widget.accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimeAgo(widget.article.publishedAt),
                          style: AppFonts.caption(
                            text: _formatTimeAgo(widget.article.publishedAt),
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const Spacer(),
                        // AI Recap button
                        GestureDetector(
                          onTap: _handleRecap,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.accentPurple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.accentPurple.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome,
                                    size: 12, color: AppColors.accentPurple),
                                const SizedBox(width: 4),
                                Text(
                                  'Recap',
                                  style: AppFonts.caption(
                                    text: 'Recap',
                                    fontSize: 9,
                                    color: AppColors.accentPurple,
                                  ),
                                ),
                                RotationTransition(
                                  turns: _iconTurn,
                                  child: Icon(Icons.expand_more,
                                      size: 14, color: AppColors.accentPurple),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // --- Title ---
                    Text(
                      displayTitle,
                      style: AppFonts.title(
                        text: displayTitle,
                        fontSize: isMobile ? 15 : 17,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: _isExpanded ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign:
                          useArabicStyle ? TextAlign.right : TextAlign.left,
                    ),

                    // --- Snippet ---
                    if (!_isExpanded && snippet.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        snippet,
                        style: AppFonts.body(
                          text: snippet,
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign:
                            useArabicStyle ? TextAlign.right : TextAlign.left,
                      ),
                    ],

                    // --- Expanded: AI Recap ---
                    if (_isExpanded) ...[
                      const SizedBox(height: 14),
                      FullAiRecap(
                        summary: _summary ?? '',
                        isArabic: widget.isSummaryArabic,
                        isLoading: _isLoading,
                        onClose: () {
                          setState(() => _isExpanded = false);
                          _controller.reverse();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
