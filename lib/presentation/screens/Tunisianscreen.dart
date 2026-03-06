import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:news_app/data/datasources/rss_remote_datasource.dart';
import 'package:news_app/data/models/rss_item_model.dart';
import 'package:news_app/data/models/news_source.dart';
import 'package:news_app/presentation/screens/source_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class TunisianNewsTheme {
  static const Color cryptoDarkBg = Color(0xFF0B0E14);
  static const Color cryptoCardBg = Color(0xFF151A25);
  static const Color cryptoOrange = Color(0xFFFF8C00);
  static const Color cryptoGold = Color(0xFFFFD700);
  static const Color textGrey = Color(0xFF6E7681);
}

class TunisianNewsScreen extends StatefulWidget {
  final bool isEmbedded;
  const TunisianNewsScreen({super.key, this.isEmbedded = false});

  @override
  State<TunisianNewsScreen> createState() => _TunisianNewsScreenState();
}

class _TunisianNewsScreenState extends State<TunisianNewsScreen> {
  final RssRemoteDataSource _dataSource = RssRemoteDataSource();

  final List<NewsSource> _rssSources = [
    NewsSource(name: 'Mosaïque FM', url: 'https://www.mosaiquefm.net/ar/rss'),
    NewsSource(
        name: 'Jawhara FM',
        url: 'https://www.jawharafm.net/ar/rss/showRss/88/1/1'),
    NewsSource(
        name: 'Express FM', url: 'https://www.radioexpressfm.com/ar/rss'),
    NewsSource(
        name: 'Tunisie Focus',
        url: 'https://www.tunisiefocus.com/category/politique/feed'),
    NewsSource(
        name: 'وزارة الداخلية',
        url: 'https://www.interieur.gov.tn/ar/feed',
        useWebFeed: false),
    NewsSource(name: 'babnet', url: 'https://www.babnet.net/feed.php'),
    NewsSource(
      name: 'التلفزة التونسية',
      url:
          'https://www.tunisiatv.tn/ar/articles/1/693ff922b922dd47f3ea53c3/%D8%A7%D8%AE%D8%A8%D8%A7%D8%B1%D9%86%D8%A7',
      type: SourceType.scrapable,
      selectors: {
        'item': 'article, .article, .news-item, .item, .col-md-4, .col-lg-4',
        'title': 'h3, .title, .article-title, h2, h4',
        'link': 'a[href*="/articles/"], a[href*="/ar/"]',
        'desc': '',
        'date': '.date, time, .published-date',
        'image': 'img, .article-image img',
      },
    ),
    NewsSource(
      name: 'rassdtunisia',
      url: 'https://rassdtunisia.net/category/news',
      type: SourceType.scrapable,
      selectors: {
        'item': 'article, .post, .entry',
        'title': 'h2.entry-title a, h1.entry-title',
        'link': 'h2.entry-title a[href], h1 a[href]',
        'desc': '.entry-summary p, .post-excerpt',
        'date':
            '.entry-date, time.entry-date, .published, .posted-on, .byline, .entry-meta',
        'image': 'img.wp-post-image, .post-thumbnail img',
      },
    ),
  ];

  final Map<int, List<RssItemModel>> _dashboardData = {};

  // ✅ CHANGE 1: Track which sources are currently loading
  final Set<int> _loadingIndices = {};

  bool _isGlobalLoading = true; // Only true for the very first load
  String? _errorMessage;
  final Map<String, String> _sourceErrors = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    // Don't clear data on refresh, just update it
    setState(() {
      _isGlobalLoading = true;
      _errorMessage = null;
      _sourceErrors.clear();
      _loadingIndices.clear();
      _dashboardData.clear();
    });

    // Create fetch tasks
    final fetchTasks = _rssSources.asMap().entries.map((entry) {
      return _fetchSource(entry.key, entry.value);
    }).toList();

    // ✅ CHANGE 2: We don't await Future.wait to block the UI.
    // We let the tasks run in background and update UI individually.
    // We just wait a tiny bit to avoid UI jank, or use a Completer if you need "Refresh" to stop spinning.

    // Start fetching
    Future.wait(fetchTasks).then((_) {
      if (mounted) {
        setState(() {
          _isGlobalLoading = false;
        });
      }
    });
  }

  Future<void> _fetchSource(int index, NewsSource source) async {
    // 1. Mark as loading immediately
    if (mounted) {
      setState(() {
        _loadingIndices.add(index);
      });
    }

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
          useWebFeed: source.useWebFeed,
        );
      }

      // 2. Update UI as soon as data arrives
      if (mounted) {
        setState(() {
          _loadingIndices.remove(index);
          if (items.isNotEmpty) {
            _dashboardData[index] = items;
          } else {
            // If empty, keep loading index removed but maybe set an error?
            // For now, we just show empty state
          }
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

  // ... (keep _openArticle, _showError, _copyLink methods as they were) ...
  Future<void> _openArticle(String url) async {
    if (url.isEmpty) return;
    String cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http')) {
      cleanUrl = 'https://$cleanUrl';
    }

    try {
      final uri = Uri.parse(cleanUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError('Could not open link');
      }
    } catch (e) {
      _showError('Cannot open article: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.montserrat()),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link copied', style: GoogleFonts.montserrat()),
        backgroundColor: TunisianNewsTheme.cryptoOrange,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: TunisianNewsTheme.cryptoDarkBg,
      appBar: AppBar(
        backgroundColor: TunisianNewsTheme.cryptoDarkBg,
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
            icon: const Icon(Icons.refresh_rounded,
                color: TunisianNewsTheme.cryptoOrange),
            // Disable button while global loading is true if desired, or allow refresh anytime
            onPressed: _isGlobalLoading ? null : _loadDashboardData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildContent() {
    // ✅ CHANGE 3: Remove the blocking "Loading..." screen.
    // We build the list immediately. The logic inside _buildSection handles the empty/loading state.
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildStatusHeader()),
        ..._rssSources.asMap().entries.map((entry) {
          final index = entry.key;
          final source = entry.value;
          final items = _dashboardData[index] ?? [];
          // Check if this specific source is loading
          final isLoading = _loadingIndices.contains(index);
          final hasError = _sourceErrors.containsKey(source.name);

          return _buildSection(
            source: source,
            items: items,
            isLoading: isLoading, // Pass loading state
            hasError: hasError,
          );
        }),
        const SliverPadding(padding: EdgeInsets.only(bottom: 60)),
      ],
    );
  }

  // ... (keep _buildStatusHeader) ...
  Widget _buildStatusHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(32, 24, 32, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            TunisianNewsTheme.cryptoOrange,
            TunisianNewsTheme.cryptoGold
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: TunisianNewsTheme.cryptoOrange.withOpacity(0.3),
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
                  'TUNISIA AGGREGATOR',
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
                const Icon(Icons.rss_feed, color: Colors.white, size: 18),
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

  // ✅ UPDATED: Section Builder
  Widget _buildSection({
    required NewsSource source,
    required List<RssItemModel> items,
    required bool isLoading, // New Param
    required bool hasError,
  }) {
    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(source.name);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header (Same as before)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      TunisianNewsTheme.cryptoOrange,
                      TunisianNewsTheme.cryptoGold
                    ]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(isArabic ? '🇹🇳' : '📰',
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
                            TunisianNewsTheme.cryptoOrange,
                            TunisianNewsTheme.cryptoGold
                          ]),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                    ],
                  ),
                ),
                // Show "View All" only if loaded and has items
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
                            selectors: source.selectors,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: TunisianNewsTheme.cryptoOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: TunisianNewsTheme.cryptoOrange
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
                              color: TunisianNewsTheme.cryptoOrange,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded,
                              size: 14, color: TunisianNewsTheme.cryptoOrange),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // ✅ Content Logic
            if (isLoading)
              _buildLoadingPlaceholder() // Show skeleton while loading
            else if (items.isNotEmpty)
              Row(
                // Show Data
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
                        if (items.length > 1) _buildSideArticleCard(items[1]),
                        if (items.length > 2) const SizedBox(height: 16),
                        if (items.length > 2) _buildSideArticleCard(items[2]),
                      ],
                    ),
                  ),
                ],
              )
            else
              _buildEmptyErrorState(hasError), // Show Error/Empty
          ],
        ),
      ),
    );
  }

  // ✅ NEW: A nice loading skeleton
  Widget _buildLoadingPlaceholder() {
    return Container(
      height: 340,
      decoration: BoxDecoration(
        color: TunisianNewsTheme.cryptoCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Simple pulsing animation simulation using opacity
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.3, end: 1.0),
              duration: const Duration(milliseconds: 800),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: TunisianNewsTheme.cryptoOrange.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              },
              onEnd:
                  () {}, // Can loop if needed, but simple static is fine for now
            ),
            const SizedBox(height: 16),
            Text(
              'Fetching Feed...',
              style:
                  GoogleFonts.montserrat(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ... (Keep _buildMainArticleCard, _buildSideArticleCard, _buildEmptyErrorState, _buildLoadingView, etc. as before) ...

  Widget _buildMainArticleCard(RssItemModel article) {
    final sourceName = article.source ?? 'News';
    final bool hasArabic = _containsArabic(article.title);

    return GestureDetector(
      onTap: () => _openArticle(article.link),
      child: Container(
        height: 340,
        decoration: BoxDecoration(
          color: TunisianNewsTheme.cryptoCardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: TunisianNewsTheme.cryptoOrange.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: TunisianNewsTheme.cryptoOrange.withOpacity(0.05),
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
                        TunisianNewsTheme.cryptoOrange,
                        TunisianNewsTheme.cryptoGold.withOpacity(0.5)
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
                            color: TunisianNewsTheme.cryptoOrange
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            sourceName.toUpperCase(),
                            style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: TunisianNewsTheme.cryptoOrange),
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
                          color:
                              TunisianNewsTheme.cryptoOrange.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_outward_rounded,
                            color: TunisianNewsTheme.cryptoOrange, size: 18),
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
    return GestureDetector(
      onTap: () => _openArticle(article.link),
      onLongPress: () => _copyLink(article.link),
      child: Container(
        height: 162,
        decoration: BoxDecoration(
          color: TunisianNewsTheme.cryptoCardBg,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: TunisianNewsTheme.cryptoGold.withOpacity(0.1)),
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
                      TunisianNewsTheme.cryptoGold.withOpacity(0.5),
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
                            fontSize: 11, color: TunisianNewsTheme.textGrey)),
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
                                color: TunisianNewsTheme.cryptoGold
                                    .withOpacity(0.7))),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_right_alt,
                            size: 12,
                            color:
                                TunisianNewsTheme.cryptoGold.withOpacity(0.7)),
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

  // --- HELPERS ---
  Widget _buildEmptyErrorState(bool hasError) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: TunisianNewsTheme.cryptoCardBg,
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
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    return arabicRegex.hasMatch(text);
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
