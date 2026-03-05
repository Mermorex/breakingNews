// lib/data/datasources/rss_remote_datasource.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:dart_rss/dart_rss.dart';
import 'package:html/parser.dart' show parse;
import '../models/rss_item_model.dart';
import 'package:flutter/foundation.dart';

class RssRemoteDataSource {
  // Clean proxy URLs (NO trailing spaces!)
  static const List<String> _publicProxies = [
    'https://api.allorigins.win/raw?url=',
    'https://corsproxy.io/?',
    'https://api.codetabs.com/v1/proxy?quest=',
  ];

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

      String? workingBody;

      // Try RSS2JSON first (most reliable, no CORS)
      try {
        final rss2JsonUrl =
            'https://api.rss2json.com/v1/api.json?rss_url=${Uri.encodeComponent(cleanUrl)}';
        final response = await http
            .get(Uri.parse(rss2JsonUrl))
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'ok') {
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
                imageUrl: item['enclosure']?['link'] ??
                    item['thumbnail'] ??
                    _extractImageFromHtml(item['description']),
                publishedAt: pubDate,
                source: name,
              );
            }).toList();

            debugPrint('✅ $name: RSS2JSON ${items.length} items');
            return items.take(limit).toList();
          }
        }
      } catch (e) {
        debugPrint('⚠️ $name: RSS2JSON failed, trying proxies');
      }

      // Fallback to public CORS proxies
      for (final proxy in _publicProxies) {
        try {
          final proxyUrl = '$proxy${Uri.encodeComponent(cleanUrl)}';
          debugPrint('🔍 $name: Trying $proxy');

          final response = await http
              .get(Uri.parse(proxyUrl))
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            workingBody = _sanitizeBody(response);
            debugPrint('✅ $name: Proxy success');
            break;
          }
        } catch (e) {
          debugPrint('❌ $name: Proxy failed: $e');
          continue;
        }
      }

      if (workingBody == null || workingBody.isEmpty) {
        debugPrint('❌ $name: All methods failed');
        return [];
      }

      // Check if HTML
      if (_isHtmlResponse(workingBody)) {
        debugPrint('⚠️ $name: Got HTML instead of RSS');
        return [];
      }

      // Parse RSS
      if (useWebFeed) {
        try {
          final feed = RssFeed.parse(workingBody);
          final items = feed.items
              .map((item) => _convertRssItemToModel(item, name))
              .toList();

          debugPrint('✅ $name: Parsed ${items.length} items');
          return items.take(limit).toList();
        } catch (e) {
          debugPrint('⚠️ $name: dart_rss failed, trying manual');
        }
      }

      // Manual parse
      final document = XmlDocument.parse(_cleanXmlForParsing(workingBody));
      return document
          .findAllElements('item')
          .take(limit)
          .map((e) => RssItemModel.fromXml(e, sourceName: name))
          .toList();
    } catch (e) {
      debugPrint('❌ $name: $e');
      return [];
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

      // Try public proxies for scraping
      for (final proxy in _publicProxies) {
        try {
          final proxyUrl = '$proxy${Uri.encodeComponent(cleanUrl)}';
          final response = await http
              .get(Uri.parse(proxyUrl))
              .timeout(const Duration(seconds: 10));

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
      final itemSelector = selectors['item'] ?? 'article';
      final elements = document.querySelectorAll(itemSelector);

      debugPrint('🔍 $name: Found ${elements.length} elements');

      final items = <RssItemModel>[];

      for (var i = 0; i < elements.length && i < limit; i++) {
        final element = elements[i];

        String? title;
        String? link;

        // Get title
        final titleSel = selectors['title'];
        if (titleSel == null || titleSel.isEmpty || titleSel == 'self') {
          title = element.text.trim();
          if (title.length < 5) {
            final titleEl = element.querySelector('h1, h2, h3, .title');
            title = titleEl?.text.trim();
          }
        } else {
          title = element.querySelector(titleSel)?.text.trim();
        }

        // Get link
        final linkSel = selectors['link'];
        if (linkSel == null || linkSel.isEmpty || linkSel == 'self') {
          link = element.attributes['href'];
          if (link == null) {
            final linkEl = element.querySelector('a');
            link = linkEl?.attributes['href'];
            if ((title == null || title.isEmpty) && linkEl != null) {
              title = linkEl.text.trim();
            }
          }
        } else {
          link = element.querySelector(linkSel)?.attributes['href'];
        }

        // Skip if no valid data
        if (title == null || title.isEmpty || link == null || link.isEmpty) {
          continue;
        }

        // Resolve relative URL
        if (!link.startsWith('http')) {
          link = _resolveUrl(cleanUrl, link);
        }

        items.add(RssItemModel(
          title: title.trim(),
          link: link,
          description: '',
          pubDate: DateTime.now().toString(),
          source: name,
        ));
      }

      debugPrint('✅ $name: Scraped ${items.length} items');
      return items;
    } catch (e) {
      debugPrint('❌ $name scraping error: $e');
      return [];
    }
  }

  String? _extractImageFromHtml(String? html) {
    if (html == null) return null;
    final match =
        RegExp(r'src="([^"]+\.(?:jpg|jpeg|png|gif|webp))"').firstMatch(html);
    return match?.group(1);
  }

  bool _isHtmlResponse(String body) {
    final trimmed = body.trim().toLowerCase();
    return trimmed.startsWith('<!doctype html') || trimmed.startsWith('<html');
  }

  String _cleanXmlForParsing(String xml) {
    xml = xml.replaceAll(RegExp(r'<!DOCTYPE[^>]*>', caseSensitive: false), '');
    xml = xml.replaceAll(RegExp(r'<!--[\s\S]*?-->', caseSensitive: false), '');

    if (xml.contains('<rss') && xml.contains('</rss>')) {
      final start = xml.indexOf('<rss');
      final end = xml.lastIndexOf('</rss>') + 6;
      if (start >= 0 && end > start) {
        xml = xml.substring(start, end);
      }
    }

    return xml
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }

  RssItemModel _convertRssItemToModel(RssItem item, String sourceName) {
    String? imageUrl;

    if (item.media?.contents?.isNotEmpty ?? false) {
      imageUrl = item.media!.contents!.first.url;
    } else if (item.enclosure?.url != null) {
      imageUrl = item.enclosure!.url;
    } else if (item.description != null) {
      imageUrl = _extractImageFromHtml(item.description);
    }

    return RssItemModel(
      title: item.title ?? 'No Title',
      link: item.link ?? '',
      pubDate: item.pubDate ?? DateTime.now().toString(),
      description: item.description ?? '',
      imageUrl: imageUrl,
      publishedAt:
          item.pubDate != null ? RssItemModel.parseDate(item.pubDate!) : null,
      source: sourceName,
    );
  }

  String _sanitizeBody(http.Response response) {
    String body = response.body;

    if (_looksGarbled(body)) {
      body = utf8.decode(response.bodyBytes, allowMalformed: true);
    }

    body = body.trim();
    if (body.isNotEmpty && body.codeUnitAt(0) == 0xFEFF) {
      body = body.substring(1);
    }
    if (body.startsWith('ï»¿')) {
      body = body.substring(3);
    }

    return body;
  }

  bool _looksGarbled(String text) {
    return text.contains('Ã©') ||
        text.contains('Ã¨') ||
        text.contains('Ã§') ||
        text.contains('Ù') ||
        text.contains('Ø§');
  }

  String _resolveUrl(String base, String relative) {
    if (relative.startsWith('http')) return relative;
    return Uri.parse(base).resolve(relative).toString();
  }
}
