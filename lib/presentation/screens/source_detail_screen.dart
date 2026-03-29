// lib/presentation/screens/source_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../data/datasources/rss_remote_datasource.dart';
import '../../data/grok_service.dart';
import '../../data/models/rss_item_model.dart';
import '../../data/models/news_source.dart';

// --- UNIFIED COLOR PALETTE (Matching Dashboard) ---
class AppColors {
  static const Color bgDark = Color(0xFF0B0E14);
  static const Color cardBg = Color(0xFF151A25);
  static const Color cardBgElevated = Color(0xFF1E2532);
  static const Color accentOrange = Color(0xFFFF8C00);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0AEC0);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderSubtle = Color(0xFF2D3748);
}

// --- AI RECAP WIDGET (Reusable) ---
class FullAiRecap extends StatelessWidget {
  final String summary;
  final bool isArabic;
  final bool isLoading;
  final VoidCallback onClose;

  const FullAiRecap({
    super.key,
    required this.summary,
    required this.isArabic,
    required this.isLoading,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accentPurple.withOpacity(0.2),
              AppColors.accentEmerald.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accentPurple.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.accentPurple),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isArabic ? 'جاري التلخيص...' : 'Generating summary...',
                style: GoogleFonts.notoKufiArabic(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentPurple.withOpacity(0.15),
            AppColors.cardBgElevated.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentPurple.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentPurple.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.accentPurple.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: AppColors.accentPurple,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isArabic ? 'ملخص ذكي' : 'AI Recap',
                          style: GoogleFonts.notoKufiArabic(
                            fontSize: 11,
                            color: AppColors.accentPurple,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text(
                  summary,
                  style: GoogleFonts.notoKufiArabic(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    height: 1.7,
                    letterSpacing: 0.2,
                  ),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- ENHANCED ARTICLE CARD WITH AI RECAP ---
class _ArticleCard extends StatefulWidget {
  final RssItemModel article;
  final bool itemIsArabic;
  final String currentLangMode;
  final Future<String> Function(String) getTranslatedTitle;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ArticleCard({
    required this.article,
    required this.itemIsArabic,
    required this.currentLangMode,
    required this.getTranslatedTitle,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<_ArticleCard>
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
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _iconTurn = Tween<double>(begin: 0.0, end: 0.5)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRecap() async {
    if (_isLoading) return;

    if (_isExpanded) {
      _controller.reverse();
      await Future.delayed(const Duration(milliseconds: 150));
      setState(() => _isExpanded = false);
      return;
    }

    setState(() {
      _isExpanded = true;
      _isLoading = true;
    });
    _controller.forward();

    if (_summary == null) {
      try {
        // AI Interacts based on selected language. Default is Arabic.
        final bool generateInArabic = widget.currentLangMode != 'english';

        final result = await MistralService().summarizeArticle(
          widget.article.title,
          widget.article.description ?? '',
          isArabic: generateInArabic,
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
            _summary = "Unable to generate summary. Please try again.";
            _isLoading = false;
          });
        }
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _closeRecap() {
    _controller.reverse();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _isExpanded = false);
    });
  }

  String _cleanText(String? text) {
    if (text == null || text.isEmpty) return '';
    return text
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return 'Just now';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hasImage =
        widget.article.imageUrl != null && widget.article.imageUrl!.isNotEmpty;

    // Determine font style based on language mode or content
    bool useArabicFont =
        widget.currentLangMode == 'arabic' || widget.itemIsArabic;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isExpanded
              ? AppColors.accentPurple.withOpacity(0.5)
              : AppColors.borderSubtle,
          width: _isExpanded ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _isExpanded
                ? AppColors.accentPurple.withOpacity(0.2)
                : Colors.black.withOpacity(0.3),
            blurRadius: _isExpanded ? 24 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isExpanded
                            ? [
                                AppColors.accentPurple,
                                AppColors.accentPurple.withOpacity(0.3)
                              ]
                            : [
                                AppColors.accentOrange,
                                AppColors.accentOrange.withOpacity(0.3)
                              ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    onLongPress: widget.onLongPress,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: AppColors.accentOrange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.accentOrange.withOpacity(0.25),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.article.publishedAt?.day.toString() ??
                                      '--',
                                  style: GoogleFonts.montserrat(
                                    color: AppColors.accentOrange,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  _getMonth(widget.article.publishedAt?.month),
                                  style: GoogleFonts.montserrat(
                                    color: AppColors.accentOrange,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 9,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: useArabicFont
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                FutureBuilder<String>(
                                  future: widget.currentLangMode == 'source'
                                      ? Future.value(widget.article.title)
                                      : widget.getTranslatedTitle(
                                          widget.article.title),
                                  builder: (context, snapshot) {
                                    final title =
                                        snapshot.data ?? widget.article.title;
                                    return Text(
                                      title,
                                      style: (useArabicFont
                                              ? GoogleFonts.notoKufiArabic()
                                              : GoogleFonts.montserrat())
                                          .copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                        height: 1.3,
                                      ),
                                      textAlign: useArabicFont
                                          ? TextAlign.right
                                          : TextAlign.left,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                if (widget.article.description != null &&
                                    widget.article.description!.isNotEmpty)
                                  Text(
                                    _cleanText(widget.article.description),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: (useArabicFont
                                            ? GoogleFonts.notoKufiArabic()
                                            : GoogleFonts.montserrat())
                                        .copyWith(
                                      fontSize: 12,
                                      color: AppColors.textSecondary
                                          .withOpacity(0.8),
                                      height: 1.4,
                                    ),
                                    textAlign: useArabicFont
                                        ? TextAlign.right
                                        : TextAlign.left,
                                  ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded,
                                        size: 12, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatTimeAgo(
                                          widget.article.publishedAt),
                                      style: GoogleFonts.montserrat(
                                          color: AppColors.textMuted,
                                          fontSize: 11),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentOrange
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.open_in_new,
                                              size: 12,
                                              color: AppColors.accentOrange
                                                  .withOpacity(0.8)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Read',
                                            style: GoogleFonts.montserrat(
                                                fontSize: 10,
                                                color: AppColors.accentOrange,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (hasImage) ...[
                            const SizedBox(width: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                widget.article.imageUrl!,
                                width: 95,
                                height: 95,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  AppColors.borderSubtle,
                  Colors.transparent
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  if (!_isExpanded)
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.touch_app,
                              size: 12,
                              color: AppColors.textMuted.withOpacity(0.5)),
                          const SizedBox(width: 4),
                          Text(
                            'Long press to copy link',
                            style: GoogleFonts.montserrat(
                                fontSize: 10,
                                color: AppColors.textMuted.withOpacity(0.5)),
                          ),
                        ],
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _handleRecap,
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isExpanded
                                ? [
                                    AppColors.accentPurple,
                                    AppColors.accentPurple.withOpacity(0.8)
                                  ]
                                : [
                                    AppColors.accentGold.withOpacity(0.9),
                                    AppColors.accentOrange
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: (_isExpanded
                                      ? AppColors.accentPurple
                                      : AppColors.accentOrange)
                                  .withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RotationTransition(
                              turns: _iconTurn,
                              child: const Icon(Icons.auto_awesome,
                                  size: 15, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isExpanded ? 'Close Recap' : 'AI Recap',
                              style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuart,
              child: _isExpanded
                  ? Container(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        height: 200,
                        child: FullAiRecap(
                          summary: _summary ?? "Unable to generate summary.",
                          isArabic: widget.currentLangMode !=
                              'english', // AI reacts to selected language
                          isLoading: _isLoading,
                          onClose: _closeRecap,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonth(int? month) {
    if (month == null) return '';
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    return months[month - 1];
  }
}

// --- MAIN SCREEN ---
class SourceDetailScreen extends StatefulWidget {
  final String sourceName;
  final String sourceUrl;
  final SourceType sourceType;
  final Map<String, String>? selectors;

  const SourceDetailScreen({
    super.key,
    required this.sourceName,
    required this.sourceUrl,
    this.sourceType = SourceType.rss,
    this.selectors,
  });

  @override
  State<SourceDetailScreen> createState() => _SourceDetailScreenState();
}

class _SourceDetailScreenState extends State<SourceDetailScreen> {
  final RssRemoteDataSource _dataSource = RssRemoteDataSource();
  late Future<List<RssItemModel>> _feedFuture;
  int _articleCount = 0;

  // --- LANGUAGE STATE ---
  String _currentLangMode = 'arabic'; // Default Arabic
  final Map<String, String> _translationCache = {};

  @override
  void initState() {
    super.initState();
    _feedFuture = _fetchData();
  }

  Future<List<RssItemModel>> _fetchData() async {
    List<RssItemModel> items;
    if (widget.sourceType == SourceType.scrapable && widget.selectors != null) {
      items = await _dataSource.scrapeWebsite(
        widget.sourceUrl.trim(),
        widget.selectors!,
        sourceName: widget.sourceName,
        limit: 50,
      );
    } else {
      items = await _dataSource.fetchRssFeed(
        widget.sourceUrl.trim(),
        sourceName: widget.sourceName,
        limit: 50,
      );
    }
    if (mounted) {
      setState(() => _articleCount = items.length);
    }
    return items;
  }

  Future<void> _reload() async {
    setState(() {
      _feedFuture = _fetchData();
    });
  }

  void _toggleLanguage() {
    setState(() {
      if (_currentLangMode == 'arabic') {
        _currentLangMode = 'english';
      } else if (_currentLangMode == 'english') {
        _currentLangMode = 'source';
      } else {
        _currentLangMode = 'arabic';
      }
    });
  }

  // --- TRANSLATION LOGIC ---
  Future<String> _getTranslatedText(String text) async {
    if (text.isEmpty) return text;
    final cacheKey = '$text-$_currentLangMode';
    if (_translationCache.containsKey(cacheKey))
      return _translationCache[cacheKey]!;

    bool toArabic = _currentLangMode == 'arabic';
    bool isSourceArabic = _containsArabic(text);

    if ((toArabic && isSourceArabic) ||
        (!toArabic && !isSourceArabic && _currentLangMode == 'english')) {
      return text;
    }

    try {
      final targetLang = toArabic ? 'ar' : 'en';
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$targetLang&dt=t&q=${Uri.encodeComponent(text)}',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data[0] != null && data[0] is List) {
          final translatedParts =
              (data[0] as List).map((e) => (e as List).first.toString()).join();
          _translationCache[cacheKey] = translatedParts;
          return translatedParts;
        }
      }
    } catch (e) {
      debugPrint("Translation error: $e");
    }
    return text;
  }

  Future<void> _openArticle(String url) async {
    if (url.isEmpty) return;
    String cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http')) cleanUrl = 'https://$cleanUrl';
    final uri = Uri.parse(cleanUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showError('Cannot open link');
    }
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Link copied to clipboard',
                style: GoogleFonts.montserrat(fontSize: 13)),
          ],
        ),
        backgroundColor: AppColors.accentEmerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.montserrat()),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  bool _containsArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _containsArabic(widget.sourceName);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: _buildEnhancedAppBar(isArabic),
        body: FutureBuilder<List<RssItemModel>>(
          future: _feedFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }
            if (snapshot.hasError) {
              return _buildErrorState();
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return _buildEmptyState();
            }

            return RefreshIndicator(
              onRefresh: _reload,
              color: AppColors.accentOrange,
              backgroundColor: AppColors.cardBg,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final itemIsArabic = _containsArabic(item.title);

                  return _ArticleCard(
                    article: item,
                    itemIsArabic: itemIsArabic,
                    currentLangMode: _currentLangMode,
                    getTranslatedTitle: _getTranslatedText,
                    onTap: () => _openArticle(item.link),
                    onLongPress: () => _copyLink(item.link),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildEnhancedAppBar(bool isArabic) {
    String displayText;
    IconData iconData;
    switch (_currentLangMode) {
      case 'arabic':
        displayText = 'AR';
        iconData = Icons.translate;
        break;
      case 'english':
        displayText = 'EN';
        iconData = Icons.translate;
        break;
      default:
        displayText = 'SRC';
        iconData = Icons.language;
    }

    return AppBar(
      backgroundColor: AppColors.bgDark,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      toolbarHeight: 70,
      leadingWidth: 70,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderSubtle, width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: const Center(
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textPrimary, size: 18),
              ),
            ),
          ),
        ),
      ),
      title: Column(
        children: [
          Text(
            widget.sourceName,
            style: (isArabic
                    ? GoogleFonts.notoKufiArabic()
                    : GoogleFonts.montserrat())
                .copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _articleCount > 0 ? '$_articleCount articles' : 'Loading...',
            style: GoogleFonts.montserrat(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        // Replaced Refresh Button with Language Toggle
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleLanguage,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.accentOrange.withOpacity(0.3), width: 1),
                ),
                child: Center(
                  child: Row(
                    children: [
                      Icon(iconData, color: AppColors.accentOrange, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        displayText,
                        style: GoogleFonts.montserrat(
                          color: AppColors.accentOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: AppColors.bgDark,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.accentOrange),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _currentLangMode == 'arabic'
                  ? 'جاري تحميل الأخبار...'
                  : 'Loading articles...',
              style: GoogleFonts.notoKufiArabic(
                  color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    bool isAr = _currentLangMode == 'arabic';
    return Container(
      color: AppColors.bgDark,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Icon(Icons.error_outline_rounded,
                      size: 32, color: Colors.red.shade400),
                ),
                const SizedBox(height: 20),
                Text(
                  isAr ? 'فشل تحميل الخلاصة' : 'Failed to load feed',
                  style: GoogleFonts.notoKufiArabic(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isAr
                      ? 'يرجى التحقق من الاتصال والمحاولة مرة أخرى.'
                      : 'Please check your connection and try again.',
                  style: GoogleFonts.notoKufiArabic(
                      color: AppColors.textMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _reload,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          AppColors.accentOrange,
                          AppColors.accentGold
                        ]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.accentOrange.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.refresh,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(isAr ? 'إعادة المحاولة' : 'Retry',
                              style: GoogleFonts.notoKufiArabic(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    bool isAr = _currentLangMode == 'arabic';
    return Container(
      color: AppColors.bgDark,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: AppColors.textMuted.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24)),
              child: Icon(Icons.rss_feed_outlined,
                  size: 40, color: AppColors.textMuted.withOpacity(0.5)),
            ),
            const SizedBox(height: 20),
            Text(
              isAr ? 'لا توجد مقالات' : 'No articles found',
              style: GoogleFonts.notoKufiArabic(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              isAr
                  ? 'قد لا يحتوي هذا المصدر على أي مقالات في الوقت الحالي.'
                  : 'This source may not have any articles at the moment.',
              style: GoogleFonts.notoKufiArabic(
                  color: AppColors.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
