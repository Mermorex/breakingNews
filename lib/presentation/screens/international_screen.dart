import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:news_app/data/datasources/rss_remote_datasource.dart';
import 'package:news_app/data/models/rss_item_model.dart';
import 'package:news_app/data/models/news_source.dart';
import 'package:news_app/presentation/screens/source_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class InternationalNewsTheme {
  // Exact same constants as Tunisian Screen
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

  final List<NewsSource> _rssSources = [
    // Arabic Sources
    NewsSource(
        name: 'Al Jazeera Arabic',
        url:
            'https://www.aljazeera.net/aljazeerarss/a7c186be-1baa-4bd4-9d80-a84db769f779/73d0e1b4-532f-45ef-b135-bfdff8b8cab9'),

    NewsSource(
        name: 'Sky News Arabia', url: 'https://www.skynewsarabia.com/rss'),

    // English Sources
    NewsSource(name: 'BBC World', url: 'http://feeds.bbci.co.uk/news/rss.xml'),
    NewsSource(
        name: 'Reuters',
        url:
            'https://news.google.com/rss/search?q=site%3Areuters.com&hl=en-US&gl=US&ceid=US%3Aen'),
    NewsSource(name: 'CNN', url: 'http://rss.cnn.com/rss/edition.rss'),
    NewsSource(
        name: 'NYT World',
        url: 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml'),
    NewsSource(
        name: 'The Guardian', url: 'https://www.theguardian.com/world/rss'),
  ];

  final Map<int, List<RssItemModel>> _dashboardData = {};

  // ✅ Progressive Loading State
  final Set<int> _loadingIndices = {};
  bool _isGlobalLoading = true;
  final Map<String, String> _sourceErrors = {};

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
        limit: 3, // 1 Main + 2 Side
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
          'Global Feed', // ✅ Orbitron Font
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
        // 1. Header
        SliverToBoxAdapter(child: _buildStatusHeader()),

        // 2. Sections (Vertical List like Tunisian Screen)
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

  // ✅ SAME STATUS HEADER STYLE
  Widget _buildStatusHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(32, 24, 32, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            InternationalNewsTheme.cryptoOrange,
            InternationalNewsTheme.cryptoGold
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: InternationalNewsTheme.cryptoOrange.withOpacity(0.3),
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

  // ✅ SAME SECTION LAYOUT (Asymmetric)
  Widget _buildSection({
    required NewsSource source,
    required List<RssItemModel> items,
    required bool isLoading,
    required bool hasError,
  }) {
    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(source.name);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header (Same Style)
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
                            sourceType: SourceType.rss,
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

            // Asymmetric Content Row
            if (isLoading && items.isEmpty)
              _buildLoadingPlaceholder()
            else if (items.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // MAIN STORY (Left - Big)
                  Expanded(
                    flex: 5,
                    child: _buildMainArticleCard(items.first),
                  ),
                  const SizedBox(width: 20),
                  // SIDE STORIES (Right - Stacked)
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        if (items.length > 1) _buildSideArticleCard(items[1]),
                        if (items.length > 2) const SizedBox(height: 16),
                        if (items.length > 2) _buildSideArticleCard(items[2]),
                      ],
                    ),
                  ),
                ],
              )
            else
              _buildEmptyErrorState(hasError),
          ],
        ),
      ),
    );
  }

  // ✅ SAME LOADING PLACEHOLDER
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

  // ✅ MAIN CARD (Identical to Tunisian)
  Widget _buildMainArticleCard(RssItemModel article) {
    final sourceName = article.source ?? 'News';
    final bool hasArabic = _containsArabic(article.title);

    return GestureDetector(
      onTap: () => _openArticle(article.link),
      child: Container(
        height: 340,
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
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: hasArabic
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Row(
                      textDirection:
                          hasArabic ? TextDirection.rtl : TextDirection.ltr,
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
                            sourceName.toUpperCase(),
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
                    Text(
                      article.title,
                      style: _getTextStyle(
                          hasArabic,
                          const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.4)),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textAlign: hasArabic ? TextAlign.right : TextAlign.left,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getSnippet(article.description),
                      style: _getTextStyle(
                          hasArabic,
                          TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.6),
                              height: 1.5)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: hasArabic ? TextAlign.right : TextAlign.left,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: hasArabic
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

  // ✅ SIDE CARD (Identical to Tunisian)
  Widget _buildSideArticleCard(RssItemModel article) {
    final bool hasArabic = _containsArabic(article.title);
    return GestureDetector(
      onTap: () => _openArticle(article.link),
      child: Container(
        height: 162,
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
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: hasArabic
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(_formatTimeAgo(article.publishedAt),
                        style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: InternationalNewsTheme.textGrey)),
                    const SizedBox(height: 10),
                    Text(
                      article.title,
                      style: _getTextStyle(
                          hasArabic,
                          const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.4)),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: hasArabic ? TextAlign.right : TextAlign.left,
                    ),
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

  // --- HELPERS (Identical) ---
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
