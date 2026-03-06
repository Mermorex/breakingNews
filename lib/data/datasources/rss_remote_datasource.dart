import 'dart:convert';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:rss_dart/dart_rss.dart';
import 'package:xml/xml.dart';
import '../models/rss_item_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class RssRemoteDataSource {
  // ✅ STRATEGY:
  // 1. Standard News (BBC, AlJazeera) -> Codetabs is best.
  // 2. Reddit -> AllOrigins is best (Codetabs is blocked by Reddit).

  static const List<String> _standardProxies = [
    'https://api.codetabs.com/v1/proxy?quest=',
    'https://api.allorigins.win/raw?url=',
    'https://corsproxy.io/?',
  ];

  // Special list just for Reddit (AllOrigins is most reliable for JSON)
  static const List<String> _redditProxies = [
    'https://api.allorigins.win/raw?url=', // 🥇 Best for Reddit JSON
    'https://corsproxy.io/?', // 🥈 Backup
    // Do not use Codetabs for Reddit, it returns 403 Forbidden
  ];

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36',
    'Accept': 'application/rss+xml, application/xml, text/xml, */*',
  };

  Future<List<RssItemModel>> fetchRssFeed(
    String url, {
    String? sourceName,
    int limit = 10,
    bool useWebFeed = true,
  }) async {
    final name = sourceName ?? 'Unknown';

    try {
      final cleanUrl = url.trim();
      if (cleanUrl.isEmpty) {
        debugPrint('❌ $name: Empty URL');
        return [];
      }

      // ✅ AUTO-DETECT REDDIT
      if (cleanUrl.contains('reddit.com') && cleanUrl.endsWith('.json')) {
        debugPrint('🔴 $name: Detected Reddit JSON');
        return await fetchRedditJson(cleanUrl, name, limit);
      }

      if (kIsWeb) {
        return await _fetchWithProxy(cleanUrl, name, limit, _standardProxies);
      }

      // Mobile/Desktop Direct Fetch
      try {
        final response = await http
            .get(Uri.parse(cleanUrl), headers: _headers)
            .timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final body = _sanitizeBody(response);
          if (!_isHtmlResponse(body)) {
            final items = _parseRssString(body, name, limit);
            if (items.isNotEmpty) {
              debugPrint('✅ $name: Direct fetch success');
              return items;
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ $name: Direct fetch failed, trying proxy...');
      }

      return await _fetchWithProxy(cleanUrl, name, limit, _standardProxies);
    } catch (e) {
      debugPrint('❌ $name: $e');
      return [];
    }
  }

  Future<List<RssItemModel>> _fetchWithProxy(
      String url, String name, int limit, List<String> proxies) async {
    for (final proxy in proxies) {
      try {
        String proxyUrl;
        if (proxy.contains('corsproxy.io')) {
          proxyUrl = '$proxy$url';
        } else {
          proxyUrl = '$proxy${Uri.encodeComponent(url)}';
        }

        // Do not send custom headers to proxies, they often reject them
        final response = await http
            .get(Uri.parse(proxyUrl))
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          String body = _sanitizeBody(response);

          if (body.trim().startsWith('{') && body.contains('contents')) {
            try {
              final data = jsonDecode(body);
              body = data['contents'] ?? '';
            } catch (_) {}
          }

          if (body.isNotEmpty && !_isHtmlResponse(body)) {
            final items = _parseRssString(body, name, limit);
            if (items.isNotEmpty) {
              debugPrint('✅ $name: Proxy success');
              return items;
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ $name: Proxy failed -> $e');
        continue;
      }
    }
    return await _fetchViaRss2Json(url, name, limit);
  }

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
              description: item['description'] ?? '',
              pubDate: item['pubDate'] ?? '',
              imageUrl: item['enclosure']?['link'] ?? item['thumbnail'],
              publishedAt: pubDate,
              source: name,
            );
          }).toList();

          debugPrint('✅ $name: RSS2JSON success');
          return items.take(limit).toList();
        }
      }
    } catch (e) {
      debugPrint('❌ $name: RSS2JSON failed');
    }
    return [];
  }

  Future<String> _translateToArabic(String text) async {
    if (text.isEmpty) return text;
    try {
      final url =
          'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(text)}&langpair=en|ar';
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['responseStatus'] == 200) {
          return data['responseData']['translatedText'] ?? text;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Translation failed');
    }
    return text;
  }

  Future<List<RssItemModel>> fetchRedditJson(
      String url, String name, int limit) async {
    try {
      String? jsonStr;

      // 1. Try Direct (Mobile/Desktop only)
      if (!kIsWeb) {
        try {
          final response = await http.get(Uri.parse(url), headers: {
            'User-Agent': 'FlutterRSSReader/1.0'
          }).timeout(const Duration(seconds: 8));

          if (response.statusCode == 200) {
            jsonStr = response.body;
          }
        } catch (_) {}
      }

      // 2. Try Proxies (Web & Mobile Fallback)
      if (jsonStr == null) {
        for (final proxy in _redditProxies) {
          try {
            String proxyUrl;
            if (proxy.contains('corsproxy.io')) {
              proxyUrl = '$proxy$url';
            } else {
              proxyUrl = '$proxy${Uri.encodeComponent(url)}';
            }

            final response = await http
                .get(Uri.parse(proxyUrl))
                .timeout(const Duration(seconds: 8));

            if (response.statusCode == 200) {
              jsonStr = _sanitizeBody(response);
              if (jsonStr.isNotEmpty) break; // Success
            }
          } catch (_) {
            continue;
          }
        }
      }

      // 3. Fallback: old.reddit.com
      if (jsonStr == null) {
        final oldUrl = url.replaceFirst('www.reddit.com', 'old.reddit.com');
        for (final proxy in _redditProxies) {
          try {
            String proxyUrl = proxy.contains('corsproxy.io')
                ? '$proxy$oldUrl'
                : '$proxy${Uri.encodeComponent(oldUrl)}';

            final response = await http
                .get(Uri.parse(proxyUrl))
                .timeout(const Duration(seconds: 8));
            if (response.statusCode == 200) {
              jsonStr = _sanitizeBody(response);
              if (jsonStr.isNotEmpty) break;
            }
          } catch (_) {}
        }
      }

      if (jsonStr == null) {
        debugPrint('❌ $name: All Reddit fetch attempts failed');
        return [];
      }

      final data = jsonDecode(jsonStr);
      final posts = data['data']['children'] as List;
      List<RssItemModel> items = [];

      for (int i = 0; i < posts.length && i < limit; i++) {
        final post = posts[i];
        final p = post['data'];

        final createdUtc = p['created_utc'] as int?;
        final date = createdUtc != null
            ? DateTime.fromMillisecondsSinceEpoch(createdUtc * 1000)
            : null;

        String link;
        String permalink = 'https://www.reddit.com${p['permalink']}';
        bool isSelfPost = p['is_self'] ?? false;
        String? externalUrl = p['url'];

        if (!isSelfPost &&
            externalUrl != null &&
            externalUrl.startsWith('http')) {
          link = externalUrl.contains('reddit.com') ? permalink : externalUrl;
        } else {
          link = permalink;
        }

        String originalTitle = p['title'] ?? 'No Title';
        String translatedTitle = await _translateToArabic(originalTitle);

        items.add(RssItemModel(
          title: translatedTitle,
          link: link,
          description: p['selftext'] ?? '',
          pubDate: date?.toIso8601String() ?? '',
          publishedAt: date,
          imageUrl: p['thumbnail'] != 'self' &&
                  p['thumbnail'] != 'default' &&
                  p['thumbnail'] != 'nsfw'
              ? p['thumbnail']
              : null,
          source: name,
        ));
      }
      return items;
    } catch (e) {
      debugPrint('❌ Reddit fetch failed: $e');
      return [];
    }
  }

  Future<List<RssItemModel>> scrapeWebsite(
      String url, Map<String, String> selectors,
      {String? sourceName, int limit = 10}) async {
    final name = sourceName ?? 'Unknown';
    try {
      final cleanUrl = url.trim();
      String? htmlContent;

      for (final proxy in _standardProxies) {
        try {
          String proxyUrl = proxy.contains('corsproxy.io')
              ? '$proxy$cleanUrl'
              : '$proxy${Uri.encodeComponent(cleanUrl)}';
          final response = await http
              .get(Uri.parse(proxyUrl))
              .timeout(const Duration(seconds: 8));

          if (response.statusCode == 200) {
            htmlContent = _sanitizeBody(response);
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

  bool _isHtmlResponse(String body) {
    final trimmed = body.trim().toLowerCase();
    return trimmed.startsWith('<!doctype html') || trimmed.startsWith('<html');
  }

  String _cleanXmlForParsing(String xml) {
    if (xml.isNotEmpty && xml.codeUnitAt(0) == 0xFEFF) xml = xml.substring(1);
    return xml.trim();
  }

  List<RssItemModel> _parseRssString(String rssString, String name, int limit) {
    try {
      final feed = RssFeed.parse(rssString);
      return feed.items
          .take(limit)
          .map((item) => _convertRssItemToModel(item, name))
          .toList();
    } catch (e) {
      try {
        final document = XmlDocument.parse(_cleanXmlForParsing(rssString));
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

  RssItemModel _convertRssItemToModel(RssItem item, String sourceName) {
    return RssItemModel(
      title: item.title ?? 'No Title',
      link: item.link ?? '',
      pubDate: item.pubDate ?? DateTime.now().toString(),
      description: item.description ?? '',
      publishedAt:
          item.pubDate != null ? RssItemModel.parseDate(item.pubDate!) : null,
      source: sourceName,
    );
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
}
