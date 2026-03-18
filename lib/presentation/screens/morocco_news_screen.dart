import 'dart:async';
import 'dart:convert';
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

class MoroccanNewsTheme {
  static const Color cryptoDarkBg = Color(0xFF0B0E14);
  static const Color cryptoCardBg = Color(0xFF151A25);
  static const Color cryptoOrange = Color(0xFFFF8C00);
  static const Color cryptoGold = Color(0xFFFFD700);
  static const Color textGrey = Color(0xFF6E7681);
}

class MoroccoNewsScreen extends StatefulWidget {
  final bool isEmbedded;

  const MoroccoNewsScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<MoroccoNewsScreen> createState() => _MoroccoNewsScreenState();
}

class _MoroccoNewsScreenState extends State<MoroccoNewsScreen> {
  final RssRemoteDataSource _dataSource = RssRemoteDataSource();

  final List<NewsSource> _rssSources = [
    NewsSource(
        name: 'Aujourd\'hui le Maroc', url: 'https://aujourdhui.ma/feed'),
    NewsSource(name: 'La Vie Eco', url: 'https://lavieeco.com/feed'),
    NewsSource(name: 'Hespress', url: 'https://www.hespress.com/feed'),
    NewsSource(name: 'Akhbarona', url: 'https://akhbarona.com/feed/index.rss'),
    NewsSource(
        name: 'Morocco World News',
        url: 'https://www.moroccoworldnews.com/feed/'),
  ];

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
      setState(() {
        _isGlobalLoading = false;
      });
    }
  }

  Future<void> _fetchSource(int index, NewsSource source) async {
    if (mounted) setState(() => _loadingIndices.add(index));

    try {
      final items = await _dataSource.fetchRssFeed(
        source.url,
        sourceName: source.name,
        limit: 3,
      );

      if (mounted) {
        setState(() {
          _loadingIndices.remove(index);
          if (items.isNotEmpty) _dashboardData[index] = items;
        });
      }
    } catch (e) {
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

      final recentArticles = allArticles.take(50).toList();

      final StringBuffer contextBuffer = StringBuffer();
      contextBuffer.writeln(
          'Morocco News Summary - ${intl.DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now())}\n');

      for (int i = 0; i < recentArticles.length; i++) {
        final article = recentArticles[i];
        contextBuffer.writeln('${i + 1}. ${article.title}');
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
      final String topicName = isArabic ? "المغرب" : "Morocco";

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
          _dailyRecap = "Error generating summary.";
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

  Future<void> _openArticle(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(
        url.trim().startsWith('http') ? url.trim() : 'https://${url.trim()}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  TextStyle _getTextStyle(bool isArabic, TextStyle style) {
    if (isArabic) {
      return GoogleFonts.notoKufiArabic(textStyle: style);
    } else {
      return GoogleFonts.montserrat(textStyle: style);
    }
  }

  bool _containsArabic(String text) {
    if (text.isEmpty) return false;
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  bool get _isArabicContent => _currentLangMode == 'arabic';

  // --- BUILD ---

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (widget.isEmbedded) return content;

    return Scaffold(
      backgroundColor: MoroccanNewsTheme.cryptoDarkBg,
      appBar: AppBar(
        backgroundColor: MoroccanNewsTheme.cryptoDarkBg,
        elevation: 0,
        title: Text(
          'Morocco Feed',
          style: GoogleFonts.orbitron(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_sourceErrors.isNotEmpty)
            const Tooltip(
              message: 'Some sources failed',
              child: Icon(Icons.warning_amber_rounded, color: Colors.orange),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: MoroccanNewsTheme.cryptoOrange),
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
        if (_showDailyRecap) _buildDailyRecapSection(),
        SliverToBoxAdapter(child: _buildStatusHeader()),
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
    final bool isDisabled = _isGlobalLoading || _dashboardData.isEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(32, 0, 32, 24),
      decoration: BoxDecoration(
        color: MoroccanNewsTheme.cryptoCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
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
                          : [Colors.green, Colors.lightGreen],
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
                          color: MoroccanNewsTheme.textGrey,
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
                      color: Colors.green,
                      strokeWidth: 2,
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: isDisabled ? Colors.white24 : Colors.green,
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
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(32, 24, 32, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.withOpacity(0.2),
              Colors.lightGreen.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.green.withOpacity(0.3),
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
                  colors: [Colors.green, Colors.lightGreen],
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
                              ? 'ملخص أخبار المغرب'
                              : 'Morocco News Recap',
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
              padding: const EdgeInsets.all(24.0),
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
                color: Colors.green,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isArabicContent ? 'جاري تحليل الأخبار...' : 'Analyzing news...',
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
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.green.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.psychology,
                size: 16,
                color: Colors.lightGreen[200],
              ),
              const SizedBox(width: 6),
              Text(
                'AI Generated',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.lightGreen[200],
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
          child: Text.rich(
            _parseRecapMarkdown(
              _dailyRecap ?? '',
              isArabic: isArabic,
              baseStyle: TextStyle(
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

  TextSpan _parseRecapMarkdown(String text,
      {required bool isArabic, required TextStyle baseStyle}) {
    final children = <TextSpan>[];
    final regExp = RegExp(r'\*\*(.*?)\*\*');
    int lastIndex = 0;

    for (final match in regExp.allMatches(text)) {
      if (match.start > lastIndex) {
        children.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: _getTextStyle(isArabic, baseStyle),
        ));
      }
      children.add(TextSpan(
        text: match.group(1),
        style: _getTextStyle(
            isArabic, baseStyle.copyWith(fontWeight: FontWeight.bold)),
      ));
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      children.add(TextSpan(
        text: text.substring(lastIndex),
        style: _getTextStyle(isArabic, baseStyle),
      ));
    }

    return TextSpan(children: children);
  }

  Widget _buildStatusHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(32, 24, 32, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            MoroccanNewsTheme.cryptoOrange,
            MoroccanNewsTheme.cryptoGold
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: MoroccanNewsTheme.cryptoOrange.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MOROCCO INSIGHT',
                  style: GoogleFonts.robotoMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.9),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_rssSources.length} Active Sources',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          _buildLangToggle(),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.public, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${_dashboardData.length}',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                displayText,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SECTION & CARDS ---

  Widget _buildSection({
    required NewsSource source,
    required List<RssItemModel> items,
    required bool isLoading,
    required bool hasError,
  }) {
    final isSourceArabic = _containsArabic(source.name);
    final isMobile = ResponsiveHelper.isMobile(context);

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
                    gradient: const LinearGradient(colors: [
                      MoroccanNewsTheme.cryptoOrange,
                      MoroccanNewsTheme.cryptoGold
                    ]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('🇲🇦', style: TextStyle(fontSize: 22)),
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
                          gradient: const LinearGradient(colors: [
                            MoroccanNewsTheme.cryptoOrange,
                            MoroccanNewsTheme.cryptoGold
                          ]),
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
                        ...items.skip(1).take(2).map((item) => Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: _buildSideArticleCard(item),
                            )),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildMainArticleCard(items.first),
                      ),
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
                sourceType: SourceType.rss,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: MoroccanNewsTheme.cryptoOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: MoroccanNewsTheme.cryptoOrange.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View All',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MoroccanNewsTheme.cryptoOrange,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded,
                  size: 14, color: MoroccanNewsTheme.cryptoOrange),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      height: 340,
      decoration: BoxDecoration(
        color: MoroccanNewsTheme.cryptoCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MoroccanNewsTheme.cryptoOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                    MoroccanNewsTheme.cryptoOrange),
              ),
            ),
            const SizedBox(height: 16),
            Text('Fetching Feed...',
                style: GoogleFonts.montserrat(
                    color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyErrorState(bool hasError) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: MoroccanNewsTheme.cryptoCardBg,
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

  // --- UPDATED: Card Builders using Private StatefulWidgets ---

  Widget _buildMainArticleCard(RssItemModel article) {
    return _MoroccanMainArticleCard(
      article: article,
      isArabic: _isArabicContent,
      getDisplayTitle: _getDisplayTitle,
      containsArabic: _containsArabic,
      getTextStyle: _getTextStyle,
    );
  }

  Widget _buildSideArticleCard(RssItemModel article) {
    return _MoroccanSideArticleCard(
      article: article,
      isArabic: _isArabicContent,
      getDisplayTitle: _getDisplayTitle,
      containsArabic: _containsArabic,
      getTextStyle: _getTextStyle,
    );
  }
}

// --- PRIVATE STATEFUL WIDGETS FOR CARDS ---

class _MoroccanMainArticleCard extends StatefulWidget {
  final RssItemModel article;
  final bool isArabic;
  final Future<String> Function(RssItemModel) getDisplayTitle;
  final bool Function(String) containsArabic;
  final TextStyle Function(bool, TextStyle) getTextStyle;

  const _MoroccanMainArticleCard({
    required this.article,
    required this.isArabic,
    required this.getDisplayTitle,
    required this.containsArabic,
    required this.getTextStyle,
  });

  @override
  State<_MoroccanMainArticleCard> createState() =>
      _MoroccanMainArticleCardState();
}

class _MoroccanMainArticleCardState extends State<_MoroccanMainArticleCard>
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

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url.trim());
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final bool useArabicStyle =
        widget.isArabic || widget.containsArabic(widget.article.title);

    return GestureDetector(
      onTap: () => _launchUrl(widget.article.link),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _isExpanded ? (isMobile ? 420 : 460) : (isMobile ? 280 : 340),
        decoration: BoxDecoration(
            color: MoroccanNewsTheme.cryptoCardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: MoroccanNewsTheme.cryptoOrange.withOpacity(0.2))),
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
                        MoroccanNewsTheme.cryptoOrange,
                        MoroccanNewsTheme.cryptoGold.withOpacity(0.5)
                      ])))),
              Padding(
                padding: EdgeInsets.all(isMobile ? 20.0 : 24.0),
                child: Column(
                  crossAxisAlignment: useArabicStyle
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: MoroccanNewsTheme.cryptoOrange
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(
                              (widget.article.source ?? 'News').toUpperCase(),
                              style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: MoroccanNewsTheme.cryptoOrange))),
                      const Spacer(),
                      Icon(Icons.access_time_rounded,
                          size: 14, color: Colors.white54),
                      const SizedBox(width: 6),
                      Text(_formatTimeAgo(widget.article.publishedAt),
                          style: GoogleFonts.montserrat(
                              fontSize: 12, color: Colors.white54)),
                    ]),
                    const SizedBox(height: 12),
                    FutureBuilder<String>(
                        future: widget.getDisplayTitle(widget.article),
                        builder: (context, snapshot) {
                          final text = snapshot.data ?? widget.article.title;
                          final isArabic = widget.containsArabic(text);
                          return Text(text,
                              style: widget.getTextStyle(
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
                                          strokeWidth: 2,
                                          color: MoroccanNewsTheme.cryptoGold)))
                              : Text(_summary ?? "Unable to generate summary.",
                                  style: widget.getTextStyle(
                                      useArabicStyle,
                                      TextStyle(
                                          fontSize: 13,
                                          color: MoroccanNewsTheme.cryptoGold
                                              .withOpacity(0.9),
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
                                                : [
                                                    MoroccanNewsTheme
                                                        .cryptoGold,
                                                    MoroccanNewsTheme
                                                        .cryptoOrange
                                                  ]),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                              color: (_isExpanded
                                                      ? Colors.purple
                                                      : MoroccanNewsTheme
                                                          .cryptoOrange)
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

class _MoroccanSideArticleCard extends StatefulWidget {
  final RssItemModel article;
  final bool isArabic;
  final Future<String> Function(RssItemModel) getDisplayTitle;
  final bool Function(String) containsArabic;
  final TextStyle Function(bool, TextStyle) getTextStyle;

  const _MoroccanSideArticleCard({
    required this.article,
    required this.isArabic,
    required this.getDisplayTitle,
    required this.containsArabic,
    required this.getTextStyle,
  });

  @override
  State<_MoroccanSideArticleCard> createState() =>
      _MoroccanSideArticleCardState();
}

class _MoroccanSideArticleCardState extends State<_MoroccanSideArticleCard>
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

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url.trim());
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final bool useArabicStyle =
        widget.isArabic || widget.containsArabic(widget.article.title);
    final isMobile = ResponsiveHelper.isMobile(context);

    return GestureDetector(
      onTap: () => _launchUrl(widget.article.link),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _isExpanded ? (isMobile ? 380 : 400) : (isMobile ? 150 : 162),
        decoration: BoxDecoration(
            color: MoroccanNewsTheme.cryptoCardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: MoroccanNewsTheme.cryptoGold.withOpacity(0.1))),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 20.0),
          child: Column(
            crossAxisAlignment: useArabicStyle
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(_formatTimeAgo(widget.article.publishedAt),
                  style: GoogleFonts.montserrat(
                      fontSize: 11, color: MoroccanNewsTheme.textGrey)),
              const SizedBox(height: 8),
              FutureBuilder<String>(
                  future: widget.getDisplayTitle(widget.article),
                  builder: (context, snapshot) {
                    final text = snapshot.data ?? widget.article.title;
                    final isArabic = widget.containsArabic(text);
                    return Text(text,
                        style: widget.getTextStyle(
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
                                    strokeWidth: 1.5,
                                    color: MoroccanNewsTheme.cryptoGold)))
                        : Text(
                            _summary ?? "Unable to generate summary.",
                            style: widget.getTextStyle(
                                useArabicStyle,
                                TextStyle(
                                    fontSize: 12,
                                    color: MoroccanNewsTheme.cryptoGold
                                        .withOpacity(0.9),
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
                        size: 16,
                        color: MoroccanNewsTheme.cryptoGold.withOpacity(0.5)),
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
                                        MoroccanNewsTheme.cryptoGold
                                            .withOpacity(0.8),
                                        MoroccanNewsTheme.cryptoOrange
                                            .withOpacity(0.8)
                                      ]),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: (_isExpanded
                                          ? Colors.purple
                                          : MoroccanNewsTheme.cryptoOrange)
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
}
