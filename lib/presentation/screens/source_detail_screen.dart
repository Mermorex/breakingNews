// lib/presentation/screens/source_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/datasources/rss_remote_datasource.dart';
import '../../data/models/rss_item_model.dart';
import '../../data/models/news_source.dart';

class SourceDetailScreen extends StatefulWidget {
  final String sourceName;
  final String sourceUrl;
  final SourceType sourceType;
  final Map<String, String>? selectors;

  const SourceDetailScreen({
    super.key,
    required this.sourceName,
    required this.sourceUrl,
    this.sourceType = SourceType.rss,
    this.selectors,
  });

  @override
  State<SourceDetailScreen> createState() => _SourceDetailScreenState();
}

class _SourceDetailScreenState extends State<SourceDetailScreen> {
  final RssRemoteDataSource _dataSource = RssRemoteDataSource();
  late Future<List<RssItemModel>> _feedFuture;

  // Crypto Palette
  static const Color _bgColor = Color(0xFF0B0E14);
  static const Color _cardColor = Color(0xFF151A25);
  static const Color _accentOrange = Color(0xFFFF8C00);
  static const Color _textWhite = Colors.white;
  static const Color _textGrey = Color(0xFF8B95A5);

  @override
  void initState() {
    super.initState();
    // ✅ FIX: Load data directly without setState to avoid initial frame flicker
    _feedFuture = _fetchData();
  }

  // Separated logic for cleaner code
  Future<List<RssItemModel>> _fetchData() {
    if (widget.sourceType == SourceType.scrapable && widget.selectors != null) {
      return _dataSource.scrapeWebsite(
        widget.sourceUrl.trim(),
        widget.selectors!,
        sourceName: widget.sourceName,
        limit: 50,
      );
    } else {
      return _dataSource.fetchRssFeed(
        widget.sourceUrl.trim(),
        sourceName: widget.sourceName,
        limit: 50,
      );
    }
  }

  void _reload() {
    setState(() {
      _feedFuture = _fetchData();
    });
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
    } else {
      _showError('Cannot open link');
    }
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link copied', style: GoogleFonts.montserrat()),
        backgroundColor: _accentOrange,
        duration: const Duration(seconds: 1),
      ),
    );
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

  String _cleanText(String? text) {
    if (text == null || text.isEmpty) return '';
    return text
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _containsArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return 'Just now';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _containsArabic(widget.sourceName);

    // ✅ FIX: AnnotatedRegion forces the Status Bar to be light (white icons)
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: _textWhite),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            widget.sourceName,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              color: _textWhite,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _accentOrange),
              onPressed: _reload,
            ),
          ],
        ),
        body: FutureBuilder<List<RssItemModel>>(
          future: _feedFuture,
          builder: (context, snapshot) {
            // ✅ FIX: Loading State with explicit background color
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                color: _bgColor, // Force background color
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_accentOrange),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading articles...',
                        style: GoogleFonts.montserrat(color: _textGrey),
                      ),
                    ],
                  ),
                ),
              );
            }

            // ✅ FIX: Error State with explicit background color
            if (snapshot.hasError) {
              return Container(
                color: _bgColor, // Force background color
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load feed',
                          style: GoogleFonts.montserrat(
                            color: _textWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please check your connection.',
                          style: GoogleFonts.montserrat(
                            color: _textGrey.withOpacity(0.7),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentOrange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final items = snapshot.data ?? [];

            // ✅ FIX: Empty State with explicit background color
            if (items.isEmpty) {
              return Container(
                color: _bgColor,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rss_feed_outlined,
                          size: 48, color: _textGrey.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'No articles found',
                        style: GoogleFonts.montserrat(
                          color: _textGrey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              color: _accentOrange,
              backgroundColor: _cardColor,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final itemIsArabic = _containsArabic(item.title);
                  final hasImage =
                      item.imageUrl != null && item.imageUrl!.isNotEmpty;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    child: InkWell(
                      onTap: () => _openArticle(item.link),
                      onLongPress: () => _copyLink(item.link),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date column
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _accentOrange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    item.publishedAt?.day.toString() ?? '--',
                                    style: GoogleFonts.montserrat(
                                      color: _accentOrange,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    _getMonth(item.publishedAt?.month),
                                    style: GoogleFonts.montserrat(
                                      color: _accentOrange,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: itemIsArabic
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: (itemIsArabic
                                            ? GoogleFonts.notoKufiArabic()
                                            : GoogleFonts.montserrat())
                                        .copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _textWhite,
                                      height: 1.3,
                                    ),
                                    textAlign: itemIsArabic
                                        ? TextAlign.right
                                        : TextAlign.left,
                                  ),
                                  const SizedBox(height: 8),
                                  if (item.description != null &&
                                      item.description!.isNotEmpty)
                                    Text(
                                      _cleanText(item.description),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: (itemIsArabic
                                              ? GoogleFonts.notoKufiArabic()
                                              : GoogleFonts.montserrat())
                                          .copyWith(
                                        fontSize: 12,
                                        color: _textGrey,
                                        height: 1.4,
                                      ),
                                      textAlign: itemIsArabic
                                          ? TextAlign.right
                                          : TextAlign.left,
                                    ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 12,
                                        color: _textGrey.withOpacity(0.7),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatTimeAgo(item.publishedAt),
                                        style: GoogleFonts.montserrat(
                                          color: _textGrey.withOpacity(0.7),
                                          fontSize: 11,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.open_in_new,
                                        size: 14,
                                        color: _accentOrange.withOpacity(0.8),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Image thumbnail
                            if (hasImage) ...[
                              const SizedBox(width: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.imageUrl!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
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
