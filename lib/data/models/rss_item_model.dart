// lib/data/models/rss_item_model.dart
import 'package:xml/xml.dart';
import 'package:intl/intl.dart';

class RssItemModel {
  final String title;
  final String link;
  final String pubDate;
  final String description;
  final String? imageUrl;
  final DateTime? publishedAt;
  final String? source;

  RssItemModel({
    required this.title,
    required this.link,
    required this.pubDate,
    required this.description,
    this.imageUrl,
    this.publishedAt,
    this.source,
  });

  factory RssItemModel.fromXml(XmlElement element, {String? sourceName}) {
    String getText(String tag) {
      final el = element.findElements(tag).firstOrNull;
      return el?.innerText.trim() ?? '';
    }

    final title = getText('title');
    final link = getText('link');
    final pubDateStr = getText('pubDate');
    final description = getText('description');

    // Parse date with multiple format attempts
    DateTime? publishedAt = parseDate(pubDateStr);

    // Extract image
    String? imageUrl;
    final mediaContent = element.findElements('media:content').firstOrNull;
    final enclosure = element.findElements('enclosure').firstOrNull;
    final mediaThumbnail = element.findElements('media:thumbnail').firstOrNull;

    if (mediaContent != null) {
      imageUrl = mediaContent.getAttribute('url');
    } else if (enclosure != null) {
      imageUrl = enclosure.getAttribute('url');
    } else if (mediaThumbnail != null) {
      imageUrl = mediaThumbnail.getAttribute('url');
    }

    // Extract from description if still null
    if (imageUrl == null || imageUrl.isEmpty) {
      final imgMatch = RegExp(r'src="([^"]+\.(?:jpg|jpeg|png|gif|webp))"')
          .firstMatch(description);
      imageUrl = imgMatch?.group(1);
    }

    return RssItemModel(
      title: title.isEmpty ? 'No title' : title,
      link: link,
      pubDate: pubDateStr,
      description: description,
      imageUrl: imageUrl,
      publishedAt: publishedAt,
      source: sourceName,
    );
  }

  // Static parser that can be used by both manual and WebFeed converters
  static DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;

    final formats = [
      'E, d MMM yyyy HH:mm:ss Z',
      'E, d MMM yyyy HH:mm:ss z',
      'E, d MMM yyyy HH:mm:ss zzzz',
      'yyyy-MM-ddTHH:mm:ssZ',
      'yyyy-MM-ddTHH:mm:ss.SSSZ',
      'yyyy-MM-dd HH:mm:ss',
      'd MMM yyyy HH:mm:ss Z',
      'E MMM dd HH:mm:ss Z yyyy',
    ];

    for (final format in formats) {
      try {
        return DateFormat(format, 'en_US').parse(dateStr);
      } catch (_) {}
    }

    try {
      return DateTime.parse(dateStr);
    } catch (_) {}

    final cleaned = dateStr
        .replaceAll('GMT', '+0000')
        .replaceAll('UTC', '+0000')
        .replaceAll('UT', '+0000');

    for (final format in formats) {
      try {
        return DateFormat(format, 'en_US').parse(cleaned);
      } catch (_) {}
    }

    return null;
  }
}
