import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../models/rss_item_model.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class GenericRemoteDataSource {
  // Fetches data from a standard website URL (not RSS)
  Future<List<RssItemModel>> fetchWebFeed(String url, {int limit = 0}) async {
    String finalUrl = url;

    // Use proxy for Web
    if (kIsWeb) {
      finalUrl = 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
    }

    try {
      final response = await http.get(Uri.parse(finalUrl));

      if (response.statusCode == 200) {
        final utf8Body = utf8.decode(response.bodyBytes);
        var document = parser.parse(utf8Body);

        List<RssItemModel> items = [];

        // STRATEGY: Find common article containers.
        // We look for <h3> or <h2> tags that usually contain headlines.
        // Then we look for the closest <a> tag (link) and <img> tag.

        // You might need to inspect the Ministry website and change this selector
        // e.g., '.news-item', 'article', '.post'
        final headlines = document.querySelectorAll('h3, h2');

        for (var element in headlines) {
          // Try to find the link inside or near the headline
          dom.Element? linkElement = element.querySelector('a');
          String link = '';
          String title = element.text.trim();

          if (linkElement != null) {
            link = linkElement.attributes['href'] ?? '';
            // Handle relative links (e.g., /news/1)
            if (link.startsWith('/')) {
              final uri = Uri.parse(url);
              link = '${uri.scheme}://${uri.host}$link';
            }
          } else {
            // If no link inside h3, maybe the h3 itself is clickable? (Rare)
            // Or skip if no link found
            if (link.isEmpty) continue;
          }

          // Try to find an image nearby (look in parent or siblings)
          // This is a "best guess" approach
          String? imageUrl;
          dom.Element? parent = element.parent;
          if (parent != null) {
            dom.Element? img = parent.querySelector('img');
            if (img != null) {
              imageUrl = img.attributes['src'];
            }
          }

          // Skip empty items
          if (title.isEmpty) continue;

          items.add(RssItemModel(
            title: title,
            link: link,
            pubDate: DateFormat('yyyy-MM-dd')
                .format(DateTime.now()), // Web scraping often hides dates
            description:
                'Scraped from Web', // Parsing full description is complex without specific CSS selectors
            imageUrl: imageUrl,
            publishedAt: DateTime.now(),
          ));
        }

        if (limit > 0 && items.length > limit) {
          return items.sublist(0, limit);
        }

        return items;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Scraping Error: $e');
      throw Exception('Scraping failed: $e');
    }
  }
}
