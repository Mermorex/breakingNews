import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:news_app/core/constants/dashboard_constants.dart';
import 'package:news_app/core/utils/responsive.dart';
import 'package:news_app/data/datasources/rss_remote_datasource.dart';
import 'package:news_app/data/grok_service.dart';
import 'package:news_app/data/models/rss_item_model.dart';
import 'package:news_app/data/models/news_source.dart';
import 'package:news_app/presentation/screens/source_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';

// --- Constants ---
const Color cryptoDarkBg = Color(0xFF0B0E14);
const Color cryptoCardBg = Color(0xFF151A25);
const Color cryptoOrange = Color(0xFFFF8C00);
const Color cryptoGold = Color(0xFFFFD700);
const Color textGrey = Color(0xFF6E7681);

class TunisianNewsScreen extends StatefulWidget {
  final bool isEmbedded;
  const TunisianNewsScreen({super.key, this.isEmbedded = false});

  @override
  State<TunisianNewsScreen> createState() => _TunisianNewsScreenState();
}

class _TunisianNewsScreenState extends State<TunisianNewsScreen> {
  final RssRemoteDataSource _dataSource = RssRemoteDataSource();

  // Sources from Constants
  List<NewsSource> get _rssSources => DashboardConstants.allTunisianSources;

  final Map<int, List<RssItemModel>> _dashboardData = {};
  final Set<int> _loadingIndices = {};
  bool _isGlobalLoading = true;
  String? _errorMessage;
  final Map<String, String> _sourceErrors = {};

  // --- NEW: Language & Translation State ---
  bool _isArabicContent = false;
  final Map<String, String> _translationCache = {};
  final Set<String> _loadingTranslations = {};

  // --- NEW: Source Map for consistent naming ---
  late final Map<String, String> _urlSourceMap;

  @override
  void initState() {
    super.initState();
    _initializeSourceMap();
    _loadDashboardData();
  }

  // --- INITIALIZATION FROM CONSTANTS ---
  void _initializeSourceMap() {
    _urlSourceMap = {};

    // Use allTunisianSources so scrapers like NewsNow are included in the map
    for (final source in DashboardConstants.allTunisianSources) {
      final name = source.name;
      final url = source.url;

      // Key from Name (normalized)
      _urlSourceMap[name.toLowerCase().replaceAll(' ', '')] = name;

      // Key from URL
      try {
        final uri = Uri.parse(url);
        String host = uri.host.replaceFirst('www.', '');
        _urlSourceMap[host] = name;

        // Add domain parts (e.g., 'newsnow' from 'www.newsnow.co.uk')
        final domainPart = host.split('.').first;
        if (domainPart.length > 2) {
          _urlSourceMap[domainPart] = name;
        }
      } catch (e) {
        // Ignore invalid URLs
      }
    }
  }

  // --- DATA LOADING ---

  Future<void> _loadDashboardData() async {
    setState(() {
      _isGlobalLoading = true;
      _errorMessage = null;
      _sourceErrors.clear();
      _loadingIndices.clear();
    });

    final fetchTasks = _rssSources.asMap().entries.map((entry) {
      return _fetchSource(entry.key, entry.value);
    }).toList();

    await Future.wait(fetchTasks);

    if (mounted) {
      setState(() {
        _isGlobalLoading = false;
      });
    }
  }

  Future<void> _fetchSource(int index, NewsSource source) async {
    if (mounted) setState(() => _loadingIndices.add(index));

    final cleanUrl = source.url.trim();
    if (cleanUrl.isEmpty) {
      _loadingIndices.remove(index);
      return;
    }

    try {
      List<RssItemModel> items;

      if (source.type == SourceType.scrapable) {
        items = await _dataSource.scrapeWebsite(
          cleanUrl,
          source.selectors!,
          sourceName: source.name,
          limit: 3,
        );
      } else {
        items = await _dataSource.fetchRssFeed(
          cleanUrl,
          sourceName: source.name,
          limit: 3,
        );
      }

      if (mounted) {
        setState(() {
          _loadingIndices.remove(index);
          if (items.isNotEmpty) _dashboardData[index] = items;
        });
      }
    } catch (e) {
      debugPrint('❌ ${source.name}: $e');
      if (mounted) {
        setState(() {
          _loadingIndices.remove(index);
          _sourceErrors[source.name] = e.toString();
        });
      }
    }
  }

  // --- LANGUAGE LOGIC ---

  void _toggleLanguage() {
    _isArabicContent = !_isArabicContent;
    setState(() {});
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
    if (article.source != null &&
        article.source!.isNotEmpty &&
        article.source != 'Unknown' &&
        !_isGenericSourceName(article.source!)) {
      return _cleanSourceName(article.source!);
    }

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

    final lowerName = name.toLowerCase();

    // Use word boundaries (\b) to ensure we match whole words only.
    // This prevents "NewsNow" from matching "news".
    for (final generic in genericNames) {
      final regex = RegExp('\\b${RegExp.escape(generic)}\\b');
      if (regex.hasMatch(lowerName)) {
        return true;
      }
    }
    return false;
  }

  String _cleanSourceName(String name) {
    return name
        .replaceAll(RegExp(r'\s*-\s*.*$'), '')
        .replaceAll(RegExp(r'\s*\|.*$'), '')
        .replaceAll(RegExp(r'\s*RSS.*$', caseSensitive: false), '')
        .trim();
  }

  String? _extractSourceFromUrl(String url) {
    final lowerUrl = url.toLowerCase();
    for (final entry in _urlSourceMap.entries) {
      if (lowerUrl.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return null;
  }

  // --- HELPERS ---

  Future<void> _openArticle(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url.trim());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link copied', style: GoogleFonts.montserrat()),
        backgroundColor: cryptoOrange,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  TextStyle _getTextStyle(bool isArabic, TextStyle style) {
    return isArabic
        ? GoogleFonts.notoKufiArabic(textStyle: style)
        : GoogleFonts.montserrat(textStyle: style);
  }

  bool _containsArabic(String text) =>
      RegExp(r'[\u0600-\u06FF]').hasMatch(text);

  // --- BUILD ---

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (widget.isEmbedded) return content;

    return Scaffold(
      backgroundColor: cryptoDarkBg,
      appBar: AppBar(
        backgroundColor: cryptoDarkBg,
        elevation: 0,
        title: Text(
          'Tunisia Feed',
          style: GoogleFonts.orbitron(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_sourceErrors.isNotEmpty)
            Tooltip(
              message: '${_sourceErrors.length} sources failed',
              child:
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: cryptoOrange),
            onPressed: _isGlobalLoading ? null : _loadDashboardData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildStatusHeader()),
        ..._rssSources.asMap().entries.map((entry) {
          final index = entry.key;
          final source = entry.value;
          final items = _dashboardData[index] ?? [];
          final isLoading = _loadingIndices.contains(index);
          final hasError = _sourceErrors.containsKey(source.name);

          return _buildSection(
            source: source,
            items: items,
            isLoading: isLoading,
            hasError: hasError,
          );
        }),
        const SliverPadding(padding: EdgeInsets.only(bottom: 60)),
      ],
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(32, 24, 32, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [cryptoOrange, cryptoGold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TUNISIA AGGREGATOR',
                          style: GoogleFonts.robotoMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.9),
                              letterSpacing: 2)),
                      const SizedBox(height: 4),
                      Text('${_rssSources.length} Active Sources',
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
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.rss_feed, color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${_dashboardData.length} Connected Feeds',
                      style: GoogleFonts.montserrat(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
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

  Widget _buildSection({
    required NewsSource source,
    required List<RssItemModel> items,
    required bool isLoading,
    required bool hasError,
  }) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isSourceArabic = _containsArabic(source.name);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
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
                  child: Text(isSourceArabic ? '🇹🇳' : '📰',
                      style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.name,
                        style: _getTextStyle(
                            isSourceArabic,
                            const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            )),
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
                if (items.isNotEmpty && !isLoading && !hasError)
                  _buildViewAllButton(source),
              ],
            ),
            const SizedBox(height: 20),
            if (isLoading)
              _buildLoadingPlaceholder()
            else if (items.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 700) {
                    return Column(
                      children: [
                        _buildMainArticleCard(items.first),
                        ...items.skip(1).take(2).map((article) => Padding(
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
                          flex: 5, child: _buildMainArticleCard(items.first)),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            if (items.length > 1)
                              _buildSideArticleCard(items[1]),
                            if (items.length > 2) const SizedBox(height: 16),
                            if (items.length > 2)
                              _buildSideArticleCard(items[2]),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              )
            else
              _buildEmptyErrorState(hasError),
          ],
        ),
      ),
    );
  }

  Widget _buildViewAllButton(NewsSource source) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SourceDetailScreen(
                sourceName: source.name,
                sourceUrl: source.url.trim(),
                sourceType: source.type,
                selectors: source.selectors,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: cryptoOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cryptoOrange.withOpacity(0.3)),
          ),
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

  Widget _buildLoadingPlaceholder() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
          color: cryptoCardBg, borderRadius: BorderRadius.circular(24)),
      child: const Center(
          child:
              CircularProgressIndicator(color: cryptoOrange, strokeWidth: 2)),
    );
  }

  Widget _buildEmptyErrorState(bool hasError) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: cryptoCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: (hasError ? Colors.red : Colors.white).withOpacity(0.1)),
      ),
      child: Center(
        child: Text(hasError ? 'Source failed to load' : 'No articles found',
            style: GoogleFonts.montserrat(color: Colors.white38)),
      ),
    );
  }

  // --- CARD WRAPPERS ---

  Widget _buildMainArticleCard(RssItemModel article) {
    return _ExpandableArticleCard(
      article: article,
      isArabic: _isArabicContent,
      getDisplayTitle: _getDisplayTitle,
      containsArabic: _containsArabic,
      getTextStyle: _getTextStyle,
      getDisplaySource: _getDisplaySource,
    );
  }

  Widget _buildSideArticleCard(RssItemModel article) {
    return _ExpandableSideArticleCard(
      article: article,
      isArabic: _isArabicContent,
      getDisplayTitle: _getDisplayTitle,
      containsArabic: _containsArabic,
      getTextStyle: _getTextStyle,
      getDisplaySource: _getDisplaySource,
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
  final String Function(RssItemModel) getDisplaySource;

  const _ExpandableArticleCard({
    required this.article,
    required this.isArabic,
    required this.getDisplayTitle,
    required this.containsArabic,
    required this.getTextStyle,
    required this.getDisplaySource,
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
    final String displaySource = widget.getDisplaySource(widget.article);

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(widget.article.link);
        if (await canLaunchUrl(uri))
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
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
}

// --- WIDGET 2: Side Article Card ---

class _ExpandableSideArticleCard extends StatefulWidget {
  final RssItemModel article;
  final bool isArabic;
  final String Function(RssItemModel) getDisplayTitle;
  final bool Function(String) containsArabic;
  final TextStyle Function(bool, TextStyle) getTextStyle;
  final String Function(RssItemModel) getDisplaySource;

  const _ExpandableSideArticleCard({
    required this.article,
    required this.isArabic,
    required this.getDisplayTitle,
    required this.containsArabic,
    required this.getTextStyle,
    required this.getDisplaySource,
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
    final String displaySource = widget.getDisplaySource(widget.article);

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(widget.article.link);
        if (await canLaunchUrl(uri))
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
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
                        : Text(_summary ?? "Unable to generate summary.",
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
                                : TextAlign.left),
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
                                    size: 14, color: Colors.white)),
                            const SizedBox(width: 6),
                            Text(_isExpanded ? 'Close' : 'Recap',
                                style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
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
}
