// lib/core/services/preload_service.dart
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:rss_dart/dart_rss.dart';
import 'package:news_app/data/models/rss_item_model.dart';

class PreloadService {
  /// Checks if we have preloaded data from JS for the given URL
  static List<RssItemModel>? getPreloadedItems(
      String url, String sourceName, int limit) {
    try {
      // Access the JavaScript object: window.preloadedRssData
      final jsMap = js.context['preloadedRssData'] as js.JsObject?;

      if (jsMap == null) return null;

      // Check if the specific URL key exists
      // Note: JS keys must match exactly what we put in index.html
      final rawRss = jsMap[url] as String?;

      if (rawRss != null && rawRss.isNotEmpty) {
        debugPrint('⚡ [Preload] Found cached data for $sourceName');
        final feed = RssFeed.parse(rawRss);

        return feed.items.take(limit).map((item) {
          return RssItemModel(
            title: item.title ?? 'No Title',
            link: item.link ?? '',
            pubDate: item.pubDate ?? DateTime.now().toString(),
            description: item.description ?? '',
            publishedAt: item.pubDate != null
                ? RssItemModel.parseDate(item.pubDate!)
                : null,
            source: sourceName,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('⚠️ [Preload] Error reading JS data: $e');
    }
    return null;
  }
}
