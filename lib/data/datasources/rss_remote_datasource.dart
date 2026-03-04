// lib/data/datasources/rss_remote_datasource.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:dart_rss/dart_rss.dart';
import 'package:html/parser.dart' show parse;
import '../models/rss_item_model.dart';
import 'package:flutter/foundation.dart';

class RssRemoteDataSource {
  static const List<String> _corsProxies = [
    'https://corsproxy.io/?',
    'https://api.allorigins.win/raw?url=',
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
      String? usedProxy;

      for (final proxy in _corsProxies) {
        try {
          final proxyUrl = '$proxy${Uri.encodeComponent(cleanUrl)}';
          debugPrint('🔍 $name: Trying $proxy');

          final response = await http
              .get(Uri.parse(proxyUrl))
              .timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            workingBody = _sanitizeBody(response);
            usedProxy = proxy;
            debugPrint('✅ $name: Success with ${proxy.split('.').first}');
            break;
          } else {
            debugPrint('⚠️ $name: HTTP ${response.statusCode} from $proxy');
          }
        } catch (e) {
          debugPrint('❌ $name: Proxy $proxy error: $e');
          continue;
        }
      }

      if (workingBody == null || workingBody.isEmpty) {
        debugPrint('❌ $name: All proxies failed or empty response');
        return [];
      }

      // Check if response is HTML instead of XML
      if (_isHtmlResponse(workingBody)) {
        debugPrint(
            '⚠️ $name: Response is HTML, not RSS XML. Use scraping instead.');
        return [];
      }

      // Try dart_rss first
      if (useWebFeed) {
        try {
          final feed = RssFeed.parse(workingBody);
          final items = feed.items
              .map((item) => _convertRssItemToModel(item, name))
              .toList();

          debugPrint('✅ $name: dart_rss parsed ${items.length} items');
          return items.take(limit).toList();
        } catch (e) {
          debugPrint('⚠️ $name: dart_rss failed ($e), trying manual parser');
        }
      }

      // Fallback to manual XML parser with better error handling
      try {
        // Try to clean up common XML issues
        String cleanedXml = _cleanXmlForParsing(workingBody);

        final document = XmlDocument.parse(cleanedXml);
        final items = document.findAllElements('item').toList();

        debugPrint('✅ $name: Manual parser found ${items.length} items');

        return items
            .take(limit)
            .map((e) => RssItemModel.fromXml(e, sourceName: name))
            .toList();
      } catch (e) {
        debugPrint('❌ $name: Manual parser also failed: $e');
        return [];
      }
    } catch (e) {
      debugPrint('❌ $name: Unexpected error: $e');
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

      for (final proxy in _corsProxies) {
        try {
          final proxyUrl = '$proxy${Uri.encodeComponent(cleanUrl)}';
          final response = await http
              .get(Uri.parse(proxyUrl))
              .timeout(const Duration(seconds: 15));

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

      debugPrint(
          '🔍 $name: Found ${elements.length} elements with selector "$itemSelector"');

      final items = <RssItemModel>[];

      for (var i = 0; i < elements.length && i < limit; i++) {
        final element = elements[i];

        String? title;
        String? link;
        String? desc;
        DateTime? pubDate;
        String? imageUrl;

        // Handle different selector types
        final titleSelector = selectors['title'];
        final linkSelector = selectors['link'];
        final descSelector = selectors['desc'];
        final dateSelector = selectors['date'];
        final imageSelector = selectors['image'];

        // Get title - try multiple approaches
        if (titleSelector == null ||
            titleSelector.isEmpty ||
            titleSelector == 'self') {
          // Try element text first
          title = element.text.trim();

          // If empty or too short, look for common title patterns
          if (title.length < 5) {
            final titleEl =
                element.querySelector('h1, h2, h3, .title, .entry-title');
            title = titleEl?.text.trim() ?? element.attributes['title'];
          }
        } else {
          final titleEl = element.querySelector(titleSelector);
          title = titleEl?.text.trim();
        }

        // Get link
        if (linkSelector == null ||
            linkSelector.isEmpty ||
            linkSelector == 'self') {
          link = element.attributes['href'];

          // If element itself doesn't have href, look for child <a>
          if (link == null) {
            final linkEl = element.querySelector('a');
            link = linkEl?.attributes['href'];

            // Also try to get title from link if still empty
            if ((title == null || title.isEmpty) && linkEl != null) {
              title = linkEl.text.trim();
              // Try title attribute if text is empty
              if (title.isEmpty) {
                title = linkEl.attributes['title'];
              }
            }
          }
        } else {
          final linkEl = element.querySelector(linkSelector);
          link = linkEl?.attributes['href'];
        }

        // Get description
        if (descSelector != null &&
            descSelector.isNotEmpty &&
            descSelector != 'self') {
          final descEl = element.querySelector(descSelector);
          desc = descEl?.text.trim();
        }

        // Get date
        if (dateSelector != null &&
            dateSelector.isNotEmpty &&
            dateSelector != 'self') {
          final dateEl = element.querySelector(dateSelector);
          if (dateEl != null) {
            final dateStr = dateEl.attributes['datetime'] ?? dateEl.text;
            pubDate = RssItemModel.parseDate(dateStr);
          }
        }

        // Get image - try multiple approaches
        if (imageSelector != null &&
            imageSelector.isNotEmpty &&
            imageSelector != 'self') {
          final imgEl = element.querySelector(imageSelector);
          imageUrl = imgEl?.attributes['src'];
        } else {
          // Auto-detect image
          final imgEl = element.querySelector('img');
          imageUrl = imgEl?.attributes['src'];
        }

        // Resolve relative URLs
        if (link != null && !link.startsWith('http')) {
          link = _resolveUrl(cleanUrl, link);
        }
        if (imageUrl != null && !imageUrl.startsWith('http')) {
          imageUrl = _resolveUrl(cleanUrl, imageUrl);
        }

        // Clean up title (remove extra whitespace)
        title = title?.replaceAll(RegExp(r'\s+'), ' ').trim();

        // Skip if no valid data
        if (title == null ||
            title.isEmpty ||
            title == 'No Title' ||
            link == null ||
            link.isEmpty) {
          debugPrint(
              '⚠️ $name: Skipping item $i - title: "$title", link: "$link"');
          continue;
        }

        items.add(RssItemModel(
          title: title,
          link: link,
          description: desc ?? '',
          pubDate: pubDate?.toString() ?? DateTime.now().toString(),
          imageUrl: imageUrl,
          publishedAt: pubDate,
          source: name,
        ));
      }

      debugPrint('✅ $name: Scraped ${items.length} valid items');
      return items;
    } catch (e, stackTrace) {
      debugPrint('❌ $name scraping error: $e');
      debugPrint('Stack: $stackTrace');
      return [];
    }
  }

  // Check if response is HTML instead of XML
  bool _isHtmlResponse(String body) {
    final trimmed = body.trim().toLowerCase();
    return trimmed.startsWith('<!doctype html') ||
        trimmed.startsWith('<html') ||
        (trimmed.contains('<html') && trimmed.contains('</html>'));
  }

  // Clean common XML issues
  String _cleanXmlForParsing(String xml) {
    // Remove HTML doctype if present
    xml = xml.replaceAll(RegExp(r'<!DOCTYPE[^>]*>', caseSensitive: false), '');

    // Remove HTML comments
    xml = xml.replaceAll(RegExp(r'<!--[\s\S]*?-->', caseSensitive: false), '');

    // Try to extract RSS content from HTML if wrapped
    if (xml.contains('<rss') && xml.contains('</rss>')) {
      final rssStart = xml.indexOf('<rss');
      final rssEnd = xml.lastIndexOf('</rss>') + 6;
      if (rssStart >= 0 && rssEnd > rssStart) {
        xml = xml.substring(rssStart, rssEnd);
      }
    }

    // Unescape common HTML entities in XML
    xml = xml
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"');

    return xml.trim();
  }

  RssItemModel _convertRssItemToModel(RssItem item, String sourceName) {
    String? imageUrl;

    if (item.media?.contents?.isNotEmpty ?? false) {
      imageUrl = item.media!.contents!.first.url;
    } else if (item.enclosure?.url != null) {
      imageUrl = item.enclosure!.url;
    } else if (item.media?.thumbnails?.isNotEmpty ?? false) {
      imageUrl = item.media!.thumbnails!.first.url;
    } else if (item.description != null) {
      final imgMatch = RegExp(r'src="([^"]+\.(?:jpg|jpeg|png|gif|webp))"')
          .firstMatch(item.description!);
      imageUrl = imgMatch?.group(1);
    }

    DateTime? publishedAt;
    if (item.pubDate != null) {
      publishedAt = RssItemModel.parseDate(item.pubDate!);
    }

    return RssItemModel(
      title: item.title ?? 'No Title',
      link: item.link ?? '',
      pubDate: item.pubDate ?? DateTime.now().toString(),
      description: item.description ?? item.content?.value ?? '',
      imageUrl: imageUrl,
      publishedAt: publishedAt,
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
        text.contains('Ã ') ||
        text.contains('Ã´') ||
        text.contains('Ã§') ||
        text.contains('Ù') ||
        text.contains('Ø§');
  }

  String _resolveUrl(String base, String relative) {
    if (relative.startsWith('http')) return relative;
    final baseUri = Uri.parse(base);
    return baseUri.resolve(relative).toString();
  }
}
