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
  static const Duration _connectTimeout = Duration(seconds: 10);
  static const Duration _globalTimeout = Duration(seconds: 15);
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

      final proxies = [
        'https://corsproxy.io/?',
        'https://api.allorigins.win/raw?url=',
        'https://api.codetabs.com/v1/proxy?quest=',
      ];

      // Strategy A: Try Original URL
      if (!kIsWeb) {
        futures.add(_tryDirectFetch(cleanUrl, name, limit));
      }
      // Try original via proxies
      for (final proxy in proxies) {
        futures.add(_tryProxyFetch(
            '$proxy${Uri.encodeComponent(cleanUrl)}', name, limit));
      }

      // Strategy B: Smart Fallback (Google News Mirror)
      // We identify domains that are consistently problematic (Iranian gov, some Arabic sites)
      final problematicDomains = [
        'mehrnews',
        'tasnim',
        'tehrantimes',
        'farsnews',
        'aljazeera.net',
        'presstv',
        'presstv.ir',
        'tunisie.gov.tn',
        'babnet'
      ];

      bool isProblematic = problematicDomains.any((d) => cleanUrl.contains(d));

      if (isProblematic) {
        final uri = Uri.tryParse(cleanUrl);
        if (uri != null && uri.host.isNotEmpty) {
          final domain = uri.host.replaceFirst('www.', '');
          // Create Google News RSS URL for this specific domain
          final googleUrl =
              'https://news.google.com/rss/search?q=site:$domain&hl=en-US&gl=US&ceid=US:en';

          debugPrint(
              '🌐 [$name] Problematic domain detected. Racing Google Mirror...');

          // CRITICAL FIX: Try the Mirror via ALL proxies to ensure one works
          for (final proxy in proxies) {
            if (kIsWeb) {
              futures.add(_tryProxyFetch(
                  '$proxy${Uri.encodeComponent(googleUrl)}', name, limit));
            } else {
              // Mobile can try direct Google
              futures.add(_tryDirectFetch(googleUrl, name, limit));
            }
          }
        }
      }

      // Race all requests
      final results = await _raceSuccess(futures)
          .timeout(_globalTimeout, onTimeout: () => []);
      List<RssItemModel> finalItems = results;

      // Strategy C: RSS2JSON Fallback (Last Resort)
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

    if (!forceRefresh && _cache.containsKey(cleanUrl)) {
      final entry = _cache[cleanUrl]!;
      if (DateTime.now().difference(entry.timestamp) < _cacheDuration) {
        return entry.items;
      }
    }

    try {
      String? htmlContent;

      if (!kIsWeb) {
        try {
          final res = await http
              .get(Uri.parse(cleanUrl), headers: _getHeaders())
              .timeout(_connectTimeout);
          if (res.statusCode == 200) htmlContent = _sanitizeBody(res);
        } catch (_) {}
      }

      if (htmlContent == null || htmlContent.isEmpty) {
        final proxies = [
          'https://corsproxy.io/?',
          'https://api.allorigins.win/raw?url=',
        ];

        for (final proxy in proxies) {
          try {
            final proxyUrl = '$proxy${Uri.encodeComponent(cleanUrl)}';

            final response =
                await http.get(Uri.parse(proxyUrl)).timeout(_connectTimeout);

            if (response.statusCode == 200) {
              String body = _sanitizeBody(response);
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

        String? title;
        var titleElement = element.querySelector(selectors['title'] ?? '');
        titleElement ??=
            element.querySelector('h3 a, a h3, h3, h2 a, a h2, h2');

        if (titleElement != null) {
          title = titleElement.text.trim();
        }

        String? link =
            element.querySelector(selectors['link'] ?? 'a')?.attributes['href'];

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
            publishedAt: _parseStandardDate(dateText),
            source: name,
          ));
        }
      }

      if (items.isNotEmpty) {
        debugPrint('✅ [$name] Scraped ${items.length} items');
        _cache[cleanUrl] = _CacheEntry(items: items, timestamp: DateTime.now());
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
      // Fail silent
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
      // Fail silent
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
                  publishedAt: _parseStandardDate(item['pubDate']),
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
      String cleanXml = rssString;
      cleanXml =
          cleanXml.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

      final feed = RssFeed.parse(cleanXml);

      if (feed.items.isEmpty) {
        return _parseXmlManually(cleanXml, name, limit);
      }

      return feed.items.take(limit).map((item) {
        return RssItemModel(
          title: item.title ?? 'No Title',
          link: item.link ?? '',
          pubDate: item.pubDate ?? DateTime.now().toString(),
          description: item.description ?? '',
          publishedAt: _parseStandardDate(item.pubDate),
          source: name,
        );
      }).toList();
    } catch (e) {
      return _parseXmlManually(rssString, name, limit);
    }
  }

  List<RssItemModel> _parseXmlManually(
      String xmlString, String name, int limit) {
    try {
      final document = XmlDocument.parse(xmlString);
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
          publishedAt: _parseStandardDate(pubDate),
          source: name,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

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

  DateTime? _parseStandardDate(String? dateText) {
    if (dateText == null || dateText.isEmpty) return null;

    String cleanDate = dateText.trim();

    DateTime? dt = DateTime.tryParse(cleanDate);
    if (dt != null) {
      return dt.isUtc ? dt.toLocal() : dt;
    }

    final months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
      'January': 1,
      'February': 2,
      'March': 3,
      'April': 4,
      'May': 5,
      'June': 6,
      'July': 7,
      'August': 8,
      'September': 9,
      'October': 10,
      'November': 11,
      'December': 12,
    };

    final rssRegex =
        RegExp(r'(\d{1,2})\s+([a-zA-Z]+)\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})');
    final match = rssRegex.firstMatch(cleanDate);

    if (match != null) {
      final day = int.tryParse(match.group(1)!);
      final monthStr = match.group(2);
      final year = int.tryParse(match.group(3)!);
      final hour = int.tryParse(match.group(4)!);
      final minute = int.tryParse(match.group(5)!);
      final second = int.tryParse(match.group(6)!);

      final month = months[monthStr];

      if (day != null &&
          month != null &&
          year != null &&
          hour != null &&
          minute != null &&
          second != null) {
        DateTime tempDate =
            DateTime.utc(year, month, day, hour, minute, second);
        return tempDate.toLocal();
      }
    }

    final slashRegex = RegExp(r'(\d{4})/(\d{1,2})/(\d{1,2})');
    final slashMatch = slashRegex.firstMatch(cleanDate);
    if (slashMatch != null) {
      return DateTime(
        int.parse(slashMatch.group(1)!),
        int.parse(slashMatch.group(2)!),
        int.parse(slashMatch.group(3)!),
      );
    }

    return null;
  }
}

class _CacheEntry {
  final List<RssItemModel> items;
  final DateTime timestamp;
  _CacheEntry({required this.items, required this.timestamp});
}
