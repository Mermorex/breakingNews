import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:news_app/data/models/news_source.dart';
import 'package:news_app/data/models/rss_item_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html;

// ✅ Using central theme files instead of local constants
import 'package:news_app/core/theme/app_colors.dart' as theme;
import 'utils/source_extractor.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/quick_stats_row.dart';
import 'widgets/news_section_block.dart';

// --- SECTION CONFIGURATION MODEL ---
class _SectionConfig {
  final String emoji; // We will keep emoji in config but hide it in UI later
  final String title;
  final String subtitle;
  final List<NewsSource> sources;
  final Color accentColor;
  final VoidCallback onViewAll;

  _SectionConfig({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.sources,
    required this.accentColor,
    required this.onViewAll,
  });
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

class _DashboardScreenState extends State<DashboardScreen> {
  String _currentLangMode = 'original';
  final Map<String, String> _translationCache = {};
  final Set<String> _loadingTranslations = {};
  int _selectedCategoryIndex = 0;

  late final List<_SectionConfig> _sections;

  @override
  void initState() {
    super.initState();
    _initializeSections();
  }

  void _initializeSections() {
    _sections = [
      _SectionConfig(
        emoji: '🌍',
        title: 'World News',
        subtitle:
            'Global headlines • ${NewsSources.international.length} sources',
        sources: NewsSources.international,
        accentColor: theme.AppColors.frenchBlue,
        onViewAll: widget.onViewWorldNews,
      ),
      _SectionConfig(
        emoji: '🇹🇳',
        title: 'Tunisia',
        subtitle: 'Local updates • ${NewsSources.tunisian.length} sources',
        sources: NewsSources.tunisian,
        accentColor: theme.AppColors.tunisianRed,
        onViewAll: widget.onViewTunisia,
      ),
      _SectionConfig(
        emoji: '🇲🇦',
        title: 'Morocco',
        subtitle: 'Local updates • ${NewsSources.moroccan.length} sources',
        sources: NewsSources.moroccan,
        accentColor: theme.AppColors.internationalGreen,
        onViewAll: widget.onViewMorocco,
      ),
      _SectionConfig(
        emoji: '🇩🇿',
        title: 'Algeria',
        subtitle: 'Local updates • ${NewsSources.algerian.length} sources',
        sources: NewsSources.algerian,
        accentColor: theme.AppColors.internationalGreen,
        onViewAll: widget.onViewAlgeria,
      ),
      _SectionConfig(
        emoji: '🇫🇷',
        title: 'France',
        subtitle: 'French news • ${NewsSources.french.length} sources',
        sources: NewsSources.french,
        accentColor: theme.AppColors.frenchBlue,
        onViewAll: widget.onViewFrance,
      ),
      _SectionConfig(
        emoji: '🇮🇷',
        title: 'Iran',
        subtitle: 'Regional news • ${NewsSources.iranian.length} sources',
        sources: NewsSources.iranian,
        accentColor: theme.AppColors.accentPurple, // Replaced with purple
        onViewAll: widget.onViewIran,
      ),
    ];
  }

  // ==================== TOP STORY ====================
  RssItemModel? get _topStory {
    final allItems = [
      ...widget.worldNewsArticles,
      ...widget.tunisianArticles,
      ...widget.moroccanArticles,
      ...widget.algerianArticles,
      ...widget.iranianArticles,
      ...widget.frenchArticles,
    ];
    if (allItems.isEmpty) return null;
    allItems.sort((a, b) => (b.publishedAt ?? DateTime(1970))
        .compareTo(a.publishedAt ?? DateTime(1970)));
    return allItems.first;
  }

  // ==================== NEWS SELECTION ====================
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

  // ==================== TRANSLATION ====================
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

  // ✅ Replaced AppFonts.containsArabic with built-in RegExp
  bool _containsArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  String _formatMixedText(String text) {
    if (_currentLangMode != 'arabic') return text;
    final words = text.split(' ');
    final buffer = StringBuffer();
    for (var word in words) {
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
      if (cleanWord.isNotEmpty && !_containsArabic(cleanWord)) {
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

  String _getDisplaySource(RssItemModel article) {
    return SourceExtractor.extractSource(article.source, article.link);
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
    bool isSourceArabic = _containsArabic(text);

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

  // ==================== URL LAUNCHER ====================
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

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // 1. Clean Top Story Header
        SliverToBoxAdapter(
          child: DashboardHeader(
            topArticle: _topStory,
            getDisplayTitle: _getDisplayTitle,
            getDisplaySource: _getDisplaySource,
            onLaunchUrl: _launchUrl,
          ),
        ),

        // 2. Categories & Language Toggle
        SliverToBoxAdapter(
          child: QuickStatsRow(
            selectedIndex: _selectedCategoryIndex,
            onCategoryTap: (index) {
              setState(() => _selectedCategoryIndex = index);
              final viewCallbacks = [
                widget.onViewWorldNews,
                widget.onViewTunisia,
                widget.onViewMorocco,
                widget.onViewAlgeria,
                widget.onViewFrance,
                widget.onViewIran
              ];
              viewCallbacks[index]();
            },
            currentLangMode: _currentLangMode,
            onToggleLanguage: _toggleLanguage,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // 3. The Journal Sections
        ..._sections.map((section) => SliverToBoxAdapter(
              child: NewsSectionBlock(
                emoji: section.emoji,
                title: section.title,
                subtitle: section.subtitle,
                articles: _getArticlesForSection(section.title),
                onViewAll: section.onViewAll,
                accentColor: section.accentColor,
                isLoading: widget.isLoading,
                hasAnyArticles: widget.totalArticles > 0,
                currentLangMode: _currentLangMode,
                getDisplayTitle: _getDisplayTitle,
                getDisplaySource: _getDisplaySource,
                onLaunchUrl: _launchUrl,
              ),
            )),

        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }
}
