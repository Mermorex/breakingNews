// lib/data/models/rss_item_model.dart
import 'package:xml/xml.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

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

  // ✅ SIMPLIFIED: Always show relative time, fallback to "Today" if date is wrong
  String get displayTime {
    // If no parsed date or date is in the future (wrong), use now
    final effectiveDate =
        (publishedAt == null || publishedAt!.isAfter(DateTime.now()))
            ? DateTime.now()
            : publishedAt!;

    final now = DateTime.now();
    final difference = now.difference(effectiveDate);

    // Simple relative time
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 30) return '${difference.inDays}d ago';

    // Old articles show actual date or fallback
    return pubDate.isNotEmpty
        ? pubDate
        : '${effectiveDate.day}/${effectiveDate.month}/${effectiveDate.year}';
  }

  factory RssItemModel.fromXml(XmlElement element, {String? sourceName}) {
    String getText(String tag) {
      try {
        final el = element.findElements(tag).firstOrNull;
        return el?.innerText.trim() ?? '';
      } catch (e) {
        return '';
      }
    }

    // Handle both RSS <item> and Atom <entry>
    final isAtom = element.name.local == 'entry';

    String title;
    String link;
    String pubDateStr;
    String description;

    if (isAtom) {
      // Atom format
      title = getText('title');
      pubDateStr = getText('updated'); // Atom uses 'updated' or 'published'
      if (pubDateStr.isEmpty) pubDateStr = getText('published');
      description = getText('summary');
      if (description.isEmpty) description = getText('content');

      // Atom links are in <link href="..."/>
      final linkEl = element.findElements('link').firstOrNull;
      link = linkEl?.getAttribute('href') ?? '';
    } else {
      // RSS format
      title = getText('title');
      link = getText('link');
      pubDateStr = getText('pubDate');
      if (pubDateStr.isEmpty) pubDateStr = getText('dc:date'); // Dublin Core
      description = getText('description');
      if (description.isEmpty) description = getText('content:encoded');
    }

    // Fallback to guid if no link
    if (link.isEmpty) {
      final guid = element.findElements('guid').firstOrNull;
      final isPermaLink = guid?.getAttribute('isPermaLink') ?? 'false';
      if (isPermaLink == 'true') {
        link = guid?.innerText.trim() ?? '';
      }
    }

    // Parse date
    DateTime? publishedAt = parseDate(pubDateStr);

    // Extract image (try multiple methods)
    String? imageUrl = _extractImage(element, description);

    return RssItemModel(
      title: title.isEmpty ? 'No title' : _cleanHtml(title),
      link: link,
      pubDate: pubDateStr,
      description: _cleanHtml(description),
      imageUrl: imageUrl,
      publishedAt: publishedAt,
      source: sourceName,
    );
  }

  static String? _extractImage(XmlElement element, String description) {
    String? imageUrl;

    // Try media:content
    final mediaContent = element.findElements('media:content').firstOrNull ??
        element
            .findElements('media:group')
            .firstOrNull
            ?.findElements('media:content')
            .firstOrNull;
    if (mediaContent != null) {
      imageUrl = mediaContent.getAttribute('url');
      // Check for type="image/*"
      final type = mediaContent.getAttribute('type') ?? '';
      if (imageUrl != null && !type.startsWith('image/') && type.isNotEmpty) {
        imageUrl = null; // Reset if not an image
      }
    }

    // Try enclosure
    if (imageUrl == null || imageUrl.isEmpty) {
      final enclosure = element.findElements('enclosure').firstOrNull;
      final type = enclosure?.getAttribute('type') ?? '';
      if (type.startsWith('image/') || type.isEmpty) {
        imageUrl = enclosure?.getAttribute('url');
      }
    }

    // Try media:thumbnail
    if (imageUrl == null || imageUrl.isEmpty) {
      final mediaThumbnail =
          element.findElements('media:thumbnail').firstOrNull;
      imageUrl = mediaThumbnail?.getAttribute('url');
    }

    // Try Atom media
    if (imageUrl == null || imageUrl.isEmpty) {
      final content = element.findElements('content').firstOrNull;
      final type = content?.getAttribute('type') ?? '';
      if (type.startsWith('image/')) {
        imageUrl = content?.getAttribute('src');
      }
    }

    // Extract from description/content HTML (case insensitive)
    if ((imageUrl == null || imageUrl.isEmpty) && description.isNotEmpty) {
      final imgMatch = RegExp(
        'src=["\']([^"\'>]+\\.(?:jpg|jpeg|png|gif|webp))["\']',
        caseSensitive: false,
      ).firstMatch(description);
      imageUrl = imgMatch?.group(1);
    }

    // Clean up URL
    if (imageUrl != null && imageUrl.isEmpty) {
      imageUrl = null;
    }

    return imageUrl;
  }

  // Clean HTML entities and tags
  static String _cleanHtml(String text) {
    if (text.isEmpty) return text;

    return text
        .replaceAll(RegExp(r'<[^>]+>'), '') // Remove HTML tags
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  // Static parser that can be used by both manual and WebFeed converters
  static DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;

    final formats = [
      'E, d MMM yyyy HH:mm:ss Z',
      'E, d MMM yyyy HH:mm:ss z',
      'E, d MMM yyyy HH:mm:ss zzzz',
      'yyyy-MM-dd\'T\'HH:mm:ssZ',
      'yyyy-MM-dd\'T\'HH:mm:ss.SSSZ',
      'yyyy-MM-dd\'T\'HH:mm:ss',
      'yyyy-MM-dd HH:mm:ss',
      'd MMM yyyy HH:mm:ss Z',
      'E MMM dd HH:mm:ss Z yyyy',
      'yyyy-MM-dd',
    ];

    // Try formats as-is
    for (final format in formats) {
      try {
        return DateFormat(format, 'en_US').parse(dateStr);
      } catch (_) {}
    }

    // Try ISO 8601
    try {
      return DateTime.parse(dateStr);
    } catch (_) {}

    // Clean and retry
    final cleaned = dateStr
        .replaceAll('GMT', '+0000')
        .replaceAll('UTC', '+0000')
        .replaceAll('UT', '+0000')
        .replaceAllMapped(
            RegExp(r'([+-]\d{2}):(\d{2})$'), (m) => '${m[1]}${m[2]}');

    for (final format in formats) {
      try {
        return DateFormat(format, 'en_US').parse(cleaned);
      } catch (_) {}
    }

    debugPrint('⚠️ Could not parse date: $dateStr');
    return null;
  }

  // Useful for updating items
  RssItemModel copyWith({
    String? title,
    String? link,
    String? pubDate,
    String? description,
    String? imageUrl,
    DateTime? publishedAt,
    String? source,
  }) {
    return RssItemModel(
      title: title ?? this.title,
      link: link ?? this.link,
      pubDate: pubDate ?? this.pubDate,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      source: source ?? this.source,
    );
  }

  @override
  String toString() {
    return 'RssItemModel(title: $title, source: $source, pubDate: $pubDate)';
  }
}
