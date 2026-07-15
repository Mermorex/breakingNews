import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:news_app/core/utils/responsive.dart';
import 'package:news_app/data/models/news_source.dart';
import 'package:news_app/data/grok_service.dart';
import 'package:news_app/data/models/rss_item_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html;

// --- REFINED COLOR PALETTE ---
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
    'mosaiquefm': 'Mosaïque FM',
    'lapresse': 'La Presse',
    'jawharafm': 'Jawhara FM',
    'diwanfm': 'Diwan FM',
    'radioexpressfm': 'Express FM',
    'tunisiefocus': 'Tunisie Focus',
    'babnet': 'Babnet',
    'jeuneafrique': 'Jeune Afrique',
    'alchourouk': 'Al Chourouk',
    'businessnews': 'Business News',
    'nawaat': 'Nawaat',
    'yabiladi': 'Yabiladi',
    'hihi2': 'Hihi2',
    'aujourdhui': 'Aujourd\'hui le Maroc',
    'moroccoworldnews': 'Morocco World News',
    'tsa-algerie': 'TSA',
    'elwatan': 'El Watan',
    'djelfa': 'Djelfa',
    'elkhadra': 'El Khadra',
    'liberte-algerie': 'Liberté',
    'algerie360': 'Algérie 360',
    'elkhabar': 'El Khabar',
    'mehrnews': 'Mehr News',
    'tasnimnews': 'Tasnim',
    'tehrantimes': 'Tehran Times',
    'asriran': 'Asriran',
    'farsnews': 'Fars News',
    'una-oic': 'UNA-OIC',
    'iranintl': 'Iran International',
    'tabnak': 'Tabnak',
    'aljazeera': 'Al Jazeera',
    'skynewsarabia': 'Sky News Arabia',
    'bbc': 'BBC',
    'france24': 'France 24',
    'reuters': 'Reuters',
    'nytimes': 'NYT',
    'theguardian': 'The Guardian',
    'apnews': 'AP News',
    'theverge': 'The Verge',
    'techcrunch': 'TechCrunch',
    'wired': 'Wired',
    'themoscowtimes': 'The Moscow Times',
    'kyivpost': 'Kyiv Post',
    'euronews': 'Euronews',
    'trtworld': 'TRT World',
    'thehindu': 'The Hindu',
    'indianexpress': 'Indian Express',
    '7news': '7News Australia',
    'neoskosmos': 'Neos Kosmos',
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
    final genericNames = [
      'world news',
      'tunisia feed',
      'morocco feed',
      'algeria feed',
      'iran feed',
      'news',
      'feed',
      'articles',
      'unknown',
      'rss',
      'xml',
      'feedburner'
    ];
    return genericNames.any((generic) => name.toLowerCase().contains(generic));
  }

  static String _cleanSourceName(String name) {
    String clean = name
        .replaceAll(RegExp(r'\s*-\s*.*$'), '')
        .replaceAll(RegExp(r'\s*\|.*$'), '')
        .replaceAll(RegExp(r'\s*RSS.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*Feed.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*News.*$', caseSensitive: false), '')
        .trim();

    for (final entry in _domainMappings.entries) {
      if (clean.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return clean;
  }

  static String _extractFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      String host = uri.host.toLowerCase();
      if (host.startsWith('www.')) host = host.substring(4);
      if (host.contains(':')) host = host.split(':')[0];

      if (_domainMappings.containsKey(host)) {
        return _domainMappings[host]!;
      }

      final parts = host.split('.');
      for (int i = 0; i < parts.length; i++) {
        final domainPart = parts.sublist(i).join('.');
        if (_domainMappings.containsKey(domainPart)) {
          return _domainMappings[domainPart]!;
        }
        if (i == parts.length - 2) {
          final namePart = parts[i];
          if (_domainMappings.containsKey(namePart)) {
            return _domainMappings[namePart]!;
          }
        }
      }

      if (parts.isNotEmpty) {
        final firstPart = parts[0];
        return firstPart[0].toUpperCase() + firstPart.substring(1);
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }
}

// --- SECTION CONFIGURATION MODEL ---
class NewsSection {
  final String emoji;
  final String title;
  final String subtitle;
  final List<NewsSource> sources;
  final Color accentColor;
  final VoidCallback? onViewAll;

  NewsSection({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.sources,
    required this.accentColor,
    this.onViewAll,
  });
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
                style: AppFonts.body(
                  text: isArabic ? 'جاري التلخيص...' : 'Generating summary...',
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
                        Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: AppColors.accentPurple,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isArabic ? 'ملخص ذكي' : 'AI Recap',
                          style: AppFonts.caption(
                            text: isArabic ? 'ملخص ذكي' : 'AI Recap',
                            fontSize: 11,
                            color: AppColors.accentPurple,
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
                  style: AppFonts.body(
                    text: summary,
                    fontSize: isArabic ? 14 : 13,
                    color: AppColors.textPrimary,
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

class DashboardScreen extends StatefulWidget {
  final List<RssItemModel> worldNewsArticles;
  final List<RssItemModel> tunisianArticles;
  final List<RssItemModel> moroccanArticles;
  final List<RssItemModel> algerianArticles;
  final List<RssItemModel> iranianArticles;
  final List<RssItemModel> frenchArticles;
  final VoidCallback onViewWorldNews;
  final VoidCallback onViewTunisia;
  final VoidCallback onViewMorocco;
  final VoidCallback onViewAlgeria;
  final VoidCallback onViewFrance;
  final VoidCallback onViewIran;
  final int totalArticles;
  final int tunisianCount;
  final int moroccanCount;
  final int algerianCount;
  final int iranianCount;
  final int frenchCount;
  final bool isLoading;

  const DashboardScreen({
    super.key,
    required this.worldNewsArticles,
    required this.tunisianArticles,
    required this.moroccanArticles,
    required this.algerianArticles,
    required this.iranianArticles,
    required this.frenchArticles,
    required this.onViewWorldNews,
    required this.onViewTunisia,
    required this.onViewMorocco,
    required this.onViewAlgeria,
    required this.onViewIran,
    required this.onViewFrance,
    required this.totalArticles,
    required this.tunisianCount,
    required this.moroccanCount,
    required this.algerianCount,
    required this.iranianCount,
    required this.frenchCount,
    required this.isLoading,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  String _currentLangMode = 'original';
  final Map<String, String> _translationCache = {};
  final Set<String> _loadingTranslations = {};

  AnimationController? _tickerController;
  double _textWidth = 0.0;
  String _currentTickerText = "";
  List<RssItemModel> _recentNews = [];

  late final List<NewsSection> _sections;

  @override
  void initState() {
    super.initState();
    _initializeSections();
    _updateRecentNews();
  }

  void _initializeSections() {
    _sections = [
      NewsSection(
        emoji: '🌍',
        title: 'World News',
        subtitle:
            'Global headlines • ${NewsSources.international.length} sources',
        sources: NewsSources.international,
        accentColor: AppColors.accentOrange,
        onViewAll: widget.onViewWorldNews,
      ),
      NewsSection(
        emoji: '🇹🇳',
        title: 'Tunisia',
        subtitle: 'Local updates • ${NewsSources.tunisian.length} sources',
        sources: NewsSources.tunisian,
        accentColor: const Color(0xFFE74C3C),
        onViewAll: widget.onViewTunisia,
      ),
      NewsSection(
        emoji: '🇲🇦',
        title: 'Morocco',
        subtitle: 'Local updates • ${NewsSources.moroccan.length} sources',
        sources: NewsSources.moroccan,
        accentColor: const Color(0xFF27AE60),
        onViewAll: widget.onViewMorocco,
      ),
      NewsSection(
        emoji: '🇩🇿',
        title: 'Algeria',
        subtitle: 'Local updates • ${NewsSources.algerian.length} sources',
        sources: NewsSources.algerian,
        accentColor: const Color(0xFF3498DB),
        onViewAll: widget.onViewAlgeria,
      ),
      NewsSection(
        emoji: '🇫🇷',
        title: 'France',
        subtitle: 'French news • ${NewsSources.french.length} sources',
        sources: NewsSources.french,
        accentColor: const Color(0xFF0055A4),
        onViewAll: widget.onViewFrance,
      ),
      NewsSection(
        emoji: '🇮🇷',
        title: 'Iran',
        subtitle: 'Regional news • ${NewsSources.iranian.length} sources',
        sources: NewsSources.iranian,
        accentColor: const Color(0xFF9B59B6),
        onViewAll: widget.onViewIran,
      ),
    ];
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.worldNewsArticles.length != widget.worldNewsArticles.length ||
        oldWidget.tunisianArticles.length != widget.tunisianArticles.length) {
      _updateRecentNews();
    }
  }

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

  String _formatMixedText(String text) {
    if (_currentLangMode != 'arabic') return text;
    final words = text.split(' ');
    final buffer = StringBuffer();
    for (var word in words) {
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
      if (cleanWord.isNotEmpty && !AppFonts.containsArabic(cleanWord)) {
        buffer.write('($word) ');
      } else {
        buffer.write('$word ');
      }
    }
    return buffer.toString().trim();
  }

  String _getDisplayTitle(RssItemModel article) {
    final original = article.title;
    if (_currentLangMode == 'original') return original;
    final cacheKey = '$original-$_currentLangMode';
    if (_translationCache.containsKey(cacheKey)) {
      return _formatMixedText(_translationCache[cacheKey]!);
    }
    if (!_loadingTranslations.contains(cacheKey)) {
      _loadTranslation(original, _currentLangMode);
    }
    return original;
  }

  Future<void> _loadTranslation(String text, String targetMode) async {
    if (text.isEmpty) return;
    final cacheKey = '$text-$targetMode';
    _loadingTranslations.add(cacheKey);
    try {
      final translated = await _translateText(text, targetMode);
      if (translated != text && mounted) {
        setState(() {
          _translationCache[cacheKey] = translated;
        });
      }
    } finally {
      _loadingTranslations.remove(cacheKey);
    }
  }

  Future<String> _getTranslatedText(String text, String targetMode) async {
    final cacheKey = '$text-$targetMode';
    if (_translationCache.containsKey(cacheKey))
      return _formatMixedText(_translationCache[cacheKey]!);
    return await _translateText(text, targetMode);
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

  String _getDisplaySource(RssItemModel article) {
    return SourceExtractor.extractSource(article.source, article.link);
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

  @override
  void dispose() {
    _tickerController?.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    try {
      html.window.open(url, '_blank');
    } catch (e) {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildModernHeader()),
        SliverToBoxAdapter(child: _buildQuickStatsRow()),
        ..._sections.map((section) => _buildModernSection(
              emoji: section.emoji,
              title: section.title,
              subtitle: section.subtitle,
              articles: _getArticlesForSection(section.title),
              onViewAll: section.onViewAll!,
              accentColor: section.accentColor,
              sourceCount: section.sources.length,
            )),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  List<RssItemModel> _getArticlesForSection(String title) {
    switch (title) {
      case 'World News':
        return widget.worldNewsArticles;
      case 'Tunisia':
        return widget.tunisianArticles;
      case 'Morocco':
        return widget.moroccanArticles;
      case 'Algeria':
        return widget.algerianArticles;
      case 'Iran':
        return widget.iranianArticles;
      case 'France':
        return widget.frenchArticles;
      default:
        return [];
    }
  }

  Widget _buildModernHeader() {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Container(
      margin:
          EdgeInsets.fromLTRB(isMobile ? 16 : 32, 24, isMobile ? 16 : 32, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentOrange.withOpacity(0.9),
            AppColors.accentGold.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentOrange.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
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
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  '${widget.totalArticles}',
                                  style: GoogleFonts.inter(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Articles',
                                  style: AppFonts.body(
                                    text: 'Articles',
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
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
                            "Loading news feed...",
                            style: AppFonts.body(
                              text: "Loading news feed...",
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        )
                      : _buildModernTicker(),
                ),
              ],
            ),
          ),
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
          Icon(
            Icons.circle,
            size: 6,
            color: AppColors.accentGold,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: AppFonts.body(
              text: text,
              fontSize: 15,
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildModernLangToggle() {
    String displayText;
    IconData iconData;
    Color bgColor;

    switch (_currentLangMode) {
      case 'arabic':
        displayText = 'AR';
        iconData = Icons.translate;
        bgColor = Colors.white.withOpacity(0.25);
        break;
      case 'english':
        displayText = 'EN';
        iconData = Icons.translate;
        bgColor = Colors.white.withOpacity(0.25);
        break;
      default:
        displayText = 'ORIG';
        iconData = Icons.language;
        bgColor = Colors.white.withOpacity(0.15);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleLanguage,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                displayText,
                style: AppFonts.caption(
                  text: displayText,
                  fontSize: 12,
                  color: Colors.white,
                ).copyWith(letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatsRow() {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Container(
      margin:
          EdgeInsets.fromLTRB(isMobile ? 16 : 32, 20, isMobile ? 16 : 32, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatChip('🇹🇳', widget.tunisianCount, widget.onViewTunisia,
                const Color(0xFFE74C3C), NewsSources.tunisian.length),
            const SizedBox(width: 10),
            _buildStatChip('🇲🇦', widget.moroccanCount, widget.onViewMorocco,
                const Color(0xFF27AE60), NewsSources.moroccan.length),
            const SizedBox(width: 10),
            _buildStatChip('🇩🇿', widget.algerianCount, widget.onViewAlgeria,
                const Color(0xFF3498DB), NewsSources.algerian.length),
            const SizedBox(width: 10),
            _buildStatChip('🇫🇷', widget.frenchCount, widget.onViewFrance,
                const Color(0xFF0055A4), NewsSources.french.length),
            const SizedBox(width: 10),
            _buildStatChip('🇮🇷', widget.iranianCount, widget.onViewIran,
                const Color(0xFF9B59B6), NewsSources.iranian.length),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String emoji, int count, VoidCallback onTap,
      Color color, int sourceCount) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: AppFonts.title(
                    text: count.toString(),
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$sourceCount sources',
                  style: AppFonts.caption(
                    text: '$sourceCount sources',
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSection({
    required String emoji,
    required String title,
    required String subtitle,
    required List<RssItemModel> articles,
    required VoidCallback onViewAll,
    required Color accentColor,
    required int sourceCount,
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
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accentColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
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
                _buildViewAllButton(onViewAll, accentColor),
              ],
            ),
            const SizedBox(height: 20),
            if (widget.isLoading && articles.isEmpty)
              _buildLoadingState()
            else if (articles.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 700) {
                    return Column(
                      children: [
                        _buildFeaturedCard(articles.first, accentColor),
                        const SizedBox(height: 12),
                        ...articles.skip(1).take(2).map((article) =>
                            _buildCompactCard(article, accentColor)),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildFeaturedCard(articles.first, accentColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            if (articles.length > 1)
                              _buildCompactCard(articles[1], accentColor),
                            if (articles.length > 2) const SizedBox(height: 12),
                            if (articles.length > 2)
                              _buildCompactCard(articles[2], accentColor),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              )
            else if (widget.totalArticles == 0)
              _buildLoadingState()
            else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildViewAllButton(VoidCallback onTap, Color accentColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: accentColor,
              ),
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
            Icon(
              Icons.article_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
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

  Widget _buildFeaturedCard(RssItemModel article, Color accentColor) {
    final bool hasArabicContent = AppFonts.containsArabic(article.title);
    final bool useArabicStyle =
        _currentLangMode == 'arabic' || hasArabicContent;

    return _ExpandableFeaturedCard(
      article: article,
      accentColor: accentColor,
      isArabic: useArabicStyle,
      isSummaryArabic: _currentLangMode != 'english',
      getDisplayTitle: _getDisplayTitle,
      getDisplaySource: _getDisplaySource,
      onLaunchUrl: _launchUrl,
    );
  }

  Widget _buildCompactCard(RssItemModel article, Color accentColor) {
    final bool hasArabicContent = AppFonts.containsArabic(article.title);
    final bool useArabicStyle =
        _currentLangMode == 'arabic' || hasArabicContent;

    return _ExpandableCompactCard(
      article: article,
      accentColor: accentColor,
      isArabic: useArabicStyle,
      isSummaryArabic: _currentLangMode != 'english',
      getDisplayTitle: _getDisplayTitle,
      getDisplaySource: _getDisplaySource,
      onLaunchUrl: _launchUrl,
    );
  }
}

class _ExpandableFeaturedCard extends StatefulWidget {
  final RssItemModel article;
  final Color accentColor;
  final bool isArabic;
  final bool isSummaryArabic;
  final String Function(RssItemModel) getDisplayTitle;
  final String Function(RssItemModel) getDisplaySource;
  final Future<void> Function(String) onLaunchUrl;

  const _ExpandableFeaturedCard({
    required this.article,
    required this.accentColor,
    required this.isArabic,
    required this.isSummaryArabic,
    required this.getDisplayTitle,
    required this.getDisplaySource,
    required this.onLaunchUrl,
  });

  @override
  State<_ExpandableFeaturedCard> createState() =>
      _ExpandableFeaturedCardState();
}

class _ExpandableFeaturedCardState extends State<_ExpandableFeaturedCard>
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
                            displaySource.toUpperCase(),
                            style: AppFonts.caption(
                              text: displaySource.toUpperCase(),
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
                            Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _formatTimeAgo(widget.article.publishedAt),
                              style: AppFonts.caption(
                                text:
                                    _formatTimeAgo(widget.article.publishedAt),
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      displayTitle,
                      style: AppFonts.title(
                        text: displayTitle,
                        fontSize: isMobile ? 18 : 20,
                        color: Colors.white,
                      ).copyWith(height: 1.3, letterSpacing: -0.3),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign:
                          useArabicStyle ? TextAlign.right : TextAlign.left,
                    ),
                    if (!_isExpanded) ...[
                      const SizedBox(height: 10),
                      Text(
                        _getSnippet(widget.article.description),
                        style: AppFonts.body(
                          text: _getSnippet(widget.article.description),
                          fontSize: 14,
                          color: AppColors.textSecondary.withOpacity(0.8),
                        ).copyWith(height: 1.5),
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
                        if (!useArabicStyle) ...[
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Read article',
                            style: AppFonts.body(
                              text: 'Read article',
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
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
                                          AppColors.accentPurple,
                                          AppColors.accentPurple
                                              .withOpacity(0.8),
                                        ]
                                      : [
                                          AppColors.accentGold,
                                          AppColors.accentOrange,
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isExpanded
                                            ? AppColors.accentPurple
                                            : AppColors.accentOrange)
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
                                    child: const Icon(
                                      Icons.auto_awesome,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isExpanded ? 'Close' : 'AI Recap',
                                    style: AppFonts.caption(
                                      text: _isExpanded ? 'Close' : 'AI Recap',
                                      fontSize: 11,
                                      color: Colors.white,
                                    ).copyWith(fontWeight: FontWeight.w700),
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

class _ExpandableCompactCard extends StatefulWidget {
  final RssItemModel article;
  final Color accentColor;
  final bool isArabic;
  final bool isSummaryArabic;
  final String Function(RssItemModel) getDisplayTitle;
  final String Function(RssItemModel) getDisplaySource;
  final Future<void> Function(String) onLaunchUrl;

  const _ExpandableCompactCard({
    required this.article,
    required this.accentColor,
    required this.isArabic,
    required this.isSummaryArabic,
    required this.getDisplayTitle,
    required this.getDisplaySource,
    required this.onLaunchUrl,
  });

  @override
  State<_ExpandableCompactCard> createState() => _ExpandableCompactCardState();
}

class _ExpandableCompactCardState extends State<_ExpandableCompactCard>
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
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
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
        margin: const EdgeInsets.only(bottom: 12),
        height: _isExpanded ? 340 : 130,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isExpanded
                ? widget.accentColor.withOpacity(0.4)
                : AppColors.borderSubtle,
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
                      color: widget.accentColor,
                    ).copyWith(letterSpacing: 0.8),
                  ),
                  if (!useArabicStyle) const Spacer(),
                  if (useArabicStyle) const SizedBox(width: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 11,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimeAgo(widget.article.publishedAt),
                        style: AppFonts.caption(
                          text: _formatTimeAgo(widget.article.publishedAt),
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                displayTitle,
                style: AppFonts.title(
                  text: displayTitle,
                  fontSize: 14,
                  color: Colors.white,
                ).copyWith(height: 1.4),
                maxLines: _isExpanded ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                textAlign: useArabicStyle ? TextAlign.right : TextAlign.left,
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
                                    AppColors.accentPurple,
                                    AppColors.accentPurple.withOpacity(0.8),
                                  ]
                                : [
                                    widget.accentColor.withOpacity(0.8),
                                    widget.accentColor,
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RotationTransition(
                              turns: _iconTurn,
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _isExpanded ? 'Close' : 'Recap',
                              style: AppFonts.caption(
                                text: _isExpanded ? 'Close' : 'Recap',
                                fontSize: 10,
                                color: Colors.white,
                              ).copyWith(fontWeight: FontWeight.w700),
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
