import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:news_app/core/utils/responsive.dart';
import 'package:news_app/core/constants/dashboard_constants.dart'; // IMPORTED CONSTANTS
import 'package:news_app/data/grok_service.dart';
import 'package:news_app/data/models/rss_item_model.dart';
import 'package:url_launcher/url_launcher.dart';

// --- Constants ---
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

  // Source map generated from constants
  late final Map<String, String> _urlSourceMap;

  @override
  void initState() {
    super.initState();
    _initializeSourceMap(); // Generate map from constants
    _updateRecentNews();
  }

  // --- INITIALIZATION FROM CONSTANTS ---
  void _initializeSourceMap() {
    _urlSourceMap = {};

    // Aggregate all featured lists from DashboardConstants
    final List<List<Map<String, String>>> allFeaturedLists = [
      DashboardConstants.tunisianFeatured,
      DashboardConstants.moroccanFeatured,
      DashboardConstants.algerianFeatured,
      DashboardConstants.iranianFeatured,
      DashboardConstants.internationalFeatured,
    ];

    for (final list in allFeaturedLists) {
      for (final item in list) {
        final name = item['name'];
        final url = item['url'];

        if (name == null || url == null) continue;

        // 1. Generate keys from Name (e.g., "BBC" -> "bbc")
        final nameKey = name.toLowerCase().replaceAll(' ', '');
        _urlSourceMap[nameKey] = name;

        // 2. Generate keys from URL domain
        try {
          final uri = Uri.parse(url);
          String host = uri.host; // e.g., "www.bbc.co.uk"

          // Remove 'www.'
          if (host.startsWith('www.')) {
            host = host.substring(4);
          }

          // Add full host (e.g., "bbc.co.uk")
          _urlSourceMap[host] = name;

          // Add domain name part (e.g., "bbc" from "bbc.co.uk" or "mosaiquefm" from "mosaiquefm.net")
          final domainParts = host.split('.');
          if (domainParts.isNotEmpty) {
            final mainPart = domainParts.first;
            // Avoid adding generic parts like 'com', 'net', but add specific names
            if (mainPart.length > 2) {
              _urlSourceMap[mainPart] = name;
            }
          }
        } catch (e) {
          // Ignore parse errors
        }
      }
    }
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

  // --- SOURCE EXTRACTION HELPER ---
  String _getDisplaySource(RssItemModel article) {
    // First try article.source if it's set and not generic
    if (article.source != null &&
        article.source!.isNotEmpty &&
        article.source != 'Unknown' &&
        !_isGenericSourceName(article.source!)) {
      return _cleanSourceName(article.source!);
    }

    // Try to extract from article link URL using our generated map
    if (article.link.isNotEmpty) {
      final urlSource = _extractSourceFromUrl(article.link);
      if (urlSource != null) return urlSource;
    }

    return 'Unknown';
  }

  bool _isGenericSourceName(String name) {
    final genericNames = [
      'world news',
      'tunisia feed',
      'morocco feed',
      'algeria feed',
      'iran feed',
      'news',
      'feed',
      'articles',
      'unknown'
    ];
    return genericNames.any((generic) => name.toLowerCase().contains(generic));
  }

  String _cleanSourceName(String name) {
    // Clean up common RSS feed suffixes
    final cleanName = name
        .replaceAll(RegExp(r'\s*-\s*.*$'), '') // Remove " - World News" etc
        .replaceAll(RegExp(r'\s*\|.*$'), '') // Remove " | Breaking News" etc
        .replaceAll(RegExp(r'\s*RSS.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*Feed.*$', caseSensitive: false), '')
        .trim();

    // Specific mappings (Can be expanded or moved to constants if needed)
    final Map<String, String> mappings = {
      'BBC News': 'BBC',
      'Reuters.com': 'Reuters',
      'Reuters Agency': 'Reuters',
      'Al Jazeera English': 'Al Jazeera',
      'CNN.com': 'CNN',
      'The New York Times': 'NYT',
      'NYTimes.com': 'NYT',
      'The Guardian': 'Guardian',
    };

    for (final entry in mappings.entries) {
      if (cleanName.contains(entry.key)) return entry.value;
    }

    return cleanName;
  }

  String? _extractSourceFromUrl(String url) {
    final lowerUrl = url.toLowerCase();

    // Check against keys generated from DashboardConstants
    for (final entry in _urlSourceMap.entries) {
      // Exact match or contained match for domain/key
      if (lowerUrl.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return null;
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
        ),
        _buildSection(
          emoji: '🇹🇳',
          title: 'Tunisia Feed',
          articles: widget.tunisianArticles,
          onViewAll: widget.onViewTunisia,
        ),
        _buildSection(
          emoji: '🇲🇦',
          title: 'Morocco Feed',
          articles: widget.moroccanArticles,
          onViewAll: widget.onViewMorocco,
        ),
        _buildSection(
          emoji: '🇩🇿',
          title: 'Algeria Feed',
          articles: widget.algerianArticles,
          onViewAll: widget.onViewAlgeria,
        ),
        _buildSection(
          emoji: '🇮🇷',
          title: 'Iran Feed',
          articles: widget.iranianArticles,
          onViewAll: widget.onViewIran,
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
                        _buildMainArticleCard(articles.first),
                        ...articles.skip(1).take(2).map((article) => Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: _buildSideArticleCard(article),
                            )),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          flex: 5,
                          child: _buildMainArticleCard(articles.first)),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            if (articles.length > 1)
                              _buildSideArticleCard(articles[1]),
                            if (articles.length > 2) const SizedBox(height: 16),
                            if (articles.length > 2)
                              _buildSideArticleCard(articles[2]),
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
  Widget _buildMainArticleCard(RssItemModel article) {
    return _ExpandableArticleCard(
      article: article,
      isArabic: _isArabicContent,
      getDisplayTitle: _getDisplayTitle,
      containsArabic: _containsArabic,
      getTextStyle: _getTextStyle,
      getDisplaySource: _getDisplaySource, // NEW: Pass source extractor
    );
  }

  // --- UPDATED: Side Card Wrapper ---
  Widget _buildSideArticleCard(RssItemModel article) {
    return _ExpandableSideArticleCard(
      article: article,
      isArabic: _isArabicContent,
      getDisplayTitle: _getDisplayTitle,
      containsArabic: _containsArabic,
      getTextStyle: _getTextStyle,
      getDisplaySource: _getDisplaySource, // NEW: Pass source extractor
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
}

// --- WIDGET 1: Main Article Card ---

class _ExpandableArticleCard extends StatefulWidget {
  final RssItemModel article;
  final bool isArabic;
  final String Function(RssItemModel) getDisplayTitle;
  final bool Function(String) containsArabic;
  final TextStyle Function(bool, TextStyle) getTextStyle;
  final String Function(RssItemModel) getDisplaySource; // NEW

  const _ExpandableArticleCard({
    required this.article,
    required this.isArabic,
    required this.getDisplayTitle,
    required this.containsArabic,
    required this.getTextStyle,
    required this.getDisplaySource, // NEW
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
          isArabic: widget.isArabic,
        );
        if (mounted)
          setState(() {
            _summary = result;
            _isLoading = false;
          });
      } catch (e) {
        if (mounted)
          setState(() {
            _summary = "Error generating summary.";
            _isLoading = false;
          });
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasArabicContent = widget.containsArabic(widget.article.title);
    final String displayTitle = widget.getDisplayTitle(widget.article);
    final bool useArabicStyle = widget.isArabic || hasArabicContent;
    final isMobile = ResponsiveHelper.isMobile(context);

    // USE THE SOURCE EXTRACTOR
    final String displaySource = widget.getDisplaySource(widget.article);

    return GestureDetector(
      onTap: () => _launchUrl(widget.article.link),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _isExpanded ? (isMobile ? 420 : 460) : (isMobile ? 280 : 320),
        decoration: BoxDecoration(
            color: cryptoCardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cryptoOrange.withOpacity(0.2))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Row
                    Row(children: [
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
                    ]),
                    const SizedBox(height: 12),
                    Text(displayTitle,
                        style: widget.getTextStyle(
                            useArabicStyle,
                            TextStyle(
                                fontSize: isMobile ? 18 : 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.4)),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign:
                            useArabicStyle ? TextAlign.right : TextAlign.left),
                    if (!_isExpanded) ...[
                      const SizedBox(height: 12),
                      Text(_getSnippet(widget.article.description),
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
                      const Expanded(child: SizedBox()),
                    ],
                    if (_isExpanded) ...[
                      const SizedBox(height: 16),
                      Flexible(
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
                              : Text(_summary ?? "Unable to generate summary.",
                                  style: widget.getTextStyle(
                                      useArabicStyle,
                                      TextStyle(
                                          fontSize: 13,
                                          color: cryptoGold.withOpacity(0.9),
                                          height: 1.5,
                                          fontStyle: FontStyle.italic)),
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: useArabicStyle
                                      ? TextAlign.right
                                      : TextAlign.left),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        const Spacer(),
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
                                              offset: const Offset(0, 2))
                                        ]),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          RotationTransition(
                                              turns: _iconTurn,
                                              child: const Icon(
                                                  Icons.auto_awesome,
                                                  size: 16,
                                                  color: Colors.white)),
                                          const SizedBox(width: 6),
                                          Text(
                                              _isExpanded
                                                  ? 'Close'
                                                  : 'AI Recap',
                                              style: GoogleFonts.montserrat(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white))
                                        ])))),
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
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// --- WIDGET 2: Side Article Card ---

class _ExpandableSideArticleCard extends StatefulWidget {
  final RssItemModel article;
  final bool isArabic;
  final String Function(RssItemModel) getDisplayTitle;
  final bool Function(String) containsArabic;
  final TextStyle Function(bool, TextStyle) getTextStyle;
  final String Function(RssItemModel) getDisplaySource; // NEW

  const _ExpandableSideArticleCard({
    required this.article,
    required this.isArabic,
    required this.getDisplayTitle,
    required this.containsArabic,
    required this.getTextStyle,
    required this.getDisplaySource, // NEW
  });

  @override
  State<_ExpandableSideArticleCard> createState() =>
      _ExpandableSideArticleCardState();
}

class _ExpandableSideArticleCardState extends State<_ExpandableSideArticleCard>
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
          isArabic: widget.isArabic,
        );
        if (mounted)
          setState(() {
            _summary = result;
            _isLoading = false;
          });
      } catch (e) {
        if (mounted)
          setState(() {
            _summary = "Error generating summary.";
            _isLoading = false;
          });
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasArabicContent = widget.containsArabic(widget.article.title);
    final String displayTitle = widget.getDisplayTitle(widget.article);
    final bool useArabicStyle = widget.isArabic || hasArabicContent;
    final isMobile = ResponsiveHelper.isMobile(context);

    // USE THE SOURCE EXTRACTOR
    final String displaySource = widget.getDisplaySource(widget.article);

    return GestureDetector(
      onTap: () => _launchUrl(widget.article.link),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _isExpanded ? (isMobile ? 380 : 400) : (isMobile ? 150 : 152),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row
              Row(
                children: [
                  Text(displaySource.toUpperCase(),
                      style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: cryptoGold)),
                  const Spacer(),
                  Icon(Icons.access_time_rounded,
                      size: 12, color: Colors.white38),
                  const SizedBox(width: 4),
                  Text(_formatTimeAgo(widget.article.publishedAt),
                      style: GoogleFonts.montserrat(
                          fontSize: 10, color: Colors.white38)),
                ],
              ),
              const SizedBox(height: 8),
              Text(displayTitle,
                  style: widget.getTextStyle(
                      useArabicStyle,
                      TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.4)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: useArabicStyle ? TextAlign.right : TextAlign.left),
              if (!_isExpanded) const Expanded(child: SizedBox()),
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.05))),
                    child: _isLoading
                        ? const Center(
                            child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5, color: cryptoGold)))
                        : Text(
                            _summary ?? "Unable to generate summary.",
                            style: widget.getTextStyle(
                                useArabicStyle,
                                TextStyle(
                                    fontSize: 12,
                                    color: cryptoGold.withOpacity(0.9),
                                    height: 1.4,
                                    fontStyle: FontStyle.italic)),
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                            textAlign: useArabicStyle
                                ? TextAlign.right
                                : TextAlign.left,
                          ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  if (!_isExpanded)
                    Icon(Icons.arrow_right_alt,
                        size: 16, color: cryptoGold.withOpacity(0.5)),
                  if (!_isExpanded) const Spacer(),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _handleRecap,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: _isExpanded
                                    ? [Colors.deepPurpleAccent, Colors.purple]
                                    : [
                                        cryptoGold.withOpacity(0.8),
                                        cryptoOrange.withOpacity(0.8)
                                      ]),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: (_isExpanded
                                          ? Colors.purple
                                          : cryptoOrange)
                                      .withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1))
                            ]),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RotationTransition(
                              turns: _iconTurn,
                              child: const Icon(Icons.auto_awesome,
                                  size: 14, color: Colors.white),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isExpanded ? 'Close' : 'Recap',
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
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
              )
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return 'Just now';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return intl.DateFormat('MMM d').format(date);
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
