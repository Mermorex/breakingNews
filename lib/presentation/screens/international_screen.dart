// ==================== INTERNATIONAL NEWS SCREEN ====================
// File: lib/presentation/screens/international_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/datasources/rss_remote_datasource.dart';
import '../../data/models/rss_item_model.dart';
import 'source_detail_screen.dart';
import '../../utils/date_time_extension.dart';

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

  final List<Map<String, String>> _arabicSources = [
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
  ];

  final List<Map<String, String>> _englishSources = [
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

  late final List<Map<String, String>> _rssSources = [
    ..._arabicSources,
    ..._englishSources
  ];

  final Map<int, List<RssItemModel>> _dashboardData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    final futures = _rssSources.asMap().entries.map((entry) async {
      final index = entry.key;
      final url = entry.value['url']!.trim();

      if (url.isEmpty || url.contains('placeholder')) {
        return {index: <RssItemModel>[]};
      }

      try {
        final items = await _dataSource.fetchRssFeed(url, limit: 3);
        return {index: items};
      } catch (e) {
        debugPrint('Error loading ${entry.value['name']}: $e');
        return {index: <RssItemModel>[]};
      }
    });

    final results = await Future.wait(futures);

    for (var map in results) {
      _dashboardData.addAll(map);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Opens article using url_launcher (works on all platforms)
  Future<void> _openArticle(String url) async {
    if (url.isEmpty) return;

    String cleanUrl = url.trim();

    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      if (cleanUrl.startsWith('//')) {
        cleanUrl = 'https:$cleanUrl';
      } else {
        cleanUrl = 'https://$cleanUrl';
      }
    }

    final uri = Uri.parse(cleanUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $cleanUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'International News',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _rssSources.length,
                itemBuilder: (context, index) {
                  final source = _rssSources[index];
                  final items = _dashboardData[index] ?? [];
                  final isArabic = _arabicSources.contains(source);

                  return _DashboardSourceSection(
                    sourceName: source['name']!,
                    sourceUrl: source['url']!,
                    items: items,
                    sourceIndex: index,
                    isArabic: isArabic,
                    onSeeAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SourceDetailScreen(
                            sourceName: source['name']!,
                            sourceUrl: source['url']!.trim(),
                          ),
                        ),
                      );
                    },
                    onArticleTap: _openArticle,
                  );
                },
              ),
            ),
    );
  }
}

class _DashboardSourceSection extends StatelessWidget {
  final String sourceName;
  final String sourceUrl;
  final List<RssItemModel> items;
  final int sourceIndex;
  final bool isArabic;
  final VoidCallback onSeeAll;
  final Function(String) onArticleTap;

  const _DashboardSourceSection({
    required this.sourceName,
    required this.sourceUrl,
    required this.items,
    required this.sourceIndex,
    required this.isArabic,
    required this.onSeeAll,
    required this.onArticleTap,
  });

  Color _getAccentColor(int index) {
    final colors = [
      Colors.green.shade600,
      Colors.teal.shade600,
      Colors.lightGreen.shade700,
      Colors.green.shade800,
      Colors.teal.shade700,
      Colors.cyan.shade600,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = _getAccentColor(sourceIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      sourceName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isArabic
                            ? Colors.green.shade100
                            : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isArabic ? 'AR' : 'EN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isArabic
                              ? Colors.green.shade800
                              : Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onSeeAll,
                icon: Text(
                  'See All',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                label: Icon(Icons.arrow_forward_rounded,
                    size: 18, color: accentColor),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          _EmptySourceCard(accentColor: accentColor)
        else
          ...items.map((item) => _MiniNewsCard(
                item: item,
                accentColor: accentColor,
                sourceUrl: sourceUrl,
                onTap: () => onArticleTap(item.link),
              )),
        const Divider(height: 32, indent: 16, endIndent: 16),
      ],
    );
  }
}

class _MiniNewsCard extends StatelessWidget {
  final RssItemModel item;
  final Color accentColor;
  final String sourceUrl;
  final VoidCallback onTap;

  const _MiniNewsCard({
    required this.item,
    required this.accentColor,
    required this.sourceUrl,
    required this.onTap,
  });

  String _getSnippet(String? description) {
    if (description == null || description.isEmpty) return '';
    final cleanText = description
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleanText.length > 100
        ? '${cleanText.substring(0, 100)}...'
        : cleanText;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snippet = _getSnippet(item.description);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                accentColor.withOpacity(0.03),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.publishedAt?.day.toString() ?? '--',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        _getMonthAbbrev(item.publishedAt?.month),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (snippet.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          snippet,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            item.publishedAt?.toTimeAgo() ?? 'Just now',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.grey.shade500,
                              fontSize: 10,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.open_in_new, size: 14, color: accentColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMonthAbbrev(int? month) {
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

class _EmptySourceCard extends StatelessWidget {
  final Color accentColor;

  const _EmptySourceCard({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.rss_feed_outlined,
                color: Colors.grey.shade400, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No recent updates',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
