import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class MistralService {
  // Get key from: https://console.mistral.ai/
  static const String _apiKey = '7ZLG8ATJrgrx2nRQEqMv1U1o09nH5fVN';
  static const String _baseUrl = 'https://api.mistral.ai/v1/chat/completions';

  // UPDATED: Added isArabic parameter
  Future<String> summarizeArticle(String title, String content,
      {bool isArabic = false}) async {
    final cleanContent =
        content.length > 3000 ? content.substring(0, 3000) : content;

    // UPDATED: Dynamic prompt based on language
    final String instruction = isArabic
        ? "لخص هذا الخبر في 2-3 جمل باللغة العربية:" // Summarize in Arabic
        : "Summarize this news in 2-3 sentences in English:";

    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              "model": "mistral-small-latest",
              "messages": [
                {
                  "role": "user",
                  "content":
                      "$instruction\nTitle: $title\n\nContent: $cleanContent"
                }
              ],
              "temperature": 0.3,
              "max_tokens": 150,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].trim();
      } else {
        debugPrint('Mistral Error: ${response.body}');
        return 'Error: API failed (${response.statusCode})';
      }
    } catch (e) {
      debugPrint('Mistral Exception: $e');
      return 'Error: $e';
    }
  }
}
