import 'dart:async';
import 'dart:convert';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:rss_dart/dart_rss.dart';
import 'package:xml/xml.dart';
import '../models/rss_item_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:news_app/core/services/preload_service.dart';
import 'package:news_app/data/models/news_source.dart';

class RssRemoteDataSource {
  static const Duration _connectTimeout = Duration(seconds: 8);
  static const Duration _globalTimeout = Duration(seconds: 10);
  static const Duration _cacheDuration = Duration(minutes: 5);

  final Map<String, _CacheEntry> _cache = {};

  Map<String, String> _getHeaders() {
    if (kIsWeb) {
      return {
        'Accept': 'application/rss+xml, application/xml, text/xml, */*',
      };
    } else {
      return {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      };
    }
  }

  // ==========================================
  // MAIN ENTRY POINT
  // ==========================================

  /// Universal method to fetch feed based on source type
  Future<List<RssItemModel>> getFeed(NewsSource source,
      {int limit = 10, bool forceRefresh = false}) async {
    switch (source.type) {
      case SourceType.scrapable:
        return scrapeWebsite(source.url, source.selectors ?? {},
            sourceName: source.name, limit: limit, forceRefresh: forceRefresh);
      case SourceType.jsonApi:
        return _fetchJsonApi(source.url, source.name, limit);
      case SourceType.rss:
      default:
        return fetchRssFeed(source.url,
            sourceName: source.name, limit: limit, forceRefresh: forceRefresh);
    }
  }

  // ==========================================
  // RSS FETCHER
  // ==========================================
  Future<List<RssItemModel>> fetchRssFeed(
    String url, {
    String? sourceName,
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    final name = sourceName ?? 'Unknown';
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return [];

    // 1. CHECK CACHE
    if (!forceRefresh && _cache.containsKey(cleanUrl)) {
      final entry = _cache[cleanUrl]!;
      if (DateTime.now().difference(entry.timestamp) < _cacheDuration) {
        debugPrint('💾 [$name] Loaded from Cache');
        return entry.items;
      }
    }

    // 2. CHECK PRELOADED DATA (Web Only)
    if (kIsWeb && !forceRefresh) {
      try {
        final preloaded =
            PreloadService.getPreloadedItems(cleanUrl, name, limit);
        if (preloaded != null && preloaded.isNotEmpty) {
          debugPrint('⚡ [$name] Loaded from JS Preload');
          _cache[cleanUrl] =
              _CacheEntry(items: preloaded, timestamp: DateTime.now());
          return preloaded;
        }
      } catch (e) {
        debugPrint('⚠️ [$name] Preload check failed: $e');
      }
    }

    // 3. NETWORK FETCH
    try {
      final List<Future<List<RssItemModel>>> futures = [];

      if (!kIsWeb) {
        futures.add(_tryDirectFetch(cleanUrl, name, limit));
      }

      // Proxies for CORS bypass
      final proxies = [
        'https://api.allorigins.win/raw?url=',
        'https://api.codetabs.com/v1/proxy?quest=',
        'https://corsproxy.io/?',
      ];

      for (final proxy in proxies) {
        final proxyUrl =
            proxy.contains('corsproxy.io') || proxy.contains('codetabs')
                ? '$proxy${Uri.encodeComponent(cleanUrl)}'
                : '$proxy${Uri.encodeComponent(cleanUrl)}';
        futures.add(_tryProxyFetch(proxyUrl, name, limit));
      }

      // Race all requests
      final results = await _raceSuccess(futures)
          .timeout(_globalTimeout, onTimeout: () => []);
      List<RssItemModel> finalItems = results;

      // 4. FALLBACK
      if (finalItems.isEmpty) {
        finalItems = await _fetchViaRss2Json(cleanUrl, name, limit);
      }

      // 5. SAVE TO CACHE
      if (finalItems.isNotEmpty) {
        _cache[cleanUrl] =
            _CacheEntry(items: finalItems, timestamp: DateTime.now());
      } else if (_cache.containsKey(cleanUrl)) {
        return _cache[cleanUrl]!.items;
      }

      return finalItems;
    } catch (e) {
      debugPrint('❌ [$name] Critical Error -> $e');
      if (_cache.containsKey(cleanUrl)) return _cache[cleanUrl]!.items;
      return [];
    }
  }

  // ==========================================
  // WEB SCRAPER
  // ==========================================
  Future<List<RssItemModel>> scrapeWebsite(
    String url,
    Map<String, String> selectors, {
    String? sourceName,
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    final name = sourceName ?? 'Unknown';
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return [];

    // Cache Check
    if (!forceRefresh && _cache.containsKey(cleanUrl)) {
      final entry = _cache[cleanUrl]!;
      if (DateTime.now().difference(entry.timestamp) < _cacheDuration) {
        return entry.items;
      }
    }

    try {
      String? htmlContent;

      // 1. Try Direct Fetch (Mobile/Desktop)
      if (!kIsWeb) {
        try {
          final res = await http
              .get(Uri.parse(cleanUrl), headers: _getHeaders())
              .timeout(_connectTimeout);
          if (res.statusCode == 200) htmlContent = _sanitizeBody(res);
        } catch (_) {}
      }

      // 2. Fallback to Proxies
      if (htmlContent == null || htmlContent.isEmpty) {
        final proxies = [
          'https://api.allorigins.win/raw?url=',
          'https://api.codetabs.com/v1/proxy?quest=',
        ];

        for (final proxy in proxies) {
          try {
            final proxyUrl = proxy.contains('codetabs')
                ? '$proxy${Uri.encodeComponent(cleanUrl)}'
                : '$proxy${Uri.encodeComponent(cleanUrl)}';

            final response =
                await http.get(Uri.parse(proxyUrl)).timeout(_connectTimeout);

            if (response.statusCode == 200) {
              String body = _sanitizeBody(response);
              // Unwrap JSON if needed
              if (body.trim().startsWith('{')) {
                try {
                  final data = jsonDecode(body);
                  if (data['contents'] != null) body = data['contents'];
                } catch (_) {}
              }

              if (body.contains('</html>') || body.length > 500) {
                htmlContent = body;
                break;
              }
            }
          } catch (e) {
            continue;
          }
        }
      }

      if (htmlContent == null || htmlContent.isEmpty) return [];

      final document = parse(htmlContent);
      final itemSelector = selectors['item'] ?? 'article';
      final elements = document.querySelectorAll(itemSelector);

      final items = <RssItemModel>[];

      for (var i = 0; i < elements.length && i < limit; i++) {
        final element = elements[i];

        // --- SMART TITLE FETCHING ---
        String? title;

        // 1. Try specific selector
        var titleElement = element.querySelector(selectors['title'] ?? '');

        // 2. Fallback: Prioritize Header Tags (h3, h2)
        titleElement ??=
            element.querySelector('h3 a, a h3, h3, h2 a, a h2, h2');

        if (titleElement != null) {
          title = titleElement.text.trim();
        }

        // --- Link ---
        String? link =
            element.querySelector(selectors['link'] ?? 'a')?.attributes['href'];

        // --- Date ---
        String? dateText;
        var dateEl = element.querySelector(selectors['date'] ?? 'time, .date');
        if (dateEl != null) {
          dateText = dateEl.attributes['datetime'] ?? dateEl.text.trim();
        }

        if (title != null &&
            title.isNotEmpty &&
            link != null &&
            link.isNotEmpty) {
          if (!link.startsWith('http')) {
            link = Uri.parse(cleanUrl).resolve(link).toString();
          }

          items.add(RssItemModel(
            title: title,
            link: link,
            description: '',
            pubDate: dateText ?? DateTime.now().toString(),
            publishedAt: _parseArabicDate(dateText),
            source: name,
          ));
        }
      }

      if (items.isNotEmpty) {
        debugPrint('✅ [$name] Scraped ${items.length} items');
        _cache[cleanUrl] = _CacheEntry(items: items, timestamp: DateTime.now());
      } else {
        debugPrint('⚠️ [$name] No items found.');
      }

      return items;
    } catch (e) {
      debugPrint('❌ [$name] Scraping error: $e');
      return [];
    }
  }

  // ==========================================
  // HELPERS & PARSERS
  // ==========================================

  Future<List<RssItemModel>> _tryDirectFetch(
      String url, String name, int limit) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: _getHeaders())
          .timeout(_connectTimeout);

      if (response.statusCode == 200) {
        final body = _sanitizeBody(response);
        if (!_isHtmlResponse(body)) {
          return _parseRssString(body, name, limit);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [$name] Direct fetch failed');
    }
    return [];
  }

  Future<List<RssItemModel>> _tryProxyFetch(
      String proxyUrl, String name, int limit) async {
    try {
      final response = await http
          .get(Uri.parse(proxyUrl), headers: _getHeaders())
          .timeout(_connectTimeout);

      if (response.statusCode == 200) {
        String body = _sanitizeBody(response);

        // Handle JSON-wrapped responses (like AllOrigins)
        if (body.trim().startsWith('{')) {
          try {
            final data = jsonDecode(body);
            if (data['contents'] != null) body = data['contents'];
          } catch (_) {}
        }

        if (!_isHtmlResponse(body)) {
          return _parseRssString(body, name, limit);
        }
      }
    } catch (e) {
      // Proxy failed
    }
    return [];
  }

  Future<List<RssItemModel>> _fetchViaRss2Json(
      String url, String name, int limit) async {
    try {
      final apiUrl =
          'https://api.rss2json.com/v1/api.json?rss_url=${Uri.encodeComponent(url)}';
      final response =
          await http.get(Uri.parse(apiUrl)).timeout(_connectTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'ok' && data['items'] != null) {
          return (data['items'] as List)
              .map((item) {
                return RssItemModel(
                  title: item['title'] ?? 'No Title',
                  link: item['link'] ?? '',
                  pubDate: item['pubDate'] ?? '',
                  description: item['description'] ?? '',
                  publishedAt: DateTime.tryParse(item['pubDate'] ?? ''),
                  source: name,
                );
              })
              .take(limit)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('❌ [$name] RSS2JSON Failed: $e');
    }
    return [];
  }

  Future<List<RssItemModel>> _fetchJsonApi(
      String url, String name, int limit) async {
    return [];
  }

  List<RssItemModel> _parseRssString(String rssString, String name, int limit) {
    try {
      final feed = RssFeed.parse(rssString);
      return feed.items.take(limit).map((item) {
        return RssItemModel(
          title: item.title ?? 'No Title',
          link: item.link ?? '',
          pubDate: item.pubDate ?? DateTime.now().toString(),
          description: item.description ?? '',
          publishedAt: _parseArabicDate(item.pubDate),
          source: name,
        );
      }).toList();
    } catch (e) {
      try {
        final document = XmlDocument.parse(rssString);
        return document.findAllElements('item').take(limit).map((e) {
          final pubDate = e.findElements('pubDate').isEmpty
              ? null
              : e.findElements('pubDate').first.text;
          return RssItemModel(
            title: e.findElements('title').isEmpty
                ? 'No Title'
                : e.findElements('title').first.text,
            link: e.findElements('link').isEmpty
                ? ''
                : e.findElements('link').first.text,
            pubDate: pubDate ?? DateTime.now().toString(),
            description: e.findElements('description').isEmpty
                ? ''
                : e.findElements('description').first.text,
            publishedAt: _parseArabicDate(pubDate),
            source: name,
          );
        }).toList();
      } catch (_) {
        return [];
      }
    }
  }

  // ==========================================
  // ARTICLE CONTENT FETCHER
  // ==========================================
  Future<String> fetchArticleContent(String url) async {
    try {
      String fetchUrl = url;
      if (kIsWeb) {
        fetchUrl =
            'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
      }

      final response = await http
          .get(Uri.parse(fetchUrl), headers: _getHeaders())
          .timeout(_connectTimeout);

      if (response.statusCode == 200) {
        final document = parse(response.body);
        document
            .querySelectorAll('script, style, nav, footer, header, aside')
            .forEach((e) => e.remove());
        final articleBody = document.querySelector('article') ?? document.body;
        String text = articleBody?.text ?? '';
        text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
        return text.length > 3000 ? text.substring(0, 3000) : text;
      }
    } catch (e) {
      debugPrint('Error fetching content: $e');
    }
    return '';
  }

  // ==========================================
  // UTILITY FUNCTIONS
  // ==========================================

  Future<List<RssItemModel>> _raceSuccess(
      List<Future<List<RssItemModel>>> futures) async {
    if (futures.isEmpty) return [];
    final completer = Completer<List<RssItemModel>>();
    int remaining = futures.length;

    for (final future in futures) {
      future.then((value) {
        if (!completer.isCompleted) {
          if (value.isNotEmpty) {
            completer.complete(value);
          } else {
            remaining--;
            if (remaining == 0) completer.complete([]);
          }
        }
      }).catchError((error) {
        remaining--;
        if (remaining == 0 && !completer.isCompleted) {
          completer.complete([]);
        }
      });
    }
    return completer.future;
  }

  String _sanitizeBody(http.Response response) {
    String body;
    try {
      body = utf8.decode(response.bodyBytes, allowMalformed: true);
    } catch (e) {
      body = latin1.decode(response.bodyBytes, allowInvalid: true);
    }
    if (body.isNotEmpty && body.codeUnitAt(0) == 0xFEFF) {
      body = body.substring(1);
    }
    return body.trim();
  }

  bool _isHtmlResponse(String body) {
    final trimmed = body.trim().toLowerCase();
    return trimmed.startsWith('<!doctype html') || trimmed.startsWith('<html');
  }

  // ==========================================
  // DATE PARSING (FIXED & SINGLE INSTANCE)
  // ==========================================
  DateTime? _parseArabicDate(String? dateText) {
    if (dateText == null || dateText.isEmpty) return null;

    // FIX 1: Trim whitespace/newlines (fixes " 2026-03-12...")
    String cleanDate = dateText.trim();

    // FIX 2: Try standard ISO parsing first
    DateTime? dt = DateTime.tryParse(cleanDate);
    if (dt != null) return dt;

    // FIX 3: Handle Slash Format: YYYY/MM/DD
    final slashRegex = RegExp(r'(\d{4})/(\d{1,2})/(\d{1,2})');
    final slashMatch = slashRegex.firstMatch(cleanDate);
    if (slashMatch != null) {
      return DateTime(
        int.parse(slashMatch.group(1)!),
        int.parse(slashMatch.group(2)!),
        int.parse(slashMatch.group(3)!),
      );
    }

    // FIX 4: Handle Arabic Months
    final arabicMonths = {
      'جانفي': 1,
      'يناير': 1,
      'فيفري': 2,
      'فبراير': 2,
      'مارس': 3,
      'أفريل': 4,
      'أبريل': 4,
      'ماي': 5,
      'مايو': 5,
      'جوان': 6,
      'يونيو': 6,
      'جويلية': 7,
      'يوليو': 7,
      'أوت': 8,
      'أغسطس': 8,
      'سبتمبر': 9,
      'أكتوبر': 10,
      'نوفمبر': 11,
      'ديسمبر': 12,
    };
    try {
      String normalized =
          cleanDate.replaceAll('ة', 'ه').replaceAll('  ', ' ').trim();
      final regex = RegExp(r'(\d{1,2})\s+([^\d\s]+)\s+(\d{4})');
      final match = regex.firstMatch(normalized);
      if (match != null) {
        final day = int.parse(match.group(1)!);
        final monthName = match.group(2)!.trim();
        final year = int.parse(match.group(3)!);
        final month = arabicMonths[monthName];
        if (month != null) return DateTime(year, month, day);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

class _CacheEntry {
  final List<RssItemModel> items;
  final DateTime timestamp;
  _CacheEntry({required this.items, required this.timestamp});
}
