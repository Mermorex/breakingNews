import 'dart:convert';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:rss_dart/dart_rss.dart';
import 'package:xml/xml.dart';
import '../models/rss_item_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class RssRemoteDataSource {
  // ✅ Reliable CORS Proxies for Web/Netlify
  static const List<String> _publicProxies = [
    'https://api.allorigins.win/raw?url=', // Best for Netlify
    'https://corsproxy.io/?', // Good backup
  ];

  // ✅ Headers to mimic a real browser (avoids bot blocking)
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

      // ✅ FIX: On Web (Netlify), we MUST use a proxy for almost all RSS feeds.
      // Direct fetching will almost always fail due to CORS.
      if (kIsWeb) {
        return await _fetchWithProxy(cleanUrl, name, limit);
      }

      // ✅ MOBILE/DESKTOP: Try Direct Fetch first (Faster)
      try {
        final response = await http
            .get(Uri.parse(cleanUrl), headers: _headers)
            .timeout(const Duration(seconds: 5));

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
        debugPrint('⚠️ $name: Direct fetch failed, trying proxy');
      }

      // Fallback to proxy for mobile if direct fails
      return await _fetchWithProxy(cleanUrl, name, limit);
    } catch (e) {
      debugPrint('❌ $name: $e');
      return [];
    }
  }

  // ✅ NEW: Dedicated Proxy Fetch Method
  Future<List<RssItemModel>> _fetchWithProxy(
      String url, String name, int limit) async {
    for (final proxy in _publicProxies) {
      try {
        // Encode URL to handle special characters
        final proxyUrl = '$proxy${Uri.encodeComponent(url)}';

        final response = await http
            .get(Uri.parse(proxyUrl), headers: _headers)
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          String body = _sanitizeBody(response);

          // Handle allorigins JSON wrapper if present
          if (body.trim().startsWith('{') && body.contains('contents')) {
            try {
              final data = jsonDecode(body);
              body = data['contents'] ?? '';
            } catch (_) {}
          }

          if (body.isNotEmpty && !_isHtmlResponse(body)) {
            final items = _parseRssString(body, name, limit);
            if (items.isNotEmpty) {
              debugPrint('✅ $name: Proxy success (${proxy.split('?').first})');
              return items;
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ $name: Proxy failed (${proxy.split('?').first})');
        continue;
      }
    }

    // Last resort: Try rss2json API
    return await _fetchViaRss2Json(url, name, limit);
  }

  // ✅ NEW: Dedicated rss2json Method
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

  // ✅ Helper: Parse RSS String
  List<RssItemModel> _parseRssString(String rssString, String name, int limit) {
    try {
      final feed = RssFeed.parse(rssString);
      return feed.items
          .take(limit)
          .map((item) => _convertRssItemToModel(item, name))
          .toList();
    } catch (e) {
      // Fallback to manual XML parsing if dart_rss fails
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

  Future<List<RssItemModel>> scrapeWebsite(
    String url,
    Map<String, String> selectors, {
    String? sourceName,
    int limit = 10,
  }) async {
    final name = sourceName ?? 'Unknown';
    try {
      final cleanUrl = url.trim();
      String? htmlContent;

      // Use proxy for web scraping
      for (final proxy in _publicProxies) {
        try {
          final proxyUrl = '$proxy${Uri.encodeComponent(cleanUrl)}';
          final response = await http
              .get(Uri.parse(proxyUrl), headers: _headers)
              .timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            htmlContent = response.body;
            break;
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

        if (title != null && link != null) {
          if (!link.startsWith('http')) {
            link = Uri.parse(cleanUrl).resolve(link).toString();
          }
          items.add(RssItemModel(
            title: title,
            link: link,
            description: '',
            pubDate: DateTime.now().toString(),
            source: name,
          ));
        }
      }
      return items;
    } catch (e) {
      return [];
    }
  }

  // --- Helper Methods (unchanged) ---

  bool _isHtmlResponse(String body) {
    final trimmed = body.trim().toLowerCase();
    return trimmed.startsWith('<!doctype html') || trimmed.startsWith('<html');
  }

  String _cleanXmlForParsing(String xml) {
    if (xml.isNotEmpty && xml.codeUnitAt(0) == 0xFEFF) xml = xml.substring(1);
    return xml.trim();
  }

  RssItemModel _convertRssItemToModel(RssItem item, String sourceName) {
    return RssItemModel(
      title: item.title ?? 'No Title',
      link: item.link ?? '',
      pubDate: item.pubDate ?? DateTime.now().toString(),
      description: item.description ?? '',
      // imageUrl: null, // Remove or set to null
      publishedAt:
          item.pubDate != null ? RssItemModel.parseDate(item.pubDate!) : null,
      source: sourceName,
    );
  }

  String _sanitizeBody(http.Response response) {
    // ✅ CRITICAL: Decode bytes directly as UTF-8, ignore header charset
    String body;
    try {
      body = utf8.decode(response.bodyBytes, allowMalformed: true);
    } catch (e) {
      body = latin1.decode(response.bodyBytes, allowInvalid: true);
    }

    // Remove BOM if present
    if (body.isNotEmpty && body.codeUnitAt(0) == 0xFEFF) {
      body = body.substring(1);
    }

    return body.trim();
  }
}
