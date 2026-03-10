import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:news_app/core/constants/dashboard_constants.dart'; // Import Constants
import 'package:news_app/core/utils/responsive.dart';
import 'package:news_app/data/datasources/rss_remote_datasource.dart';
import 'package:news_app/data/models/rss_item_model.dart';
import 'package:news_app/data/models/news_source.dart';
import 'package:news_app/presentation/screens/source_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class InternationalNewsTheme {
  static const Color cryptoDarkBg = Color(0xFF0B0E14);
  static const Color cryptoCardBg = Color(0xFF151A25);
  static const Color cryptoOrange = Color(0xFFFF8C00);
  static const Color cryptoGold = Color(0xFFFFD700);
  static const Color textGrey = Color(0xFF6E7681);
}

class InternationalNewsScreen extends StatefulWidget {
  final bool isEmbedded;

  const InternationalNewsScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<InternationalNewsScreen> createState() =>
      _InternationalNewsScreenState();
}

class _InternationalNewsScreenState extends State<InternationalNewsScreen> {
  final RssRemoteDataSource _dataSource = RssRemoteDataSource();

  // ✅ UPDATED: Get sources directly from Constants
  List<NewsSource> get _rssSources =>
      DashboardConstants.allInternationalSources;

  final Map<int, List<RssItemModel>> _dashboardData = {};
  final Set<int> _loadingIndices = {};
  bool _isGlobalLoading = true;
  final Map<String, String> _sourceErrors = {};

  bool _isArabicContent = false;
  final Map<String, String> _translationCache = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isGlobalLoading = true;
      _sourceErrors.clear();
      _loadingIndices.clear();
      _dashboardData.clear();
    });

    final fetchTasks = _rssSources.asMap().entries.map((entry) {
      return _fetchSource(entry.key, entry.value);
    }).toList();

    Future.wait(fetchTasks).then((_) {
      if (mounted) setState(() => _isGlobalLoading = false);
    });
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

  void _toggleLanguage() {
    setState(() {
      _isArabicContent = !_isArabicContent;
    });
  }

  Future<String> _translateText(String text, {bool toArabic = true}) async {
    if (text.isEmpty) return text;
    final cacheKey = '$text-$toArabic';
    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!;
    }

    try {
      final langPair = toArabic ? 'en|ar' : 'ar|en';
      final url =
          'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(text)}&langpair=$langPair';
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['responseStatus'] == 200) {
          final translated = data['responseData']['translatedText'] ?? text;
          _translationCache[cacheKey] = translated;
          return translated;
        }
      }
    } catch (e) {
      debugPrint('Translation failed: $e');
    }
    return text;
  }

  Future<String> _getProcessedTitle(
      String originalTitle, bool isContentArabic) async {
    if (_isArabicContent && !isContentArabic) {
      return _translateText(originalTitle, toArabic: true);
    }
    if (!_isArabicContent && isContentArabic) {
      return _translateText(originalTitle, toArabic: false);
    }
    return originalTitle;
  }

  Future<void> _openArticle(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(
        url.trim().startsWith('http') ? url.trim() : 'https://${url.trim()}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (widget.isEmbedded) return content;

    return Scaffold(
      backgroundColor: InternationalNewsTheme.cryptoDarkBg,
      appBar: AppBar(
        backgroundColor: InternationalNewsTheme.cryptoDarkBg,
        elevation: 0,
        title: Text(
          'Global Feed',
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
                color: InternationalNewsTheme.cryptoOrange),
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

  // --- HEADER (Responsive) ---
  Widget _buildStatusHeader() {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      margin:
          EdgeInsets.fromLTRB(isMobile ? 16 : 32, 24, isMobile ? 16 : 32, 16),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            InternationalNewsTheme.cryptoOrange,
            InternationalNewsTheme.cryptoGold
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
        boxShadow: [
          BoxShadow(
            color: InternationalNewsTheme.cryptoOrange.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GLOBAL COVERAGE',
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildLangToggle(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSourceCountBadge(),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GLOBAL COVERAGE',
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
                _buildSourceCountBadge(),
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
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.translate, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                _isArabicContent ? 'AR' : 'EN',
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

  Widget _buildSourceCountBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }

  // --- SECTION (Responsive) ---
  Widget _buildSection({
    required NewsSource source,
    required List<RssItemModel> items,
    required bool isLoading,
    required bool hasError,
  }) {
    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(source.name);
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
                    gradient: const LinearGradient(colors: [
                      InternationalNewsTheme.cryptoOrange,
                      InternationalNewsTheme.cryptoGold
                    ]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(isArabic ? '🌍' : '📰',
                      style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.name,
                        style: (isArabic
                                ? GoogleFonts.notoKufiArabic()
                                : GoogleFonts.montserrat())
                            .copyWith(
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
                          gradient: const LinearGradient(colors: [
                            InternationalNewsTheme.cryptoOrange,
                            InternationalNewsTheme.cryptoGold
                          ]),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                    ],
                  ),
                ),
                if (items.isNotEmpty && !isLoading && !hasError)
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SourceDetailScreen(
                            sourceName: source.name,
                            sourceUrl: source.url.trim(),
                            sourceType: source.type,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: InternationalNewsTheme.cryptoOrange
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: InternationalNewsTheme.cryptoOrange
                                .withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View All',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: InternationalNewsTheme.cryptoOrange,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded,
                              size: 14,
                              color: InternationalNewsTheme.cryptoOrange),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (isLoading && items.isEmpty)
              _buildLoadingPlaceholder()
            else if (items.isNotEmpty)
              // ✅ RESPONSIVE GRID LOGIC
              LayoutBuilder(
                builder: (context, constraints) {
                  // Use Column for Mobile, Row for Desktop/Tablet
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

  Widget _buildLoadingPlaceholder() {
    return Container(
      height: 340,
      decoration: BoxDecoration(
        color: InternationalNewsTheme.cryptoCardBg,
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
                color: InternationalNewsTheme.cryptoOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                    InternationalNewsTheme.cryptoOrange),
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

  // --- CARDS (Responsive) ---

  Widget _buildMainArticleCard(RssItemModel article) {
    final bool hasArabic = _containsArabic(article.title);
    final bool useArabicStyle = _isArabicContent || hasArabic;
    final isMobile = ResponsiveHelper.isMobile(context);

    return GestureDetector(
      onTap: () => _openArticle(article.link),
      child: Container(
        height: isMobile ? 280 : 340, // Responsive height
        decoration: BoxDecoration(
          color: InternationalNewsTheme.cryptoCardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: InternationalNewsTheme.cryptoOrange.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: InternationalNewsTheme.cryptoOrange.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
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
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        InternationalNewsTheme.cryptoOrange,
                        InternationalNewsTheme.cryptoGold.withOpacity(0.5)
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(
                    isMobile ? 20.0 : 24.0), // Responsive padding
                child: Column(
                  crossAxisAlignment: useArabicStyle
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: InternationalNewsTheme.cryptoOrange
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            (article.source ?? 'News').toUpperCase(),
                            style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: InternationalNewsTheme.cryptoOrange),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.access_time_rounded,
                            size: 14, color: Colors.white54),
                        const SizedBox(width: 6),
                        Text(_formatTimeAgo(article.publishedAt),
                            style: GoogleFonts.montserrat(
                                fontSize: 12, color: Colors.white54)),
                      ],
                    ),
                    const Spacer(),
                    FutureBuilder<String>(
                        future: _getProcessedTitle(article.title, hasArabic),
                        builder: (context, snapshot) {
                          final text = snapshot.data ?? article.title;
                          return Text(
                            text,
                            style: _getTextStyle(
                                useArabicStyle,
                                TextStyle(
                                    fontSize:
                                        isMobile ? 18 : 20, // Responsive font
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.4)),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            textAlign: useArabicStyle
                                ? TextAlign.right
                                : TextAlign.left,
                          );
                        }),
                    const SizedBox(height: 12),
                    Text(
                      _getSnippet(article.description),
                      style: _getTextStyle(
                          useArabicStyle,
                          TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.6),
                              height: 1.5)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign:
                          useArabicStyle ? TextAlign.right : TextAlign.left,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: useArabicStyle
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: InternationalNewsTheme.cryptoOrange
                              .withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_outward_rounded,
                            color: InternationalNewsTheme.cryptoOrange,
                            size: 18),
                      ),
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
    final bool hasArabic = _containsArabic(article.title);
    final bool useArabicStyle = _isArabicContent || hasArabic;
    final isMobile = ResponsiveHelper.isMobile(context);

    return GestureDetector(
      onTap: () => _openArticle(article.link),
      child: Container(
        height: isMobile ? 150 : 162, // Responsive height
        decoration: BoxDecoration(
          color: InternationalNewsTheme.cryptoCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: InternationalNewsTheme.cryptoGold.withOpacity(0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      InternationalNewsTheme.cryptoGold.withOpacity(0.5),
                      Colors.transparent
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(
                    isMobile ? 16.0 : 20.0), // Responsive padding
                child: Column(
                  crossAxisAlignment: useArabicStyle
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(_formatTimeAgo(article.publishedAt),
                        style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: InternationalNewsTheme.textGrey)),
                    const SizedBox(height: 8),
                    FutureBuilder<String>(
                        future: _getProcessedTitle(article.title, hasArabic),
                        builder: (context, snapshot) {
                          final text = snapshot.data ?? article.title;
                          return Text(
                            text,
                            style: _getTextStyle(
                                useArabicStyle,
                                TextStyle(
                                    fontSize:
                                        isMobile ? 13 : 14, // Responsive font
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    height: 1.4)),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign: useArabicStyle
                                ? TextAlign.right
                                : TextAlign.left,
                          );
                        }),
                    const Spacer(),
                    Row(
                      children: [
                        Text('Read',
                            style: GoogleFonts.montserrat(
                                fontSize: 10,
                                color: InternationalNewsTheme.cryptoGold
                                    .withOpacity(0.7))),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_right_alt,
                            size: 12,
                            color: InternationalNewsTheme.cryptoGold
                                .withOpacity(0.7)),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyErrorState(bool hasError) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: InternationalNewsTheme.cryptoCardBg,
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

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return 'Just now';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _getSnippet(String? description) {
    if (description == null || description.isEmpty) return '';
    return description
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
