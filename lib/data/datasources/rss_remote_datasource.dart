// lib/data/datasources/rss_remote_datasource.dart
// SIMPLE VERSION - Use this if the above doesn't work

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/rss_item_model.dart';
import 'package:flutter/foundation.dart';

class RssRemoteDataSource {
  Future<List<RssItemModel>> fetchRssFeed(String url,
      {String? sourceName, int limit = 10}) async {
    try {
      final cleanUrl = url.trim();
      if (cleanUrl.isEmpty) return [];

      // Use corsproxy.io (the one that was working)
      final proxyUrl = 'https://corsproxy.io/?$cleanUrl';

      final response = await http
          .get(Uri.parse(proxyUrl))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return [];

      // Use response.body (which was working) but check encoding
      String body = response.body;

      // If it looks garbled, try re-decoding
      if (_looksGarbled(body)) {
        body = utf8.decode(response.bodyBytes, allowMalformed: true);
      }

      // Clean XML
      body = body.trim();
      if (body.startsWith('ï»¿')) {
        // UTF-8 BOM as text
        body = body.substring(3);
      }

      final document = XmlDocument.parse(body);
      final items = document.findAllElements('item').toList();

      debugPrint('✅ $sourceName: ${items.length} articles');

      return items
          .take(limit)
          .map((e) => RssItemModel.fromXml(e, sourceName: sourceName))
          .toList();
    } catch (e) {
      debugPrint('❌ $sourceName: $e');
      return [];
    }
  }

  bool _looksGarbled(String text) {
    // Check for UTF-8 decoded as Latin-1 patterns
    return text.contains('Ã©') || // é
        text.contains('Ã¨') || // è
        text.contains('Ã ') || // à
        text.contains('Ã´') || // ô
        text.contains('Ã§') || // ç
        text.contains('Ù�') || // Arabic lam
        text.contains('Ø§'); // Arabic alef
  }
}
