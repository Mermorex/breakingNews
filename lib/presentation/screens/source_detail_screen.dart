// ==================== SOURCE DETAIL SCREEN ====================
// File: lib/presentation/screens/source_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/datasources/rss_remote_datasource.dart';
import '../../data/models/rss_item_model.dart';
import '../../utils/date_time_extension.dart';

class SourceDetailScreen extends StatefulWidget {
  final String sourceName;
  final String sourceUrl;

  const SourceDetailScreen({
    super.key,
    required this.sourceName,
    required this.sourceUrl,
  });

  @override
  State<SourceDetailScreen> createState() => _SourceDetailScreenState();
}

class _SourceDetailScreenState extends State<SourceDetailScreen> {
  final RssRemoteDataSource _dataSource = RssRemoteDataSource();
  late Future<List<RssItemModel>> _feedFuture;

  @override
  void initState() {
    super.initState();
    _feedFuture = _dataSource.fetchRssFeed(widget.sourceUrl.trim());
  }

  void _loadFeed() {
    setState(() {
      _feedFuture = _dataSource.fetchRssFeed(widget.sourceUrl.trim());
    });
  }

  /// Opens article using url_launcher (works on all platforms)
  Future<void> _openArticle(String url) async {
    if (url.isEmpty) return;

    String cleanUrl = url.trim();

    // Ensure URL is absolute (starts with http:// or https://)
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      // If relative URL, try to make it absolute
      if (cleanUrl.startsWith('//')) {
        cleanUrl = 'https:$cleanUrl';
      } else if (cleanUrl.startsWith('/')) {
        // Relative to domain - extract domain from source
        cleanUrl = _getBaseUrl(widget.sourceUrl) + cleanUrl;
      } else {
        // No protocol - add https://
        cleanUrl = 'https://$cleanUrl';
      }
    }

    debugPrint('Opening URL: $cleanUrl');

    final uri = Uri.parse(cleanUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $cleanUrl');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $cleanUrl')),
        );
      }
    }
  }

  /// Extracts base URL from source URL
  String _getBaseUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      return '${uri.scheme}://${uri.host}';
    } catch (e) {
      return '';
    }
  }

  String _cleanText(String? text) {
    if (text == null || text.isEmpty) return '';
    return text
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sourceName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFeed,
          ),
        ],
      ),
      body: FutureBuilder<List<RssItemModel>>(
        future: _feedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('Failed to load',
                      style: Theme.of(context).textTheme.titleMedium),
                  TextButton(
                    onPressed: _loadFeed,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return const Center(child: Text('No articles'));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: InkWell(
                  onTap: () => _openArticle(item.link),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (item.description != null)
                          Text(
                            _cleanText(item.description),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              item.publishedAt?.toTimeAgo() ?? 'Just now',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.open_in_new,
                                size: 16, color: Colors.grey.shade400),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
