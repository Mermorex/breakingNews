import 'dart:async';
import 'dart:convert';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:rss_dart/dart_rss.dart';
import 'package:xml/xml.dart';
import '../models/rss_item_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class RssRemoteDataSource {
  // Reduced timeouts for "Speed Perception"
  static const Duration _connectTimeout = Duration(seconds: 3);

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36',
    'Accept': 'application/rss+xml, application/xml, text/xml, */*',
  };

  /// Main method to fetch RSS feeds using parallel requests (Race Condition)
  /// Falls back to RSS2JSON API if proxies fail (Fixes AlJazeera, etc.)
  Future<List<RssItemModel>> fetchRssFeed(
    String url, {
    String? sourceName,
    int limit = 10,
  }) async {
    final name = sourceName ?? 'Unknown';
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return [];

    try {
      final completer = Completer<List<RssItemModel>>();
      int activeRequests = 0;
      bool hasCompleted = false;

      void handleResult(List<RssItemModel>? items) {
        if (hasCompleted) return;
        if (items != null && items.isNotEmpty) {
          hasCompleted = true;
          completer.complete(items);
        } else {
          activeRequests--;
          if (activeRequests == 0 && !completer.isCompleted) {
            completer.complete([]);
          }
        }
      }

      // 1. Direct Fetch (Mobile/Desktop)
      if (!kIsWeb) {
        activeRequests++;
        _tryDirectFetch(cleanUrl, name, limit).then(handleResult);
      }

      // 2. Proxy Fetches (Web & Mobile Fallback)
      final proxies = [
        'https://api.allorigins.win/raw?url=',
        'https://corsproxy.io/?',
      ];

      for (final proxy in proxies) {
        activeRequests++;
        final proxyUrl = proxy.contains('corsproxy.io')
            ? '$proxy${Uri.encodeComponent(cleanUrl)}'
            : '$proxy${Uri.encodeComponent(cleanUrl)}';

        _tryProxyFetch(proxyUrl, name, limit).then(handleResult);
      }

      // Wait for the race results
      List<RssItemModel> results = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => [],
      );

      // STRATEGY 2: Fallback
      // If parallel fetch failed (returns empty), try RSS2JSON API.
      // This handles strict sites like AlJazeera that block standard proxies.
      if (results.isEmpty) {
        debugPrint(
            '⚠️ $name: Parallel fetch failed, trying RSS2JSON fallback...');
        return await _fetchViaRss2Json(cleanUrl, name, limit);
      }

      return results;
    } catch (e) {
      debugPrint('❌ $name: Error -> $e');
      return [];
    }
  }

  /// Method to scrape websites that don't have RSS
  Future<List<RssItemModel>> scrapeWebsite(
      String url, Map<String, String> selectors,
      {String? sourceName, int limit = 10}) async {
    final name = sourceName ?? 'Unknown';
    try {
      final cleanUrl = url.trim();
      String? htmlContent;

      // Try fetching via proxies for scraping
      final proxies = [
        'https://api.allorigins.win/raw?url=',
        'https://corsproxy.io/?',
      ];

      for (final proxy in proxies) {
        try {
          String proxyUrl = proxy.contains('corsproxy.io')
              ? '$proxy$cleanUrl'
              : '$proxy${Uri.encodeComponent(cleanUrl)}';

          final response = await http
              .get(Uri.parse(proxyUrl))
              .timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            htmlContent = _sanitizeBody(response);
            // Check if we actually got HTML content
            if (htmlContent.contains('</html>') ||
                htmlContent.contains('<body')) break;
          }
        } catch (_) {
          continue;
        }
      }

      if (htmlContent == null) return [];

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
          if (!link.startsWith('http'))
            link = Uri.parse(cleanUrl).resolve(link).toString();

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
      return items;
    } catch (e) {
      debugPrint('❌ $name: Scraping error: $e');
      return [];
    }
  }

  // --- Private Helpers ---

  Future<List<RssItemModel>?> _tryDirectFetch(
      String url, String name, int limit) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(_connectTimeout);

      if (response.statusCode == 200) {
        final body = _sanitizeBody(response);
        if (!_isHtmlResponse(body)) {
          final items = _parseRssString(body, name, limit);
          if (items.isNotEmpty) {
            debugPrint('⚡ $name: Direct Fetch Success');
            return items;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<RssItemModel>?> _tryProxyFetch(
      String proxyUrl, String name, int limit) async {
    try {
      final response =
          await http.get(Uri.parse(proxyUrl)).timeout(_connectTimeout);

      if (response.statusCode == 200) {
        String body = _sanitizeBody(response);

        // Handle JSON wrapped responses
        if (body.trim().startsWith('{')) {
          try {
            final data = jsonDecode(body);
            if (data['contents'] != null) body = data['contents'];
          } catch (_) {}
        }

        if (!_isHtmlResponse(body)) {
          final items = _parseRssString(body, name, limit);
          if (items.isNotEmpty) {
            debugPrint('⚡ $name: Proxy Fetch Success');
            return items;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // NEW: Fallback API method for strict sources
  Future<List<RssItemModel>> _fetchViaRss2Json(
      String url, String name, int limit) async {
    try {
      final apiUrl =
          'https://api.rss2json.com/v1/api.json?rss_url=${Uri.encodeComponent(url)}';
      final response =
          await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'ok' && data['items'] != null) {
          final items = (data['items'] as List).map((item) {
            DateTime? pubDate;
            try {
              pubDate = DateTime.parse(item['pubDate']);
            } catch (_) {}

            return RssItemModel(
              title: item['title'] ?? 'No Title',
              link: item['link'] ?? '',
              pubDate: item['pubDate'] ?? '',
              description: item['description'] ?? '',
              imageUrl: item['enclosure']?['link'] ?? item['thumbnail'],
              publishedAt: pubDate,
              source: name,
            );
          }).toList();

          debugPrint('✅ $name: RSS2JSON Fallback Success');
          return items.take(limit).toList();
        }
      }
    } catch (e) {
      debugPrint('❌ $name: RSS2JSON Fallback Failed');
    }
    return [];
  }

  List<RssItemModel> _parseRssString(String rssString, String name, int limit) {
    try {
      final feed = RssFeed.parse(rssString);
      return feed.items
          .take(limit)
          .map((item) => RssItemModel(
                title: item.title ?? 'No Title',
                link: item.link ?? '',
                pubDate: item.pubDate ?? DateTime.now().toString(),
                description: item.description ?? '',
                publishedAt: item.pubDate != null
                    ? RssItemModel.parseDate(item.pubDate!)
                    : null,
                source: name,
              ))
          .toList();
    } catch (e) {
      // Fallback manual XML parsing if library fails
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

  Future<String> fetchArticleContent(String url) async {
    try {
      // Use a proxy if on web, or direct if mobile
      String fetchUrl = url;
      if (kIsWeb) {
        fetchUrl =
            'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
      }

      final response = await http
          .get(Uri.parse(fetchUrl))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final document = parse(response.body);

        // Remove scripts and styles to get clean text
        document
            .querySelectorAll('script, style, nav, footer, header, aside')
            .forEach((e) => e.remove());

        // Try to find the main article body, fallback to body
        final articleBody = document.querySelector('article') ?? document.body;

        // Extract text and clean whitespace
        String text = articleBody?.text ?? '';
        text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

        // Return first 3000 chars to avoid huge API costs/limits
        return text.length > 3000 ? text.substring(0, 3000) : text;
      }
    } catch (e) {
      debugPrint('Error fetching content: $e');
    }
    return '';
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

  String _sanitizeBody(http.Response response) {
    String body;
    try {
      body = utf8.decode(response.bodyBytes, allowMalformed: true);
    } catch (e) {
      body = latin1.decode(response.bodyBytes, allowInvalid: true);
    }
    if (body.isNotEmpty && body.codeUnitAt(0) == 0xFEFF)
      body = body.substring(1);
    return body.trim();
  }

  bool _isHtmlResponse(String body) {
    final trimmed = body.trim().toLowerCase();
    return trimmed.startsWith('<!doctype html') || trimmed.startsWith('<html');
  }
}
