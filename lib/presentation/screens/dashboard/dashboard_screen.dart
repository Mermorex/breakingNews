import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:news_app/core/utils/responsive.dart';
import 'package:news_app/data/models/rss_item_model.dart';
import 'package:url_launcher/url_launcher.dart';

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
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isArabicContent = false;
  final Map<String, String> _translationCache = {};

  static const Color cryptoDarkBg = Color(0xFF0B0E14);
  static const Color cryptoCardBg = Color(0xFF151A25);
  static const Color cryptoOrange = Color(0xFFFF8C00);
  static const Color cryptoGold = Color(0xFFFFD700);

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

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildCompactStatsHeader()),
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

  // --- HEADER (Responsive) ---
  Widget _buildCompactStatsHeader() {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      margin:
          EdgeInsets.fromLTRB(isMobile ? 16 : 32, 24, isMobile ? 16 : 32, 16),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [cryptoOrange, cryptoGold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
        boxShadow: [
          BoxShadow(
            color: cryptoOrange.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LIVE FEED',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.9),
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.totalArticles} Articles',
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
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickStat('🇹🇳', widget.tunisianCount),
                    _buildQuickStat('🇲🇦', widget.moroccanCount),
                    _buildQuickStat('🇩🇿', widget.algerianCount),
                    _buildQuickStat('🇮🇷', widget.iranianCount),
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
                        'LIVE FEED',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.totalArticles} Articles',
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildLangToggle(),
                Row(
                  children: [
                    _buildQuickStat('🇹🇳', widget.tunisianCount),
                    _buildQuickStat('🇲🇦', widget.moroccanCount),
                    _buildQuickStat('🇩🇿', widget.algerianCount),
                    _buildQuickStat('🇮🇷', widget.iranianCount),
                  ],
                ),
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

  Widget _buildQuickStat(String emoji, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            count.toString(),
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION BUILDER (Responsive) ---
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
                    borderRadius: BorderRadius.circular(16),
                  ),
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
            if (articles.isNotEmpty)
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
                            articles.first, fallbackSource),
                      ),
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
            border: Border.all(color: cryptoOrange.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('View All',
                  style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cryptoOrange)),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, size: 14, color: cryptoOrange),
            ],
          ),
        ),
      ),
    );
  }

  // --- CARDS ---

  Widget _buildMainArticleCard(RssItemModel article, String fallbackSource) {
    final bool hasArabicContent = _containsArabic(article.title);
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
        // ✅ FIX: Increased mobile height to 280 to prevent overflow
        height: isMobile ? 280 : 320,
        decoration: BoxDecoration(
          color: cryptoCardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cryptoOrange.withOpacity(0.2)),
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
                        gradient: LinearGradient(colors: [
                      cryptoOrange,
                      cryptoGold.withOpacity(0.5)
                    ]))),
              ),
              Padding(
                // ✅ FIX: Slightly reduced padding on mobile for more text space
                padding: EdgeInsets.all(isMobile ? 20.0 : 24.0),
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
                              color: cryptoOrange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(displaySource.toUpperCase(),
                              style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: cryptoOrange)),
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
                        future:
                            _getProcessedTitle(article.title, hasArabicContent),
                        builder: (context, snapshot) {
                          final text = snapshot.data ?? article.title;
                          return Text(text,
                              style: _getTextStyle(
                                  useArabicStyle,
                                  TextStyle(
                                      fontSize: isMobile
                                          ? 18
                                          : 20, // Slightly smaller on mobile
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1.4)),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              textAlign: useArabicStyle
                                  ? TextAlign.right
                                  : TextAlign.left);
                        }),
                    const SizedBox(height: 12),
                    Text(_getSnippet(article.description),
                        style: _getTextStyle(
                            useArabicStyle,
                            TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.6),
                                height: 1.5)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign:
                            useArabicStyle ? TextAlign.right : TextAlign.left),
                    const SizedBox(height: 16),
                    Align(
                        alignment: useArabicStyle
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: cryptoOrange.withOpacity(0.15),
                                shape: BoxShape.circle),
                            child: Icon(Icons.arrow_outward_rounded,
                                color: cryptoOrange, size: 18))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSideArticleCard(RssItemModel article, String fallbackSource) {
    final bool hasArabicContent = _containsArabic(article.title);
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
        // ✅ FIX: Increased mobile height from 120 to 150 to prevent the 2px overflow
        height: isMobile ? 150 : 152,
        decoration: BoxDecoration(
          color: cryptoCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cryptoGold.withOpacity(0.1)),
        ),
        child: Padding(
          // ✅ FIX: Reduced mobile padding to 16 to optimize space
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
              FutureBuilder<String>(
                  future: _getProcessedTitle(article.title, hasArabicContent),
                  builder: (context, snapshot) {
                    final text = snapshot.data ?? article.title;
                    return Text(text,
                        style: _getTextStyle(
                            useArabicStyle,
                            TextStyle(
                                fontSize: isMobile
                                    ? 13
                                    : 14, // Slightly smaller on mobile
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                height: 1.4)),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign:
                            useArabicStyle ? TextAlign.right : TextAlign.left);
                  }),
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

  Widget _buildEmptyState() {
    return Container(
        height: 200,
        decoration: BoxDecoration(
            color: cryptoCardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cryptoOrange.withOpacity(0.1))),
        child: Center(
            child: Text('No articles found',
                style: GoogleFonts.montserrat(color: Colors.white38))));
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return 'Just now';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
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
