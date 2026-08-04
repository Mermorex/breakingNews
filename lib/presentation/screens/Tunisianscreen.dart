import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:news_app/data/datasources/rss_remote_datasource.dart';
import 'package:news_app/data/grok_service.dart';
import 'package:news_app/data/models/rss_item_model.dart';
import 'package:news_app/data/models/news_source.dart';
import 'package:news_app/presentation/screens/source_detail_screen.dart'
    hide AppColors, FullAiRecap;
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html;

// --- IMPORT SHARED DASHBOARD WIDGETS & CONSTANTS ---
import 'package:news_app/presentation/screens/dashboard/constants/app_colors.dart';
import 'package:news_app/presentation/screens/dashboard/constants/app_fonts.dart';
import 'package:news_app/presentation/screens/dashboard/utils/source_extractor.dart';
import 'package:news_app/presentation/screens/dashboard/widgets/dashboard_header.dart';
import 'package:news_app/presentation/screens/dashboard/widgets/news_section_block.dart';
import 'package:news_app/presentation/screens/dashboard/widgets/full_ai_recap.dart';

class TunisianNewsScreen extends StatefulWidget {
  final bool isEmbedded;
  const TunisianNewsScreen({super.key, this.isEmbedded = false});

  @override
  State<TunisianNewsScreen> createState() => _TunisianNewsScreenState();
}

class _TunisianNewsScreenState extends State<TunisianNewsScreen> {
  final RssRemoteDataSource _dataSource = RssRemoteDataSource();
  List<NewsSource> get _rssSources => NewsSources.tunisian;

  final Map<int, List<RssItemModel>> _dashboardData = {};
  final Set<int> _loadingIndices = {};
  bool _isGlobalLoading = true;
  final Map<String, String> _sourceErrors = {};

  // --- LANGUAGE STATE ---
  String _currentLangMode = 'original';
  final Map<String, String> _translationCache = {};
  final Set<String> _loadingTranslations = {};

  // --- DAILY RECAP STATE ---
  bool _isDailyRecapLoading = false;
  String? _dailyRecap;
  bool _showDailyRecap = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // ==================== DATA LOADING ====================

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

  // ==================== TOP STORY (For Hero Header) ====================

  RssItemModel? get _topStory {
    final allItems = _dashboardData.values.expand((e) => e).toList();
    if (allItems.isEmpty) return null;
    allItems.sort((a, b) => (b.publishedAt ?? DateTime(1970))
        .compareTo(a.publishedAt ?? DateTime(1970)));
    return allItems.first;
  }

  // ==================== TRANSLATION LOGIC ====================

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
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=${toArabic ? 'ar' : 'en'}&dt=t&q=${Uri.encodeComponent(text)}',
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

  // ==================== DAILY RECAP LOGIC ====================

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

      final isArabic = _currentLangMode != 'english';

      final recap = await MistralService().generateDailyRecap(
        contextBuffer.toString(),
        isArabic: isArabic,
        topic: isArabic ? "تونس" : "Tunisia",
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

  // ==================== HELPERS ====================

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

  void _navigateToSource(NewsSource source) {
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
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final content = CustomScrollView(
      slivers: [
        // 1. CINEMATIC HERO HEADER
        SliverToBoxAdapter(
          child: DashboardHeader(
            topArticle: _topStory,
            getDisplayTitle: _getDisplayTitle,
            getDisplaySource: (item) =>
                SourceExtractor.extractSource(item.source, item.link),
            onLaunchUrl: _launchUrl,
          ),
        ),

        // 2. ALWAYS-VISIBLE LANGUAGE SELECTOR (Works even if embedded!)
        SliverToBoxAdapter(child: _buildLanguageBar()),

        // 3. DAILY RECAP TRIGGER / DISPLAY
        if (_showDailyRecap)
          SliverToBoxAdapter(child: _buildDailyRecapSection())
        else
          SliverToBoxAdapter(child: _buildDailyRecapTrigger()),

        // 4. JOURNAL SECTIONS FOR EACH TUNISIAN SOURCE
        ..._rssSources.asMap().entries.map((entry) {
          final index = entry.key;
          final source = entry.value;
          final items = _dashboardData[index] ?? [];
          final isLoading = _loadingIndices.contains(index);
          final hasError = _sourceErrors.containsKey(source.name);

          return SliverToBoxAdapter(
            child: NewsSectionBlock(
              emoji: AppFonts.containsArabic(source.name) ? '🇹🇳' : '📰',
              title: source.name,
              subtitle:
                  hasError ? 'Connection issue' : '${items.length} articles',
              articles: items,
              onViewAll: () => _navigateToSource(source),
              accentColor: AppColors.tunisiaAccent, // Tunisia Red
              isLoading: isLoading,
              hasAnyArticles: _dashboardData.values.expand((e) => e).isNotEmpty,
              currentLangMode: _currentLangMode,
              getDisplayTitle: _getDisplayTitle,
              getDisplaySource: (item) =>
                  SourceExtractor.extractSource(item.source, item.link),
              onLaunchUrl: _launchUrl,
            ),
          );
        }),

        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );

    if (widget.isEmbedded) return content;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
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
          // Language toggle removed from here to prevent duplication
          if (_sourceErrors.isNotEmpty)
            Tooltip(
              message: '${_sourceErrors.length} sources failed',
              child:
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.accentOrange),
            onPressed: _isGlobalLoading ? null : _loadDashboardData,
          ),
        ],
      ),
      body: content,
    );
  }

  // --- LANGUAGE SELECTION BAR ---

  Widget _buildLanguageBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.end, // Aligns right like a journal control
        children: [
          _buildLangChip('SRC', 'original'),
          const SizedBox(width: 8),
          _buildLangChip('AR', 'arabic'),
          const SizedBox(width: 8),
          _buildLangChip('EN', 'english'),
        ],
      ),
    );
  }

  Widget _buildLangChip(String label, String mode) {
    final isSelected = _currentLangMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _currentLangMode = mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.tunisiaAccent
                  .withOpacity(0.15) // Uses Tunisia Red tint when selected
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.tunisiaAccent
                : AppColors.borderSubtle, // Tunisia Red border
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              mode == 'original' ? Icons.language : Icons.translate,
              size: 14,
              color: isSelected ? AppColors.tunisiaAccent : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppFonts.caption(
                text: label,
                fontSize: 11,
                color:
                    isSelected ? AppColors.tunisiaAccent : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DAILY RECAP UI ---

  Widget _buildDailyRecapTrigger() {
    final bool isDisabled = _isGlobalLoading || _dashboardData.isEmpty;
    final isArabic = _currentLangMode == 'arabic';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentPurple.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: GestureDetector(
        onTap: isDisabled ? null : _generateDailyRecap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentPurple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_motion,
                  color: AppColors.accentPurple, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'الملخص اليومي' : 'DAILY BRIEFING',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentPurple,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isDisabled
                        ? (isArabic
                            ? 'جاري تحميل الأخبار...'
                            : 'Loading news feed...')
                        : (isArabic
                            ? 'تلخيص ذكي لأهم أحداث تونس اليوم'
                            : 'AI summary of the most important Tunisian events today.'),
                    style: AppFonts.body(
                      text: isDisabled
                          ? (isArabic
                              ? 'جاري تحميل الأخبار...'
                              : 'Loading news feed...')
                          : (isArabic
                              ? 'تلخيص ذكي لأهم أحداث تونس اليوم'
                              : 'AI summary of the most important Tunisian events today.'),
                      fontSize: 12,
                      color: AppColors.textMuted,
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
                      color: AppColors.accentPurple, strokeWidth: 2))
            else
              Icon(Icons.arrow_forward_ios_rounded,
                  color: isDisabled ? Colors.white24 : AppColors.accentPurple,
                  size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyRecapSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: FullAiRecap(
        summary: _dailyRecap ?? "Unable to generate summary.",
        isArabic: _currentLangMode != 'english',
        isLoading: _isDailyRecapLoading,
        onClose: () => setState(() => _showDailyRecap = false),
      ),
    );
  }
}
