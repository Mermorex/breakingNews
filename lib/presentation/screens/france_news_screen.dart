import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:news_app/core/utils/responsive.dart';
import 'package:news_app/data/datasources/rss_remote_datasource.dart';
import 'package:news_app/data/grok_service.dart';
import 'package:news_app/data/models/rss_item_model.dart';
import 'package:news_app/data/models/news_source.dart';
import 'package:news_app/presentation/screens/source_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';

// --- FRENCH COLOR PALETTE ---
class FrenchAppColors {
  static const Color bgDark = Color(0xFF0B0E14);
  static const Color cardBg = Color(0xFF151A25);
  static const Color cardBgElevated = Color(0xFF1E2532);

  // French Tricolore Theme
  static const Color accentBlue = Color(0xFF0055A4);
  static const Color accentRed = Color(0xFFEF4135);
  static const Color accentWhite = Color(0xFFFFFFFF);

  static const Color accentGold = Color(0xFFFFD700); // Retained for variety
  static const Color accentPurple = Color(0xFF8B5CF6);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0AEC0);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderSubtle = Color(0xFF2D3748);
}

// --- UNIFIED FONT HELPER ---
class AppFonts {
  static bool containsArabic(String text) {
    return RegExp(
            r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]')
        .hasMatch(text);
  }

  static TextStyle getTextStyle({
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.normal,
    double height = 1.0,
    double letterSpacing = 0,
    String? text,
    bool forceArabic = false,
  }) {
    final bool isArabic = forceArabic || (text != null && containsArabic(text));
    if (isArabic) {
      return GoogleFonts.notoKufiArabic(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle title({
    required String text,
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.w700,
    double height = 1.3,
  }) {
    return getTextStyle(
      text: text,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      height: height,
    );
  }

  static TextStyle body({
    required String text,
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.normal,
    double height = 1.5,
  }) {
    return getTextStyle(
      text: text,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      height: height,
    );
  }

  static TextStyle caption({
    required String text,
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return getTextStyle(
      text: text,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: 0.5,
    );
  }
}

// --- ENHANCED SOURCE EXTRACTOR ---
class SourceExtractor {
  static final Map<String, String> _domainMappings = {
    // French Sources
    'lemonde': 'Le Monde',
    'lefigaro': 'Le Figaro',
    'liberation': 'Libération',
    'france24': 'France 24',
    'rfi': 'RFI',
    'bfmtv': 'BFM TV',
    'leparisien': 'Le Parisien',
    'lexpress': 'L\'Express',
    'franceinfo': 'France Info',
    '20minutes': '20 Minutes',
    'ouest-france': 'Ouest-France',
    'ladepeche': 'La Dépêche',
    'nicematin': 'Nice Matin',
    'lamarseillaise': 'La Marseillaise',
    'sudouest': 'Sud Ouest',
    'lacroix': 'La Croix',
    'les echos': 'Les Echos',
    // Fallback Tunisian/Other
    'mosaiquefm': 'Mosaïque FM',
    'lapresse': 'La Presse',
    'jawharafm': 'Jawhara FM',
  };

  static String extractSource(String? rssSource, String articleUrl) {
    if (rssSource != null &&
        rssSource.isNotEmpty &&
        rssSource != 'Unknown' &&
        !_isGenericName(rssSource)) {
      return _cleanSourceName(rssSource);
    }
    return _extractFromUrl(articleUrl);
  }

  static bool _isGenericName(String name) {
    final genericNames = ['world news', 'news', 'feed', 'articles', 'unknown'];
    return genericNames.any((generic) => name.toLowerCase().contains(generic));
  }

  static String _cleanSourceName(String name) {
    return name
        .replaceAll(RegExp(r'\s*-\s*.*$'), '')
        .replaceAll(RegExp(r'\s*\|.*$'), '')
        .trim();
  }

  static String _extractFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      String host = uri.host.toLowerCase().replaceAll('www.', '');
      if (_domainMappings.containsKey(host)) return _domainMappings[host]!;

      final parts = host.split('.');
      if (parts.isNotEmpty) {
        final name = parts[0];
        return name[0].toUpperCase() + name.substring(1);
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }
}

// --- FULL AI RECAP WIDGET ---
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
              FrenchAppColors.accentPurple.withOpacity(0.2),
              FrenchAppColors.accentBlue.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: FrenchAppColors.accentPurple.withOpacity(0.3),
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
                      AlwaysStoppedAnimation<Color>(FrenchAppColors.accentBlue),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isArabic ? 'جاري التلخيص...' : 'Génération du résumé...',
                style: AppFonts.body(
                  text:
                      isArabic ? 'جاري التلخيص...' : 'Génération du résumé...',
                  fontSize: 13,
                  color: FrenchAppColors.textSecondary,
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
            FrenchAppColors.accentBlue.withOpacity(0.15),
            FrenchAppColors.cardBgElevated.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: FrenchAppColors.accentBlue.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: FrenchAppColors.accentBlue.withOpacity(0.15),
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
                    color: FrenchAppColors.accentBlue.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: FrenchAppColors.accentBlue.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: FrenchAppColors.accentWhite,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isArabic ? 'ملخص ذكي' : 'Résumé IA',
                          style: AppFonts.caption(
                            text: isArabic ? 'ملخص ذكي' : 'Résumé IA',
                            fontSize: 11,
                            color: FrenchAppColors.accentWhite,
                          ).copyWith(fontWeight: FontWeight.w700),
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
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: FrenchAppColors.textMuted,
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
                  style: AppFonts.body(
                    text: summary,
                    fontSize: isArabic ? 14 : 13,
                    color: FrenchAppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ).copyWith(height: 1.7, letterSpacing: 0.2),
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

class FrenchNewsScreen extends StatefulWidget {
  final bool isEmbedded;
  const FrenchNewsScreen({super.key, this.isEmbedded = false});

  @override
  State<FrenchNewsScreen> createState() => _FrenchNewsScreenState();
}

class _FrenchNewsScreenState extends State<FrenchNewsScreen>
    with TickerProviderStateMixin {
  final RssRemoteDataSource _dataSource = RssRemoteDataSource();
  // Make sure to define 'french' in your NewsSources model or use a hardcoded list here
  List<NewsSource> get _rssSources => NewsSources.french;

  final Map<int, List<RssItemModel>> _dashboardData = {};
  final Set<int> _loadingIndices = {};
  bool _isGlobalLoading = true;
  final Map<String, String> _sourceErrors = {};

  // --- LANGUAGE & TICKER STATE ---
  String _currentLangMode = 'original';
  final Map<String, String> _translationCache = {};

  AnimationController? _tickerController;
  double _textWidth = 0.0;
  String _currentTickerText = "";
  List<RssItemModel> _recentNews = [];

  // --- DAILY RECAP STATE ---
  bool _isDailyRecapLoading = false;
  String? _dailyRecap;
  bool _showDailyRecap = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // --- DATA LOADING ---
  Future<void> _loadDashboardData() async {
    setState(() {
      _isGlobalLoading = true;
      _sourceErrors.clear();
      _loadingIndices.clear();
      _dailyRecap = null;
      _showDailyRecap = false;
    });

    final fetchTasks = _rssSources.asMap().entries.map((entry) {
      return _fetchSource(entry.key, entry.value);
    }).toList();

    await Future.wait(fetchTasks);

    if (mounted) {
      setState(() => _isGlobalLoading = false);
      _updateRecentNews();
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

  // --- TICKER & LANGUAGE LOGIC ---
  void _updateRecentNews() {
    final allItems = _dashboardData.values.expand((e) => e).toList();
    allItems.sort((a, b) => (b.publishedAt ?? DateTime(1970))
        .compareTo(a.publishedAt ?? DateTime(1970)));
    _recentNews = allItems.take(10).toList();

    if (_currentLangMode == 'original') {
      _currentTickerText = _recentNews.map((e) => e.title).join('   •   ');
      _initTicker();
    } else {
      _translateTickerText();
    }
  }

  void _toggleLanguage() {
    setState(() {
      if (_currentLangMode == 'original') {
        _currentLangMode = 'arabic';
      } else if (_currentLangMode == 'arabic') {
        _currentLangMode = 'english';
      } else {
        _currentLangMode = 'original';
      }
    });

    if (_currentLangMode == 'original') {
      _currentTickerText = _recentNews.map((e) => e.title).join('   •   ');
      _initTicker();
    } else {
      _translateTickerText();
    }
  }

  Future<void> _translateTickerText() async {
    if (_recentNews.isEmpty) return;
    final titles = _recentNews.map((e) => e.title).toList();
    List<String> translatedTitles = [];
    for (var title in titles) {
      translatedTitles.add(await _getTranslatedText(title, _currentLangMode));
    }
    if ((_currentLangMode == 'arabic' || _currentLangMode == 'english') &&
        mounted) {
      setState(() {
        _currentTickerText = translatedTitles.join('   •   ');
      });
      _initTicker();
    }
  }

  void _initTicker() {
    if (_currentTickerText.isEmpty) return;
    final textPainter = TextPainter(
      text: TextSpan(
        text: _currentTickerText,
        style: AppFonts.body(
          text: _currentTickerText,
          fontSize: 15,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
    )..layout();
    _textWidth = textPainter.width;
    final duration = Duration(milliseconds: ((_textWidth / 80) * 1000).round());
    _tickerController?.dispose();
    _tickerController = AnimationController(
      vsync: this,
      duration: duration,
    )..repeat();
    if (mounted) setState(() {});
  }

  Future<String> _getDisplayTitle(RssItemModel article) async {
    final original = article.title;
    if (_currentLangMode == 'original') return original;
    return _getTranslatedText(original, _currentLangMode);
  }

  Future<String> _getTranslatedText(String text, String targetMode) async {
    final cacheKey = '$text-$targetMode';
    if (_translationCache.containsKey(cacheKey))
      return _translationCache[cacheKey]!;
    return _translateText(text, targetMode);
  }

  Future<String> _translateText(String text, String targetMode) async {
    if (text.isEmpty) return text;
    final cacheKey = '$text-$targetMode';
    if (_translationCache.containsKey(cacheKey))
      return _translationCache[cacheKey]!;

    bool toArabic = targetMode == 'arabic';
    bool isSourceArabic = AppFonts.containsArabic(text);

    if ((toArabic && isSourceArabic) ||
        (!toArabic && !isSourceArabic && targetMode == 'english')) {
      return text;
    }

    try {
      final sourceLang = 'auto';
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
          _translationCache[cacheKey] = translatedParts;
          return translatedParts;
        }
      }
    } catch (e) {}
    return text;
  }

  // --- DAILY RECAP LOGIC ---
  Future<void> _generateDailyRecap() async {
    if (_dashboardData.isEmpty) return;

    setState(() {
      _isDailyRecapLoading = true;
      _showDailyRecap = true;
    });

    try {
      final allArticles = _dashboardData.values.expand((e) => e).toList();
      allArticles.sort((a, b) => (b.publishedAt ?? DateTime.now())
          .compareTo(a.publishedAt ?? DateTime.now()));

      final contextBuffer = StringBuffer();
      for (var article in allArticles.take(50)) {
        contextBuffer.writeln(article.title);
      }

      final bool generateInEnglish = (_currentLangMode == 'english');
      final bool isArabic = !generateInEnglish;

      final recap = await MistralService().generateDailyRecap(
        contextBuffer.toString(),
        isArabic: isArabic,
        topic: isArabic ? "فرنسا" : "France",
      );

      if (mounted) {
        setState(() {
          _dailyRecap = recap;
          _isDailyRecapLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dailyRecap = "Error generating summary.";
          _isDailyRecapLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tickerController?.dispose();
    super.dispose();
  }

  // Fixed: Removed dart:html dependency for cross-platform support
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
    }
  }

  bool get _isArabicContent => _currentLangMode == 'arabic';

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (widget.isEmbedded) return content;

    return Scaffold(
      backgroundColor: FrenchAppColors.bgDark,
      appBar: AppBar(
        backgroundColor: FrenchAppColors.bgDark,
        elevation: 0,
        title: Text(
          'France Feed',
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
            icon: const Icon(Icons.refresh_rounded,
                color: FrenchAppColors.accentBlue),
            onPressed: _isGlobalLoading ? null : _loadDashboardData,
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildModernHeader()),
        if (_showDailyRecap)
          SliverToBoxAdapter(child: _buildDailyRecapSection()),
        if (!_showDailyRecap)
          SliverToBoxAdapter(child: _buildDailyRecapTrigger()),
        ..._rssSources.asMap().entries.map((entry) {
          final index = entry.key;
          final source = entry.value;
          final items = _dashboardData[index] ?? [];
          final isLoading = _loadingIndices.contains(index);
          final hasError = _sourceErrors.containsKey(source.name);

          return _buildModernSection(
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

  // --- UI COMPONENTS ---

  Widget _buildModernHeader() {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Container(
      margin:
          EdgeInsets.fromLTRB(isMobile ? 16 : 32, 24, isMobile ? 16 : 32, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FrenchAppColors.accentBlue.withOpacity(0.9),
            FrenchAppColors.accentRed.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: FrenchAppColors.accentBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  isMobile ? 20 : 28, 24, isMobile ? 20 : 28, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'LIVE FEED',
                            style: AppFonts.caption(
                              text: 'LIVE FEED',
                              fontSize: 10,
                              color: Colors.white,
                            ).copyWith(
                                letterSpacing: 2, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${_rssSources.length} Active Sources',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildModernLangToggle(),
                ],
              ),
            ),
            Container(
              height: 54,
              width: double.infinity,
              color: Colors.black.withOpacity(0.2),
              child: _tickerController == null
                  ? Center(
                      child: Text(
                        "Loading feed...",
                        style: AppFonts.body(
                            text: "Loading feed...",
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.6)),
                      ),
                    )
                  : _buildModernTicker(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTicker() {
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
              _buildTickerItem(_currentTickerText),
              const SizedBox(width: 80),
              _buildTickerItem(_currentTickerText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTickerItem(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 6, color: FrenchAppColors.accentRed),
          const SizedBox(width: 12),
          Text(
            text,
            style: AppFonts.body(
                text: text,
                fontSize: 15,
                color: Colors.white.withOpacity(0.95),
                fontWeight: FontWeight.w500),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildModernLangToggle() {
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleLanguage,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                displayText,
                style: AppFonts.caption(
                        text: displayText, fontSize: 12, color: Colors.white)
                    .copyWith(letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyRecapTrigger() {
    final bool isDisabled = _isGlobalLoading || _dashboardData.isEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(32, 20, 32, 8),
      decoration: BoxDecoration(
        color: FrenchAppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FrenchAppColors.accentBlue.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
              color: FrenchAppColors.accentBlue.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : _generateDailyRecap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      FrenchAppColors.accentBlue,
                      FrenchAppColors.accentRed
                    ]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.auto_awesome_motion,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isArabicContent
                            ? 'ماذا حدث اليوم؟'
                            : 'Quoi de neuf aujourd\'hui ?',
                        style: AppFonts.title(
                            text: _isArabicContent
                                ? 'ماذا حدث اليوم؟'
                                : 'Quoi de neuf aujourd\'hui ?',
                            fontSize: 16,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDisabled
                            ? (_isArabicContent
                                ? 'جاري تحميل الأخبار...'
                                : 'Chargement...')
                            : (_isArabicContent
                                ? 'ملخص ذكي للأخبار الفرنسية'
                                : 'Résumé IA de l\'actualité'),
                        style: AppFonts.body(
                            text: '',
                            fontSize: 12,
                            color: FrenchAppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (_isDailyRecapLoading)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: FrenchAppColors.accentBlue, strokeWidth: 2))
                else
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: isDisabled
                          ? Colors.white24
                          : FrenchAppColors.accentBlue,
                      size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyRecapSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(32, 24, 32, 16),
      child: FullAiRecap(
        summary: _dailyRecap ?? "Unable to generate summary.",
        isArabic: _isArabicContent,
        isLoading: _isDailyRecapLoading,
        onClose: () => setState(() => _showDailyRecap = false),
      ),
    );
  }

  Widget _buildModernSection({
    required NewsSource source,
    required List<RssItemModel> items,
    required bool isLoading,
    required bool hasError,
  }) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(isMobile ? 16 : 32, 28, isMobile ? 16 : 32, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: FrenchAppColors.accentBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: FrenchAppColors.accentBlue.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Text(
                      AppFonts.containsArabic(source.name) ? '🇫🇷' : '📰',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.name,
                        style: AppFonts.title(
                                text: source.name,
                                fontSize: 20,
                                color: Colors.white)
                            .copyWith(letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Recent updates',
                        style: AppFonts.body(
                            text: 'Recent updates',
                            fontSize: 13,
                            color: FrenchAppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (items.isNotEmpty && !isLoading && !hasError)
                  _buildViewAllButton(source),
              ],
            ),
            const SizedBox(height: 20),
            if (isLoading)
              _buildLoadingState()
            else if (items.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 700) {
                    return Column(
                      children: [
                        _buildFeaturedCard(items.first),
                        const SizedBox(height: 12),
                        ...items
                            .skip(1)
                            .take(2)
                            .map((item) => _buildCompactCard(item)),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildFeaturedCard(items.first)),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            if (items.length > 1) _buildCompactCard(items[1]),
                            if (items.length > 2) const SizedBox(height: 12),
                            if (items.length > 2) _buildCompactCard(items[2]),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              )
            else
              _buildEmptyState(hasError),
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
            color: FrenchAppColors.accentBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: FrenchAppColors.accentBlue.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('View All',
                  style: AppFonts.caption(
                      text: 'View All',
                      fontSize: 12,
                      color: FrenchAppColors.accentBlue)),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded,
                  size: 14, color: FrenchAppColors.accentBlue),
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
          color: FrenchAppColors.cardBg,
          borderRadius: BorderRadius.circular(20)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                    color: FrenchAppColors.accentBlue, strokeWidth: 3)),
            const SizedBox(height: 16),
            Text('Loading articles...',
                style: AppFonts.body(
                    text: 'Loading articles...',
                    fontSize: 14,
                    color: FrenchAppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool hasError) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
          color: FrenchAppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: FrenchAppColors.borderSubtle)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined,
                size: 48, color: FrenchAppColors.textMuted),
            const SizedBox(height: 12),
            Text('No articles found',
                style: AppFonts.title(
                    text: 'No articles found',
                    fontSize: 15,
                    color: FrenchAppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(RssItemModel article) {
    return _FrenchMainArticleCard(
      article: article,
      accentColor: FrenchAppColors.accentBlue,
      isArabic: _isArabicContent,
      isSummaryArabic: _currentLangMode != 'english',
      getDisplayTitle: _getDisplayTitle,
      getDisplaySource: (item) =>
          SourceExtractor.extractSource(item.source, item.link),
      onLaunchUrl: _launchUrl,
    );
  }

  Widget _buildCompactCard(RssItemModel article) {
    return _FrenchSideArticleCard(
      article: article,
      accentColor: FrenchAppColors.accentRed,
      isArabic: _isArabicContent,
      isSummaryArabic: _currentLangMode != 'english',
      getDisplayTitle: _getDisplayTitle,
      getDisplaySource: (item) =>
          SourceExtractor.extractSource(item.source, item.link),
      onLaunchUrl: _launchUrl,
    );
  }
}

// --- REUSABLE CARD WIDGETS FOR FRENCH NEWS ---

class _FrenchMainArticleCard extends StatefulWidget {
  final RssItemModel article;
  final Color accentColor;
  final bool isArabic;
  final bool isSummaryArabic;
  final Future<String> Function(RssItemModel) getDisplayTitle;
  final String Function(RssItemModel) getDisplaySource;
  final Future<void> Function(String) onLaunchUrl;

  const _FrenchMainArticleCard({
    required this.article,
    required this.accentColor,
    required this.isArabic,
    required this.isSummaryArabic,
    required this.getDisplayTitle,
    required this.getDisplaySource,
    required this.onLaunchUrl,
  });

  @override
  State<_FrenchMainArticleCard> createState() => _FrenchMainArticleCardState();
}

class _FrenchMainArticleCardState extends State<_FrenchMainArticleCard>
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
        duration: const Duration(milliseconds: 250), vsync: this);
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
        if (mounted)
          setState(() {
            _summary = result;
            _isLoading = false;
          });
      } catch (e) {
        if (mounted)
          setState(() {
            _summary = "Unable to generate summary.";
            _isLoading = false;
          });
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
    final bool useArabicStyle =
        widget.isArabic || AppFonts.containsArabic(widget.article.title);

    return GestureDetector(
      onTap: () => widget.onLaunchUrl(widget.article.link),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
        height: _isExpanded ? (isMobile ? 480 : 500) : (isMobile ? 260 : 280),
        decoration: BoxDecoration(
          color: FrenchAppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isExpanded
                ? widget.accentColor.withOpacity(0.5)
                : FrenchAppColors.borderSubtle,
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
                        widget.accentColor.withOpacity(0.3)
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
                    Row(
                      children: [
                        if (useArabicStyle) const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: widget.accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget
                                .getDisplaySource(widget.article)
                                .toUpperCase(),
                            style: AppFonts.caption(
                              text: widget
                                  .getDisplaySource(widget.article)
                                  .toUpperCase(),
                              fontSize: 10,
                              color: widget.accentColor,
                            ).copyWith(letterSpacing: 1.0),
                          ),
                        ),
                        if (!useArabicStyle) const Spacer(),
                        if (useArabicStyle) const SizedBox(width: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 13, color: FrenchAppColors.textMuted),
                            const SizedBox(width: 5),
                            Text(
                              _formatTimeAgo(widget.article.publishedAt),
                              style: AppFonts.caption(
                                  text: _formatTimeAgo(
                                      widget.article.publishedAt),
                                  fontSize: 11,
                                  color: FrenchAppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FutureBuilder<String>(
                      future: widget.getDisplayTitle(widget.article),
                      builder: (context, snapshot) {
                        final title = snapshot.data ?? widget.article.title;
                        return Text(
                          title,
                          style: AppFonts.title(
                                  text: title,
                                  fontSize: isMobile ? 18 : 20,
                                  color: Colors.white)
                              .copyWith(height: 1.3),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign:
                              useArabicStyle ? TextAlign.right : TextAlign.left,
                        );
                      },
                    ),
                    if (!_isExpanded) ...[
                      const SizedBox(height: 10),
                      Text(
                        _getSnippet(widget.article.description),
                        style: AppFonts.body(
                                text: _getSnippet(widget.article.description),
                                fontSize: 13,
                                color: FrenchAppColors.textSecondary
                                    .withOpacity(0.8))
                            .copyWith(height: 1.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign:
                            useArabicStyle ? TextAlign.right : TextAlign.left,
                      ),
                      const Spacer(),
                    ],
                    if (_isExpanded) ...[
                      const SizedBox(height: 12),
                      Expanded(
                        child: FullAiRecap(
                          summary: _summary ?? "Unable to generate summary.",
                          isArabic: widget.isSummaryArabic,
                          isLoading: _isLoading,
                          onClose: () {
                            setState(() => _isExpanded = false);
                            _controller.reverse();
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        const Spacer(),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _handleRecap,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isExpanded
                                      ? [
                                          FrenchAppColors.accentBlue,
                                          FrenchAppColors.accentBlue
                                              .withOpacity(0.8)
                                        ]
                                      : [
                                          FrenchAppColors.accentRed,
                                          widget.accentColor
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isExpanded
                                            ? FrenchAppColors.accentBlue
                                            : widget.accentColor)
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
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
                                    _isExpanded ? 'Close' : 'AI Recap',
                                    style: AppFonts.caption(
                                            text: _isExpanded
                                                ? 'Close'
                                                : 'AI Recap',
                                            fontSize: 11,
                                            color: Colors.white)
                                        .copyWith(fontWeight: FontWeight.w700),
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
}

class _FrenchSideArticleCard extends StatefulWidget {
  final RssItemModel article;
  final Color accentColor;
  final bool isArabic;
  final bool isSummaryArabic;
  final Future<String> Function(RssItemModel) getDisplayTitle;
  final String Function(RssItemModel) getDisplaySource;
  final Future<void> Function(String) onLaunchUrl;

  const _FrenchSideArticleCard({
    required this.article,
    required this.accentColor,
    required this.isArabic,
    required this.isSummaryArabic,
    required this.getDisplayTitle,
    required this.getDisplaySource,
    required this.onLaunchUrl,
  });

  @override
  State<_FrenchSideArticleCard> createState() => _FrenchSideArticleCardState();
}

class _FrenchSideArticleCardState extends State<_FrenchSideArticleCard>
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
        duration: const Duration(milliseconds: 250), vsync: this);
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
        if (mounted)
          setState(() {
            _summary = result;
            _isLoading = false;
          });
      } catch (e) {
        if (mounted)
          setState(() {
            _summary = "Unable to generate summary.";
            _isLoading = false;
          });
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
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return intl.DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final String displaySource = widget.getDisplaySource(widget.article);
    final bool useArabicStyle =
        widget.isArabic || AppFonts.containsArabic(widget.article.title);

    return GestureDetector(
      onTap: () => widget.onLaunchUrl(widget.article.link),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
        margin: const EdgeInsets.only(bottom: 12),
        height: _isExpanded ? 340 : 130,
        decoration: BoxDecoration(
          color: FrenchAppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isExpanded
                ? widget.accentColor.withOpacity(0.4)
                : FrenchAppColors.borderSubtle,
            width: _isExpanded ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: useArabicStyle
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (useArabicStyle) const Spacer(),
                  Text(
                    displaySource.toUpperCase(),
                    style: AppFonts.caption(
                            text: displaySource.toUpperCase(),
                            fontSize: 10,
                            color: widget.accentColor)
                        .copyWith(letterSpacing: 0.8),
                  ),
                  if (!useArabicStyle) const Spacer(),
                  if (useArabicStyle) const SizedBox(width: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 11, color: FrenchAppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimeAgo(widget.article.publishedAt),
                        style: AppFonts.caption(
                            text: _formatTimeAgo(widget.article.publishedAt),
                            fontSize: 10,
                            color: FrenchAppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FutureBuilder<String>(
                future: widget.getDisplayTitle(widget.article),
                builder: (context, snapshot) {
                  final title = snapshot.data ?? widget.article.title;
                  return Text(
                    title,
                    style: AppFonts.title(
                            text: title, fontSize: 14, color: Colors.white)
                        .copyWith(height: 1.4),
                    maxLines: _isExpanded ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign:
                        useArabicStyle ? TextAlign.right : TextAlign.left,
                  );
                },
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 160,
                  child: FullAiRecap(
                    summary: _summary ?? "Unable to generate summary.",
                    isArabic: widget.isSummaryArabic,
                    isLoading: _isLoading,
                    onClose: () {
                      setState(() => _isExpanded = false);
                      _controller.reverse();
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const Spacer(),
              Row(
                children: [
                  const Spacer(),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _handleRecap,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isExpanded
                                ? [
                                    FrenchAppColors.accentBlue,
                                    FrenchAppColors.accentBlue.withOpacity(0.8)
                                  ]
                                : [
                                    widget.accentColor.withOpacity(0.8),
                                    widget.accentColor
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RotationTransition(
                              turns: _iconTurn,
                              child: const Icon(Icons.auto_awesome,
                                  size: 12, color: Colors.white),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _isExpanded ? 'Close' : 'Recap',
                              style: AppFonts.caption(
                                      text: _isExpanded ? 'Close' : 'Recap',
                                      fontSize: 10,
                                      color: Colors.white)
                                  .copyWith(fontWeight: FontWeight.w700),
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
      ),
    );
  }
}
