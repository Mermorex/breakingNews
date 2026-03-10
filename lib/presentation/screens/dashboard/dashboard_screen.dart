import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:news_app/core/utils/responsive.dart';
import 'package:news_app/data/grok_service.dart';
import 'package:news_app/data/models/rss_item_model.dart';
import 'package:url_launcher/url_launcher.dart';

// --- Constants (Moved to top level for easy access) ---
const Color cryptoDarkBg = Color(0xFF0B0E14);
const Color cryptoCardBg = Color(0xFF151A25);
const Color cryptoOrange = Color(0xFFFF8C00);
const Color cryptoGold = Color(0xFFFFD700);

class DashboardScreen extends StatefulWidget {
  final List<RssItemModel> worldNewsArticles;
  final List<RssItemModel> tunisianArticles;
  final List<RssItemModel> moroccanArticles;
  final List<RssItemModel> algerianArticles;
  final List<RssItemModel> iranianArticles;
  final VoidCallback onViewWorldNews;
  final VoidCallback onViewTunisia;
  final VoidCallback onViewMorocco;
  final VoidCallback onViewAlgeria;
  final VoidCallback onViewIran;
  final int totalArticles;
  final int tunisianCount;
  final int moroccanCount;
  final int algerianCount;
  final int iranianCount;
  final bool isLoading;

  const DashboardScreen({
    super.key,
    required this.worldNewsArticles,
    required this.tunisianArticles,
    required this.moroccanArticles,
    required this.algerianArticles,
    required this.iranianArticles,
    required this.onViewWorldNews,
    required this.onViewTunisia,
    required this.onViewMorocco,
    required this.onViewAlgeria,
    required this.onViewIran,
    required this.totalArticles,
    required this.tunisianCount,
    required this.moroccanCount,
    required this.algerianCount,
    required this.iranianCount,
    required this.isLoading,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  bool _isArabicContent = false;

  // OPTIMIZATION: Cache translations
  final Map<String, String> _translationCache = {};
  final Set<String> _loadingTranslations = {};

  AnimationController? _tickerController;
  double _textWidth = 0.0;
  String _currentTickerText = "";
  List<RssItemModel> _recentNews = [];

  @override
  void initState() {
    super.initState();
    _updateRecentNews();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.worldNewsArticles.length != widget.worldNewsArticles.length ||
        oldWidget.tunisianArticles.length != widget.tunisianArticles.length) {
      _updateRecentNews();
    }
  }

  // --- LOGIC ---

  void _updateRecentNews() {
    final allItems = [
      ...widget.worldNewsArticles,
      ...widget.tunisianArticles,
      ...widget.moroccanArticles,
      ...widget.algerianArticles,
      ...widget.iranianArticles,
    ];

    allItems.sort((a, b) {
      final dateA = a.publishedAt ?? DateTime(1970);
      final dateB = b.publishedAt ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });

    _recentNews = allItems.take(10).toList();
    _currentTickerText = _recentNews.map((e) => e.title).join('   •   ');
    _initTicker();

    if (_isArabicContent) {
      _translateTickerText();
    }
  }

  void _toggleLanguage() {
    _isArabicContent = !_isArabicContent;
    setState(() {});

    if (_isArabicContent) {
      _translateTickerText();
    } else {
      _currentTickerText = _recentNews.map((e) => e.title).join('   •   ');
      _initTicker();
    }
  }

  Future<void> _translateTickerText() async {
    if (_recentNews.isEmpty) return;
    final titles = _recentNews.map((e) => e.title).toList();
    List<String> translatedTitles = [];

    for (var title in titles) {
      translatedTitles.add(await _getTranslatedText(title));
    }

    if (_isArabicContent && mounted) {
      setState(() {
        _currentTickerText = translatedTitles.join('   •   ');
      });
      _initTicker();
    }
  }

  String _getDisplayTitle(RssItemModel article) {
    final original = article.title;
    if (!_isArabicContent) return original;

    if (_translationCache.containsKey(original)) {
      return _translationCache[original]!;
    }

    if (!_loadingTranslations.contains(original)) {
      _loadTranslation(original);
    }
    return original;
  }

  Future<void> _loadTranslation(String text) async {
    if (text.isEmpty) return;
    _loadingTranslations.add(text);

    try {
      final translated = await _translateText(text, toArabic: true);
      if (translated != text && mounted) {
        setState(() {
          _translationCache[text] = translated;
        });
      }
    } finally {
      _loadingTranslations.remove(text);
    }
  }

  Future<String> _getTranslatedText(String text) async {
    if (_translationCache.containsKey(text)) return _translationCache[text]!;
    return await _translateText(text, toArabic: true);
  }

  Future<String> _translateText(String text, {bool toArabic = true}) async {
    if (text.isEmpty) return text;
    if (_translationCache.containsKey(text)) return _translationCache[text]!;

    try {
      final sourceLang = toArabic ? 'en' : 'ar';
      final targetLang = toArabic ? 'ar' : 'en';

      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sourceLang&tl=$targetLang&dt=t&q=${Uri.encodeComponent(text)}',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data[0] != null && data[0] is List) {
          final translatedParts =
              (data[0] as List).map((e) => (e as List).first.toString()).join();
          _translationCache[text] = translatedParts;
          return translatedParts;
        }
      }
    } catch (e) {
      // Fail silently
    }
    return text;
  }

  // --- ANIMATION ---
  void _initTicker() {
    if (_currentTickerText.isEmpty) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: _currentTickerText,
        style: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
    )..layout();

    _textWidth = textPainter.width;
    final duration = Duration(milliseconds: ((_textWidth / 60) * 1000).round());

    _tickerController?.dispose();
    _tickerController = AnimationController(
      vsync: this,
      duration: duration,
    )..repeat();

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tickerController?.dispose();
    super.dispose();
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildAnimatedHeader()),
        SliverToBoxAdapter(child: _buildQuickStatsRow()),
        _buildSection(
          emoji: '🌍',
          title: 'World News',
          articles: widget.worldNewsArticles,
          onViewAll: widget.onViewWorldNews,
          fallbackSource: 'World News',
        ),
        _buildSection(
          emoji: '🇹🇳',
          title: 'Tunisia Feed',
          articles: widget.tunisianArticles,
          onViewAll: widget.onViewTunisia,
          fallbackSource: 'Tunisia',
        ),
        _buildSection(
          emoji: '🇲🇦',
          title: 'Morocco Feed',
          articles: widget.moroccanArticles,
          onViewAll: widget.onViewMorocco,
          fallbackSource: 'Morocco',
        ),
        _buildSection(
          emoji: '🇩🇿',
          title: 'Algeria Feed',
          articles: widget.algerianArticles,
          onViewAll: widget.onViewAlgeria,
          fallbackSource: 'Algeria',
        ),
        _buildSection(
          emoji: '🇮🇷',
          title: 'Iran Feed',
          articles: widget.iranianArticles,
          onViewAll: widget.onViewIran,
          fallbackSource: 'Iran',
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  Widget _buildAnimatedHeader() {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      margin: EdgeInsets.fromLTRB(isMobile ? 0 : 32, 24, isMobile ? 0 : 32, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [cryptoOrange, cryptoGold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24, 20, isMobile ? 16 : 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LIVE FEED',
                          style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.9),
                              letterSpacing: 2)),
                      const SizedBox(height: 4),
                      Text('${widget.totalArticles} Articles',
                          style: GoogleFonts.montserrat(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ],
                  ),
                ),
                _buildLangToggle(),
              ],
            ),
          ),
          Container(
            height: 50,
            width: double.infinity,
            color: Colors.black.withOpacity(0.15),
            child: _tickerController == null
                ? Center(
                    child: Text("Waiting for feed...",
                        style: GoogleFonts.montserrat(color: Colors.white54)))
                : _buildTickerWidget(),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildTickerWidget() {
    return ClipRect(
      child: OverflowBox(
        maxWidth: double.infinity,
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: _tickerController!,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(-_textWidth * _tickerController!.value, 0),
              child: child,
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTickerText(_currentTickerText),
              const SizedBox(width: 100),
              _buildTickerText(_currentTickerText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTickerText(String text) => Text(text,
      style: GoogleFonts.montserrat(
          fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
      maxLines: 1);

  Widget _buildQuickStatsRow() {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Container(
      margin:
          EdgeInsets.fromLTRB(isMobile ? 16 : 32, 16, isMobile ? 16 : 32, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildQuickStat('🇹🇳', widget.tunisianCount, widget.onViewTunisia),
            const SizedBox(width: 8),
            _buildQuickStat('🇲🇦', widget.moroccanCount, widget.onViewMorocco),
            const SizedBox(width: 8),
            _buildQuickStat('🇩🇿', widget.algerianCount, widget.onViewAlgeria),
            const SizedBox(width: 8),
            _buildQuickStat('🇮🇷', widget.iranianCount, widget.onViewIran),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(String emoji, int count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: cryptoCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cryptoOrange.withOpacity(0.2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(count.toString(),
              style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14)),
        ]),
      ),
    );
  }

  Widget _buildLangToggle() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleLanguage,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.translate, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(_isArabicContent ? 'AR' : 'EN',
                style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14)),
          ]),
        ),
      ),
    );
  }

  // --- SECTIONS ---

  Widget _buildSection({
    required String emoji,
    required String title,
    required List<RssItemModel> articles,
    required VoidCallback onViewAll,
    required String fallbackSource,
  }) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(isMobile ? 16 : 32, 16, isMobile ? 16 : 32, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [cryptoOrange, cryptoGold]),
                      borderRadius: BorderRadius.circular(16)),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        height: 2,
                        width: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [cryptoOrange, cryptoGold]),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                    ],
                  ),
                ),
                _buildViewAllButton(onViewAll),
              ],
            ),
            const SizedBox(height: 20),
            if (widget.isLoading && articles.isEmpty)
              _buildLoadingPlaceholder()
            else if (articles.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 700) {
                    return Column(
                      children: [
                        _buildMainArticleCard(articles.first, fallbackSource),
                        ...articles.skip(1).take(2).map((article) => Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: _buildSideArticleCard(
                                  article, fallbackSource),
                            )),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          flex: 5,
                          child: _buildMainArticleCard(
                              articles.first, fallbackSource)),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            if (articles.length > 1)
                              _buildSideArticleCard(
                                  articles[1], fallbackSource),
                            if (articles.length > 2) const SizedBox(height: 16),
                            if (articles.length > 2)
                              _buildSideArticleCard(
                                  articles[2], fallbackSource),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              )
            else if (widget.totalArticles == 0)
              _buildLoadingPlaceholder()
            else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildViewAllButton(VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
              color: cryptoOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cryptoOrange.withOpacity(0.3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('View All',
                style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cryptoOrange)),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_rounded, size: 14, color: cryptoOrange),
          ]),
        ),
      ),
    );
  }

  // --- UPDATED: Main Card Wrapper ---
  Widget _buildMainArticleCard(RssItemModel article, String fallbackSource) {
    return _ExpandableArticleCard(
      article: article,
      fallbackSource: fallbackSource,
      isArabic: _isArabicContent,
      getDisplayTitle: _getDisplayTitle,
      containsArabic: _containsArabic,
      getTextStyle: _getTextStyle,
    );
  }

  Widget _buildSideArticleCard(RssItemModel article, String fallbackSource) {
    final bool hasArabicContent = _containsArabic(article.title);
    final String displayTitle = _getDisplayTitle(article);
    final bool useArabicStyle = _isArabicContent || hasArabicContent;
    final isMobile = ResponsiveHelper.isMobile(context);

    final String displaySource = (article.source == null ||
            article.source!.isEmpty ||
            article.source == 'Unknown')
        ? fallbackSource
        : article.source!;

    return GestureDetector(
      onTap: () => _launchUrl(article.link),
      child: Container(
        height: isMobile ? 150 : 152,
        decoration: BoxDecoration(
            color: cryptoCardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cryptoGold.withOpacity(0.1))),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 20.0),
          child: Column(
            crossAxisAlignment: useArabicStyle
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(displaySource.toUpperCase(),
                  style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: cryptoGold)),
              const SizedBox(height: 8),
              Text(displayTitle,
                  style: _getTextStyle(
                      useArabicStyle,
                      TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.4)),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: useArabicStyle ? TextAlign.right : TextAlign.left),
              const Spacer(),
              Row(
                children: [
                  Text(_formatTimeAgo(article.publishedAt),
                      style: GoogleFonts.montserrat(
                          fontSize: 11, color: Colors.white38)),
                  const Spacer(),
                  Icon(Icons.arrow_right_alt,
                      size: 16, color: cryptoGold.withOpacity(0.5)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPERS ---
  TextStyle _getTextStyle(bool isArabic, TextStyle style) {
    return isArabic
        ? GoogleFonts.notoKufiArabic(textStyle: style)
        : GoogleFonts.montserrat(textStyle: style);
  }

  bool _containsArabic(String text) =>
      RegExp(r'[\u0600-\u06FF]').hasMatch(text);

  Widget _buildEmptyState() => Container(
      height: 200,
      decoration: BoxDecoration(
          color: cryptoCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cryptoOrange.withOpacity(0.1))),
      child: Center(
          child: Text('No articles found',
              style: GoogleFonts.montserrat(color: Colors.white38))));

  Widget _buildLoadingPlaceholder() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: cryptoCardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: cryptoOrange,
          strokeWidth: 2,
        ),
      ),
    );
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

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// --- NEW WIDGET: Expandable Article Card with AI Recap ---

class _ExpandableArticleCard extends StatefulWidget {
  final RssItemModel article;
  final String fallbackSource;
  final bool isArabic;
  final String Function(RssItemModel) getDisplayTitle;
  final bool Function(String) containsArabic;
  final TextStyle Function(bool, TextStyle) getTextStyle;

  const _ExpandableArticleCard({
    required this.article,
    required this.fallbackSource,
    required this.isArabic,
    required this.getDisplayTitle,
    required this.containsArabic,
    required this.getTextStyle,
  });

  @override
  State<_ExpandableArticleCard> createState() => _ExpandableArticleCardState();
}

class _ExpandableArticleCardState extends State<_ExpandableArticleCard>
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
    _iconTurn = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRecap() async {
    if (_isLoading) return;

    // If already expanded, collapse it
    if (_isExpanded) {
      setState(() {
        _isExpanded = false;
      });
      _controller.reverse();
      return;
    }

    // Expand and Fetch
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
            _summary = "Error generating summary.";
            _isLoading = false;
          });
        }
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasArabicContent = widget.containsArabic(widget.article.title);
    final String displayTitle = widget.getDisplayTitle(widget.article);
    final bool useArabicStyle = widget.isArabic || hasArabicContent;
    final isMobile = ResponsiveHelper.isMobile(context);

    final String displaySource = (widget.article.source == null ||
            widget.article.source!.isEmpty ||
            widget.article.source == 'Unknown')
        ? widget.fallbackSource
        : widget.article.source!;

    return GestureDetector(
      onTap: () => _launchUrl(widget.article.link),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _isExpanded ? (isMobile ? 380 : 420) : (isMobile ? 280 : 320),
        decoration: BoxDecoration(
            color: cryptoCardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cryptoOrange.withOpacity(0.2))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Left Gradient Line
              Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                      width: 5,
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                        cryptoOrange,
                        cryptoGold.withOpacity(0.5)
                      ])))),

              Padding(
                padding: EdgeInsets.all(isMobile ? 20.0 : 24.0),
                child: Column(
                  crossAxisAlignment: useArabicStyle
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      children: [
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: cryptoOrange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(displaySource.toUpperCase(),
                                style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: cryptoOrange))),
                        const Spacer(),
                        Icon(Icons.access_time_rounded,
                            size: 14, color: Colors.white54),
                        const SizedBox(width: 6),
                        Text(_formatTimeAgo(widget.article.publishedAt),
                            style: GoogleFonts.montserrat(
                                fontSize: 12, color: Colors.white54)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Text(displayTitle,
                        style: widget.getTextStyle(
                            useArabicStyle,
                            TextStyle(
                                fontSize: isMobile ? 18 : 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.4)),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        textAlign:
                            useArabicStyle ? TextAlign.right : TextAlign.left),

                    const Spacer(),

                    // --- Summary Section ---
                    if (_isExpanded)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          width: double.infinity,
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.05))),
                          child: _isLoading
                              ? Center(
                                  child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: cryptoGold)))
                              : Text(
                                  _summary ?? "Unable to generate summary.",
                                  style: widget.getTextStyle(
                                      useArabicStyle,
                                      TextStyle(
                                          fontSize: 13,
                                          color: cryptoGold.withOpacity(0.9),
                                          height: 1.5,
                                          fontStyle: FontStyle.italic)),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: useArabicStyle
                                      ? TextAlign.right
                                      : TextAlign.left,
                                ),
                        ),
                      ),

                    // Bottom Actions Row
                    Row(
                      children: [
                        // Original Snippet (hide if expanded)
                        if (!_isExpanded)
                          Expanded(
                            child: Text(_getSnippet(widget.article.description),
                                style: widget.getTextStyle(
                                    useArabicStyle,
                                    TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.6),
                                        height: 1.5)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: useArabicStyle
                                    ? TextAlign.right
                                    : TextAlign.left),
                          )
                        else
                          const Spacer(),

                        const SizedBox(width: 12),

                        // --- Recap Button ---
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _handleRecap,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: _isExpanded
                                          ? [
                                              Colors.deepPurpleAccent,
                                              Colors.purple
                                            ]
                                          : [cryptoGold, cryptoOrange]),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                        color: (_isExpanded
                                                ? Colors.purple
                                                : cryptoOrange)
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: Offset(0, 2))
                                  ]),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RotationTransition(
                                    turns: _iconTurn,
                                    child: Icon(Icons.auto_awesome,
                                        size: 16, color: Colors.white),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isExpanded ? 'Close' : 'AI Recap',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helpers
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

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
