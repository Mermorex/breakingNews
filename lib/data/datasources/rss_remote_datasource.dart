import 'dart:async';
import 'dart:convert';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:rss_dart/dart_rss.dart';
import 'package:xml/xml.dart';
import '../models/rss_item_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

// Check if we need the Preload Service import (Web only)
import 'package:news_app/core/services/preload_service.dart';

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
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      };
    }
  }

  Future<List<RssItemModel>> fetchRssFeed(
    String url, {
    String? sourceName,
    int limit = 4,
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
          // Save to local cache for subsequent requests
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
      } else {
        if (_cache.containsKey(cleanUrl)) {
          return _cache[cleanUrl]!.items;
        }
      }

      return finalItems;
    } catch (e) {
      debugPrint('❌ [$name] Critical Error -> $e');
      if (_cache.containsKey(cleanUrl)) return _cache[cleanUrl]!.items;
      return [];
    }
  }

  Future<List<RssItemModel>> scrapeWebsite(
    String url,
    Map<String, String> selectors, {
    String? sourceName,
    int limit = 4,
  }) async {
    final name = sourceName ?? 'Unknown';
    final cleanUrl = url.trim();

    if (_cache.containsKey(cleanUrl)) {
      final entry = _cache[cleanUrl]!;
      if (DateTime.now().difference(entry.timestamp) < _cacheDuration) {
        debugPrint('💾 [$name] Scraper loaded from Cache');
        return entry.items;
      }
    }

    try {
      String? htmlContent;
      final proxies = [
        'https://api.allorigins.win/raw?url=',
        'https://api.codetabs.com/v1/proxy?quest=',
      ];

      for (final proxy in proxies) {
        try {
          final proxyUrl = proxy.contains('codetabs')
              ? '$proxy${Uri.encodeComponent(cleanUrl)}'
              : '$proxy${Uri.encodeComponent(cleanUrl)}';

          final response = await http
              .get(Uri.parse(proxyUrl), headers: _getHeaders())
              .timeout(_connectTimeout);

          if (response.statusCode == 200) {
            htmlContent = _sanitizeBody(response);
            if (htmlContent.contains('</html>') ||
                htmlContent.contains('<body')) {
              break;
            }
          }
        } catch (e) {
          continue;
        }
      }

      if (htmlContent == null || htmlContent.isEmpty) return [];

      final document = parse(htmlContent);
      final elements =
          document.querySelectorAll(selectors['item'] ?? 'article');
      final items = <RssItemModel>[];

      for (var i = 0; i < elements.length && i < limit; i++) {
        final element = elements[i];
        String? title =
            element.querySelector(selectors['title'] ?? 'h2')?.text.trim();
        String? link =
            element.querySelector(selectors['link'] ?? 'a')?.attributes['href'];
        String? dateText = element
            .querySelector(selectors['date'] ?? '.date, time')
            ?.text
            .trim();

        if (title != null && link != null) {
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
        _cache[cleanUrl] = _CacheEntry(items: items, timestamp: DateTime.now());
      }

      return items;
    } catch (e) {
      debugPrint('❌ [$name] Scraping error: $e');
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

  // --- Private Helpers ---

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

  Future<List<RssItemModel>> _tryDirectFetch(
      String url, String name, int limit) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: _getHeaders())
          .timeout(_connectTimeout);

      if (response.statusCode == 200) {
        final body = _sanitizeBody(response);
        if (!_isHtmlResponse(body)) {
          final items = _parseRssString(body, name, limit);
          if (items.isNotEmpty) debugPrint('⚡ [$name] Direct Fetch Success');
          return items;
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

        if (body.trim().startsWith('{')) {
          try {
            final data = jsonDecode(body);
            if (data['contents'] != null) body = data['contents'];
          } catch (_) {}
        }

        if (!_isHtmlResponse(body)) {
          final items = _parseRssString(body, name, limit);
          if (items.isNotEmpty) {
            debugPrint('⚡ [$name] Proxy Success');
          }
          return items;
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
          final items = (data['items'] as List).map((item) {
            return RssItemModel(
              title: item['title'] ?? 'No Title',
              link: item['link'] ?? '',
              pubDate: item['pubDate'] ?? '',
              description: item['description'] ?? '',
              imageUrl: item['enclosure']?['link'] ?? item['thumbnail'],
              publishedAt: DateTime.tryParse(item['pubDate'] ?? ''),
              source: name,
            );
          }).toList();
          debugPrint('✅ [$name] RSS2JSON Fallback Success');
          return items.take(limit).toList();
        }
      }
    } catch (e) {
      debugPrint('❌ [$name] RSS2JSON Failed: $e');
    }
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
          publishedAt: item.pubDate != null
              ? RssItemModel.parseDate(item.pubDate!)
              : null,
          source: name,
        );
      }).toList();
    } catch (e) {
      try {
        final document = XmlDocument.parse(rssString);
        return document
            .findAllElements('item')
            .take(limit)
            .map((e) => RssItemModel.fromXml(e, sourceName: name))
            .toList();
      } catch (_) {
        return [];
      }
    }
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

  DateTime? _parseArabicDate(String? dateText) {
    if (dateText == null || dateText.isEmpty) return null;
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
          dateText.replaceAll('ة', 'ه').replaceAll('  ', ' ').trim();
      final regex = RegExp(r'(\d{1,2})\s+([^\d\s]+)\s+(\d{4})');
      final match = regex.firstMatch(normalized);
      if (match != null) {
        final day = int.parse(match.group(1)!);
        final monthName = match.group(2)!.trim();
        final year = int.parse(match.group(3)!);
        final month = arabicMonths[monthName];
        if (month != null) return DateTime(year, month, day);
      }
      return DateTime.tryParse(dateText);
    } catch (e) {
      return null;
    }
  }
}

// Helper class defined OUTSIDE the main class
class _CacheEntry {
  final List<RssItemModel> items;
  final DateTime timestamp;

  _CacheEntry({required this.items, required this.timestamp});
}
