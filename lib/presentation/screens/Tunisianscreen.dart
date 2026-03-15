import 'dart:async';
import 'dart:convert';
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

  // --- LANGUAGE STATE ---
  // Modes: 'original', 'arabic', 'english'
  String _currentLangMode = 'original';

  // Cache key format: "originalText-targetLang"
  final Map<String, String> _translationCache = {};
  final Set<String> _loadingTranslations = {};

  // --- DAILY RECAP STATE ---
  bool _isDailyRecapLoading = false;
  String? _dailyRecap;
  bool _showDailyRecap = false;

  // --- SOURCE MAP ---
  late final Map<String, String> _urlSourceMap;

  @override
  void initState() {
    super.initState();
    _initializeSourceMap();
    _loadDashboardData();
  }

  // --- INITIALIZATION ---
  void _initializeSourceMap() {
    _urlSourceMap = {};
    for (final source in DashboardConstants.allTunisianSources) {
      final name = source.name;
      final url = source.url;
      _urlSourceMap[name.toLowerCase().replaceAll(' ', '')] = name;
      try {
        final uri = Uri.parse(url);
        String host = uri.host.replaceFirst('www.', '');
        _urlSourceMap[host] = name;
        final domainPart = host.split('.').first;
        if (domainPart.length > 2) {
          _urlSourceMap[domainPart] = name;
        }
      } catch (e) {
        // Ignore
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
      _dailyRecap = null;
      _showDailyRecap = false;
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
    setState(() {
      if (_currentLangMode == 'original') {
        _currentLangMode = 'arabic';
      } else if (_currentLangMode == 'arabic') {
        _currentLangMode = 'english';
      } else {
        _currentLangMode = 'original';
      }
    });
  }

  Future<String> _getDisplayTitle(RssItemModel article) async {
    final original = article.title;

    if (_currentLangMode == 'original') return original;

    final targetLang = _currentLangMode;
    final cacheKey = '$original-$targetLang';

    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!;
    }

    if (_loadingTranslations.contains(cacheKey)) return original;

    return _loadTranslation(original, targetLang);
  }

  Future<String> _loadTranslation(String text, String targetLang) async {
    if (text.isEmpty) return text;

    final cacheKey = '$text-$targetLang';
    _loadingTranslations.add(cacheKey);

    try {
      bool toArabic = targetLang == 'arabic';

      bool isAlreadyArabic = _containsArabic(text);
      if ((toArabic && isAlreadyArabic) || (!toArabic && !isAlreadyArabic)) {
        return text;
      }

      final langPair = toArabic ? 'en|ar' : 'ar|en';
      final url =
          'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(text)}&langpair=$langPair';

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['responseStatus'] == 200) {
          final translated = data['responseData']['translatedText'] ?? text;

          if (mounted) {
            setState(() {
              _translationCache[cacheKey] = translated;
            });
          }
          return translated;
        }
      }
    } catch (e) {
      debugPrint('Translation failed: $e');
    } finally {
      _loadingTranslations.remove(cacheKey);
    }
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
      final allArticles = <RssItemModel>[];
      for (final items in _dashboardData.values) {
        allArticles.addAll(items);
      }

      allArticles.sort((a, b) => (b.publishedAt ?? DateTime.now())
          .compareTo(a.publishedAt ?? DateTime.now()));

      final recentArticles = allArticles.take(15).toList();

      final StringBuffer contextBuffer = StringBuffer();
      contextBuffer.writeln(
          'Tunisia News Summary - ${intl.DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now())}\n');

      for (int i = 0; i < recentArticles.length; i++) {
        final article = recentArticles[i];
        contextBuffer.writeln(
            '${i + 1}. [${_getDisplaySource(article)}] ${article.title}');
        if (article.description != null && article.description!.isNotEmpty) {
          final cleanDesc = article.description!
              .replaceAll(RegExp(r'<[^>]*>'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          if (cleanDesc.length > 50) {
            contextBuffer.writeln('   $cleanDesc');
          }
        }
        contextBuffer.writeln('');
      }

      final bool generateInEnglish = (_currentLangMode == 'english');
      final bool isArabic = !generateInEnglish;

      final String topicName = isArabic ? "تونس" : "Tunisia";

      final recap = await MistralService().generateDailyRecap(
        contextBuffer.toString(),
        isArabic: isArabic,
        topic: topicName,
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
          _dailyRecap = _isArabicContent
              ? "عذراً، لم نتمكن من إنشاء الملخص اليومي."
              : "Sorry, we couldn't generate today's summary.";
          _isDailyRecapLoading = false;
        });
      }
    }
  }

  void _closeDailyRecap() {
    setState(() {
      _showDailyRecap = false;
    });
  }

  // --- HELPERS ---

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

  bool get _isArabicContent => _currentLangMode == 'arabic';

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
        if (_showDailyRecap) _buildDailyRecapSection(),

        SliverToBoxAdapter(child: _buildStatusHeader()),

        // UPDATED: Shows immediately, regardless of loading state
        if (!_showDailyRecap)
          SliverToBoxAdapter(
            child: _buildDailyRecapTriggerContainer(),
          ),

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

  // --- UI COMPONENTS ---

  Widget _buildDailyRecapTriggerContainer() {
    // Disable if global loading is active OR if data is empty
    final bool isDisabled = _isGlobalLoading || _dashboardData.isEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(32, 0, 32, 24),
      decoration: BoxDecoration(
        color: cryptoCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurpleAccent.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
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
                    gradient: LinearGradient(
                      colors: isDisabled
                          ? [Colors.grey, Colors.grey.shade700]
                          : [Colors.deepPurpleAccent, Colors.purple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_motion,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isArabicContent
                            ? 'ماذا حدث اليوم؟'
                            : 'What Happened Today?',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDisabled ? Colors.white38 : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDisabled
                            ? (_isArabicContent
                                ? 'جاري تحميل الأخبار...'
                                : 'Loading news feed...')
                            : (_isArabicContent
                                ? 'انقر هنا للحصول على ملخص ذكي للأخبار'
                                : 'Tap here for an AI summary of current events'),
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isDailyRecapLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.deepPurpleAccent,
                      strokeWidth: 2,
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color:
                        isDisabled ? Colors.white24 : Colors.deepPurpleAccent,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyRecapSection() {
    final isMobile = ResponsiveHelper.isMobile(context);

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(32, 24, 32, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.deepPurpleAccent.withOpacity(0.2),
              Colors.purple.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.deepPurpleAccent.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurpleAccent, Colors.purple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_motion,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isArabicContent
                              ? 'ملخص أخبار اليوم'
                              : 'What Happened Today',
                          style: GoogleFonts.orbitron(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          intl.DateFormat('EEEE, MMMM d, yyyy')
                              .format(DateTime.now()),
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _closeDailyRecap,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(isMobile ? 20.0 : 24.0),
              child: _isDailyRecapLoading
                  ? _buildDailyRecapLoading()
                  : _buildDailyRecapContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyRecapLoading() {
    return Container(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: Colors.deepPurpleAccent,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isArabicContent
                  ? 'جاري تحليل الأخبار وإنشاء الملخص...'
                  : 'Analyzing news and generating summary...',
              style: GoogleFonts.montserrat(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyRecapContent() {
    final isArabic = _containsArabic(_dailyRecap ?? '');

    return Column(
      crossAxisAlignment:
          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.deepPurpleAccent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.deepPurpleAccent.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.psychology,
                size: 16,
                color: Colors.deepPurpleAccent,
              ),
              const SizedBox(width: 6),
              Text(
                'AI Generated',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurpleAccent,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          child: Text(
            _dailyRecap ?? '',
            style: _getTextStyle(
              isArabic,
              TextStyle(
                fontSize: 15,
                color: Colors.white.withOpacity(0.9),
                height: 1.7,
                letterSpacing: 0.3,
              ),
            ),
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
          ),
        ),
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
      default: // Original
        displayText = 'SRC';
        iconData = Icons.language;
    }

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
            Icon(iconData, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(displayText,
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

  Widget _buildMainArticleCard(RssItemModel article) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final String displaySource = _getDisplaySource(article);

    return GestureDetector(
      onTap: () => _openArticle(article.link),
      child: Container(
        height: isMobile ? 280 : 320,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      Text(_formatTimeAgo(article.publishedAt),
                          style: GoogleFonts.montserrat(
                              fontSize: 12, color: Colors.white54)),
                    ]),
                    const SizedBox(height: 12),
                    FutureBuilder<String>(
                        future: _getDisplayTitle(article),
                        builder: (context, snapshot) {
                          final text = snapshot.data ?? article.title;
                          final isArabic = _containsArabic(text);
                          return Text(text,
                              style: _getTextStyle(
                                  isArabic,
                                  TextStyle(
                                      fontSize: isMobile ? 18 : 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1.4)),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign:
                                  isArabic ? TextAlign.right : TextAlign.left);
                        }),
                    const SizedBox(height: 12),
                    Text(_getSnippet(article.description),
                        style: GoogleFonts.montserrat(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.6),
                            height: 1.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(
                      children: [
                        const Spacer(),
                        Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: cryptoOrange.withOpacity(0.15),
                                shape: BoxShape.circle),
                            child: Icon(Icons.arrow_outward_rounded,
                                color: cryptoOrange, size: 18)),
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

  Widget _buildSideArticleCard(RssItemModel article) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final String displaySource = _getDisplaySource(article);

    return GestureDetector(
      onTap: () => _openArticle(article.link),
      child: Container(
        height: isMobile ? 150 : 152,
        decoration: BoxDecoration(
            color: cryptoCardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cryptoGold.withOpacity(0.1))),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  Text(_formatTimeAgo(article.publishedAt),
                      style: GoogleFonts.montserrat(
                          fontSize: 10, color: Colors.white38)),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<String>(
                  future: _getDisplayTitle(article),
                  builder: (context, snapshot) {
                    final text = snapshot.data ?? article.title;
                    final isArabic = _containsArabic(text);
                    return Text(text,
                        style: _getTextStyle(
                            isArabic,
                            TextStyle(
                                fontSize: isMobile ? 13 : 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                height: 1.4)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: isArabic ? TextAlign.right : TextAlign.left);
                  }),
              const Spacer(),
              Row(
                children: [
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
