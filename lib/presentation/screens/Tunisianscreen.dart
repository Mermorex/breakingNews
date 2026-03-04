// lib/presentation/screens/tunisian_news_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:news_app/data/datasources/rss_remote_datasource.dart';
import 'package:news_app/data/models/rss_item_model.dart';
import 'package:news_app/data/models/news_source.dart';
import 'package:news_app/presentation/screens/source_detail_screen.dart';

// Public constants for use across all widgets in this file
class TunisianNewsTheme {
  static const Color bgColor = Color(0xFF0B0E14);
  static const Color cardColor = Color(0xFF151A25);
  static const Color accentOrange = Color(0xFFFF8C00);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color textWhite = Colors.white;
  static const Color textGrey = Color(0xFF8B95A5);
}

class TunisianNewsScreen extends StatefulWidget {
  final bool isEmbedded;

  const TunisianNewsScreen({
    super.key,
    this.isEmbedded = false,
  });

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
        name: 'France 24', url: 'https://www.france24.com/fr/tag/tunisie/rss'),
    NewsSource(
        name: 'Express FM', url: 'https://www.radioexpressfm.com/ar/rss'),
    NewsSource(
        name: 'Tunisie Focus',
        url: 'https://www.tunisiefocus.com/category/politique/feed'),
    NewsSource(name: 'Al Chourouk', url: 'https://www.alchourouk.com/rss'),
    NewsSource(
        name: 'وزارة الداخلية',
        url: 'https://www.interieur.gov.tn/ar/feed',
        useWebFeed: false),
    NewsSource(
        name: 'Business News', url: 'https://www.businessnews.com.tn/feed'),
    NewsSource(
      name: 'الصحافة اليوم',
      url: 'https://essahafa.tn/category/أخبار-تونس/',
      type: SourceType.scrapable, // MUST be scrapable, not rss
      selectors: {
        'item': 'a[href*="/20"]',
      },
    ),
  ];

  final Map<int, List<RssItemModel>> _dashboardData = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _dashboardData.clear();

    final futures = _rssSources.asMap().entries.map((entry) async {
      final index = entry.key;
      final source = entry.value;
      final cleanUrl = source.url.trim();

      if (cleanUrl.isEmpty || cleanUrl.contains('placeholder')) {
        return {index: <RssItemModel>[]};
      }

      try {
        List<RssItemModel> items;

        if (source.type == SourceType.rss) {
          items = await _dataSource.fetchRssFeed(
            cleanUrl,
            sourceName: source.name,
            limit: 3,
            useWebFeed: source.useWebFeed,
          );
        } else {
          items = await _dataSource.scrapeWebsite(
            cleanUrl,
            source.selectors!,
            sourceName: source.name,
            limit: 3,
          );
        }

        return {index: items};
      } catch (e) {
        debugPrint('Error loading ${source.name}: $e');
        return {index: <RssItemModel>[]};
      }
    });

    try {
      final results = await Future.wait(futures);

      for (var map in results) {
        _dashboardData.addAll(map);
      }

      final totalItems = _dashboardData.values
          .fold<int>(0, (sum, items) => sum + items.length);
      if (totalItems == 0 && _rssSources.isNotEmpty) {
        _errorMessage =
            'Unable to load news. Please check your internet connection.';
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load news: $e';
        });
      }
    }
  }

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
        _showError('Cannot open link');
      }
    } catch (e) {
      _showError('Invalid link format');
    }
  }

  void _showError(String message) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link copied', style: GoogleFonts.montserrat()),
        backgroundColor: TunisianNewsTheme.accentOrange,
        duration: Duration(seconds: 1),
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
      backgroundColor: TunisianNewsTheme.bgColor,
      appBar: AppBar(
        backgroundColor: TunisianNewsTheme.bgColor,
        elevation: 0,
        title: Text(
          'Tunisian News',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: TunisianNewsTheme.textWhite,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: TunisianNewsTheme.accentOrange),
            onPressed: _isLoading ? null : _loadDashboardData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(TunisianNewsTheme.accentOrange),
            ),
            SizedBox(height: 16),
            Text(
              'Loading news...',
              style: GoogleFonts.montserrat(color: TunisianNewsTheme.textGrey),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: GoogleFonts.montserrat(color: TunisianNewsTheme.textGrey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDashboardData,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: TunisianNewsTheme.accentOrange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        double childAspectRatio = 1.1;

        if (constraints.maxWidth > 1400) {
          crossAxisCount = 4;
          childAspectRatio = 1.2;
        } else if (constraints.maxWidth > 1200) {
          crossAxisCount = 3;
          childAspectRatio = 1.1;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 2;
          childAspectRatio = 1.0;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 2;
          childAspectRatio = 0.9;
        }

        return RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: TunisianNewsTheme.accentOrange,
          backgroundColor: TunisianNewsTheme.cardColor,
          child: CustomScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 24,
                    childAspectRatio: childAspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final source = _rssSources[index];
                      final items = _dashboardData[index] ?? [];
                      return SourceBlock(
                        sourceName: source.name,
                        items: items,
                        sourceIndex: index,
                        onSeeAll: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SourceDetailScreen(
                                sourceName: source.name,
                                sourceUrl: source.url.trim(),
                              ),
                            ),
                          );
                        },
                        onArticleTap: _openArticle,
                        onArticleLongPress: _copyLink,
                      );
                    },
                    childCount: _rssSources.length,
                  ),
                ),
              ),
              SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          ),
        );
      },
    );
  }
}

class SourceBlock extends StatelessWidget {
  final String sourceName;
  final List<RssItemModel> items;
  final int sourceIndex;
  final VoidCallback onSeeAll;
  final Function(String) onArticleTap;
  final Function(String) onArticleLongPress;

  const SourceBlock({
    super.key,
    required this.sourceName,
    required this.items,
    required this.sourceIndex,
    required this.onSeeAll,
    required this.onArticleTap,
    required this.onArticleLongPress,
  });

  Color _getAccentColor(int index) {
    final colors = [
      const Color(0xFFFF8C00),
      const Color(0xFFFFD700),
      const Color(0xFFE74C3C),
      const Color(0xFF3498DB),
      const Color(0xFF9B59B6),
      const Color(0xFF006233),
      const Color(0xFF1ABC9C),
      const Color(0xFFE67E22),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _getAccentColor(sourceIndex);
    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(sourceName);
    final hasItems = items.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: TunisianNewsTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    style: (isArabic
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
                if (hasItems)
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
                          border:
                              Border.all(color: accentColor.withOpacity(0.3)),
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
          Expanded(
            child: !hasItems
                ? EmptyBlock(accentColor: accentColor, sourceName: sourceName)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) => NewsCard(
                      item: items[i],
                      accentColor: accentColor,
                      onTap: () => onArticleTap(items[i].link),
                      onLongPress: () => onArticleLongPress(items[i].link),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class NewsCard extends StatelessWidget {
  final RssItemModel item;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const NewsCard({
    super.key,
    required this.item,
    required this.accentColor,
    required this.onTap,
    required this.onLongPress,
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
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF1C222E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.03),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Expanded(
                child: Column(
                  crossAxisAlignment: isArabic
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: isArabic
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: (isArabic
                                  ? GoogleFonts.notoKufiArabic()
                                  : GoogleFonts.montserrat())
                              .copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign:
                              isArabic ? TextAlign.right : TextAlign.left,
                        ),
                        const SizedBox(height: 2),
                        if (snippet.isNotEmpty)
                          Text(
                            snippet,
                            style: (isArabic
                                    ? GoogleFonts.notoKufiArabic()
                                    : GoogleFonts.montserrat())
                                .copyWith(
                              fontSize: 10,
                              color: const Color(0xFF8B95A5),
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign:
                                isArabic ? TextAlign.right : TextAlign.left,
                          ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: isArabic
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 9, color: Color(0xFF6D7680)),
                        const SizedBox(width: 3),
                        Text(
                          _formatTimeAgo(item.publishedAt),
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            color: Color(0xFF6D7680),
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
              if (hasImage) ...[
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    item.imageUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => SizedBox.shrink(),
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

class EmptyBlock extends StatelessWidget {
  final Color accentColor;
  final String sourceName;

  const EmptyBlock({
    super.key,
    required this.accentColor,
    required this.sourceName,
  });

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
              color: Color(0xFF8B95A5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sourceName,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              color: Color(0xFF6D7680),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
