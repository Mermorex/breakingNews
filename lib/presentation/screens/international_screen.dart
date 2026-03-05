import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:news_app/data/datasources/rss_remote_datasource.dart';
import 'package:news_app/data/models/rss_item_model.dart';
import 'package:news_app/data/models/news_source.dart'; // Import for SourceType
import 'package:news_app/presentation/screens/source_detail_screen.dart';

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

  // Defined sources for International News
  final List<Map<String, String>> _rssSources = [
    // Arabic Sources
    {
      'name': 'Al Jazeera Arabic',
      'url':
          'https://www.aljazeera.net/aljazeerarss/a7c186be-1baa-4bd4-9d80-a84db769f779/73d0e1b4-532f-45ef-b135-bfdff8b8cab9'
    },
    {
      'name': 'Al Jazeera English',
      'url': 'https://www.aljazeera.com/xml/rss/all.xml'
    },
    {'name': 'Al Arabiya', 'url': 'https://www.alarabiya.net/feed/rss2/ar.xml'},
    {'name': 'Sky News Arabia', 'url': 'https://www.skynewsarabia.com/rss'},

    // English Sources
    {'name': 'BBC', 'url': 'http://feeds.bbci.co.uk/news/rss.xml'},
    {
      'name': 'Reuters',
      'url':
          'https://news.google.com/rss/search?q=site%3Areuters.com&hl=en-US&gl=US&ceid=US%3Aen'
    },
    {'name': 'CNN', 'url': 'http://rss.cnn.com/rss/edition.rss'},
    {
      'name': 'NYT',
      'url': 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml'
    },
    {
      'name': 'Washington Post',
      'url': 'https://feeds.washingtonpost.com/rss/world'
    },
    {'name': 'The Guardian', 'url': 'https://www.theguardian.com/world/rss'},
  ];

  final Map<int, List<RssItemModel>> _dashboardData = {};
  bool _isLoading = true;

  // Theme Colors
  static const Color _bgColor = Color(0xFF0B0E14);
  static const Color _cardColor = Color(0xFF151A25);
  static const Color _accentOrange = Color(0xFFFF8C00);
  static const Color _textWhite = Colors.white;
  static const Color _textGrey = Color(0xFF8B95A5);

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  /// ✅ OPTIMIZED: Parallel loading with a global safety timeout
  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    _dashboardData.clear();

    // Create a list of fetch tasks
    final futures = _rssSources.asMap().entries.map((entry) {
      final index = entry.key;
      final source = entry.value;
      final url = source['url']!.trim();

      return _fetchSourceData(index, url, source['name']!);
    }).toList();

    // Wait for all futures with a global timeout (20s max)
    try {
      await Future.wait(futures).timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('⚠️ International News loading timed out: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSourceData(int index, String url, String name) async {
    if (url.isEmpty) return;
    try {
      // Explicitly pass limit and sourceName for debugging
      final items =
          await _dataSource.fetchRssFeed(url, sourceName: name, limit: 3);

      if (mounted && items.isNotEmpty) {
        // Optional: setState here for progressive loading
        // setState(() {
        _dashboardData[index] = items;
        // });
      }
    } catch (e) {
      debugPrint('❌ Error loading $name: $e');
    }
  }

  Future<void> _openArticle(String url) async {
    if (url.isEmpty) return;
    String cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http')) {
      cleanUrl = 'https://$cleanUrl';
    }
    final uri = Uri.parse(cleanUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: Text(
          'International News',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: _textWhite,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _accentOrange),
            onPressed: _isLoading ? null : _loadDashboardData,
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildContent() {
    if (_isLoading && _dashboardData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_accentOrange),
            ),
            const SizedBox(height: 16),
            Text(
              'Connecting to global sources...',
              style: GoogleFonts.montserrat(color: _textGrey),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 2;
        }

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 24,
                  childAspectRatio: 1.1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final source = _rssSources[index];
                    final items = _dashboardData[index] ?? [];
                    return _SourceBlock(
                      sourceName: source['name']!,
                      items: items,
                      sourceIndex: index,
                      onSeeAll: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SourceDetailScreen(
                              sourceName: source['name']!,
                              sourceUrl: source['url']!.trim(),
                              sourceType:
                                  SourceType.rss, // Ensure this enum exists
                            ),
                          ),
                        );
                      },
                      onArticleTap: _openArticle,
                    );
                  },
                  childCount: _rssSources.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// SourceBlock Widget
class _SourceBlock extends StatelessWidget {
  final String sourceName;
  final List<RssItemModel> items;
  final int sourceIndex;
  final VoidCallback onSeeAll;
  final Function(String) onArticleTap;

  const _SourceBlock({
    required this.sourceName,
    required this.items,
    required this.sourceIndex,
    required this.onSeeAll,
    required this.onArticleTap,
  });

  Color _getAccentColor(int index) {
    final colors = [
      const Color(0xFFFF8C00), // Orange
      const Color(0xFFFFD700), // Gold
      const Color(0xFF00A896), // Teal
      const Color(0xFF7B61FF), // Purple
      const Color(0xFF00CED1), // Cyan
      const Color(0xFF20B2AA), // Light Sea Green
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _getAccentColor(sourceIndex);
    final isArabicSource = RegExp(r'[\u0600-\u06FF]').hasMatch(sourceName);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151A25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sourceName,
                    style: (isArabicSource
                            ? GoogleFonts.notoKufiArabic()
                            : GoogleFonts.montserrat())
                        .copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onSeeAll,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: accentColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded,
                              size: 10, color: accentColor),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x1AFFFFFF)),

          // List of Articles
          Expanded(
            child: items.isEmpty
                ? _EmptyBlock(accentColor: accentColor)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) => _NewsCard(
                      item: items[i],
                      accentColor: accentColor,
                      onTap: () => onArticleTap(items[i].link),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// NewsCard Widget (Added Image Support)
class _NewsCard extends StatelessWidget {
  final RssItemModel item;
  final Color accentColor;
  final VoidCallback onTap;

  const _NewsCard({
    required this.item,
    required this.accentColor,
    required this.onTap,
  });

  String _getSnippet(String? description) {
    if (description == null || description.isEmpty) return '';
    final cleanText = description
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleanText.length > 50
        ? '${cleanText.substring(0, 50)}...'
        : cleanText;
  }

  bool _containsArabic(String text) {
    if (text.isEmpty) return false;
    final arabicRegex = RegExp(
        r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return arabicRegex.hasMatch(text);
  }

  TextStyle _getTextStyle(bool isArabic, TextStyle style) {
    if (isArabic) {
      return GoogleFonts.notoKufiArabic(textStyle: style);
    } else {
      return GoogleFonts.montserrat(textStyle: style);
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
    return '${date.day}/${date.month}';
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _containsArabic(item.title);
    final snippet = _getSnippet(item.description);
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1C222E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.03),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Widget
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.publishedAt?.day.toString() ?? '--',
                      style: GoogleFonts.montserrat(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _getMonth(item.publishedAt?.month),
                      style: GoogleFonts.montserrat(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 7,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: isArabic
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title + Snippet
                    Column(
                      crossAxisAlignment: isArabic
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: _getTextStyle(
                              isArabic,
                              const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                height: 1.2,
                              )),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign:
                              isArabic ? TextAlign.right : TextAlign.left,
                        ),
                        const SizedBox(height: 2),
                        if (snippet.isNotEmpty)
                          Text(
                            snippet,
                            style: _getTextStyle(
                                isArabic,
                                const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF8B95A5),
                                  height: 1.2,
                                )),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign:
                                isArabic ? TextAlign.right : TextAlign.left,
                          ),
                      ],
                    ),

                    // Time + Icon
                    Row(
                      mainAxisAlignment: isArabic
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 9, color: Color(0xFF6D7680)),
                        const SizedBox(width: 3),
                        Text(
                          _formatTimeAgo(item.publishedAt),
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            color: const Color(0xFF6D7680),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.open_in_new,
                            size: 9, color: accentColor.withOpacity(0.8)),
                      ],
                    ),
                  ],
                ),
              ),

              // ✅ ADDED: Image Thumbnail support
              if (hasImage) ...[
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    item.imageUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getMonth(int? month) {
    if (month == null) return '';
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    return months[month - 1];
  }
}

class _EmptyBlock extends StatelessWidget {
  final Color accentColor;

  const _EmptyBlock({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rss_feed_outlined,
              size: 32, color: accentColor.withOpacity(0.3)),
          const SizedBox(height: 8),
          Text(
            'No updates',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: const Color(0xFF8B95A5),
            ),
          ),
        ],
      ),
    );
  }
}
