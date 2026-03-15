import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class MistralService {
  static const String _apiKey = '7ZLG8ATJrgrx2nRQEqMv1U1o09nH5fVN';
  static const String _baseUrl = 'https://api.mistral.ai/v1/chat/completions';

  // --- SINGLE ARTICLE SUMMARY ---
  Future<String> summarizeArticle(String title, String content,
      {bool isArabic = false}) async {
    final cleanContent =
        content.length > 3000 ? content.substring(0, 3000) : content;

    final String instruction = isArabic
        ? "لخص هذا الخبر في 2-3 جمل باللغة العربية:"
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
        return 'Error: API failed (${response.statusCode})';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  // NEW: Generate daily recap from multiple articles
  // ADDED 'topic' as a required named parameter
  Future<String> generateDailyRecap(
    String articlesContext, {
    required bool isArabic,
    required String topic,
  }) async {
    // Limit context length to avoid token limits
    final cleanContext = articlesContext.length > 8000
        ? articlesContext.substring(0, 8000)
        : articlesContext;

    // Dynamic prompt based on language and topic
    final String systemPrompt = isArabic
        ? """أنت محلل أخبار محترف. قم بإنشاء ملخص يومي شامل لأخبار $topic بناءً **حصرياً** على المقالات المقدمة.

قواعد صارمة:
1. لا تخترع أخباراً غير موجودة في النص المقدم.
2. ركز على الأخبار الأكثر أهمية وتأثيراً المتعلقة بـ $topic.
3. استخدم لغة عربية فصحى واضحة.

التنسيق المطلوب:
📰 **العناوين الرئيسية**
[ملخص عام للأحداث الأكثر أهمية في فقرة واحدة]

🎯 **أهم النقاط**
• [نقطة رئيسية 1]
• [نقطة رئيسية 2]
• [نقطة رئيسية 3]

⚡ **تطورات جارية**
[أي أخبار تتطلب متابعة مستقبلية إذا وجدت]"""
        : """You are a professional news analyst. Create a comprehensive daily summary of $topic news based **strictly** on the provided articles.

Strict Rules:
1. Do not invent news not present in the provided text.
2. Focus on high-impact events related to $topic.

Required Format:
📰 **Headlines**
[General summary of the most important events in one paragraph]

🎯 **Key Takeaways**
• [Key point 1]
• [Key point 2]
• [Key point 3]

⚡ **Ongoing Developments**
[Any news requiring future follow-up if applicable]""";

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
                  "role": "system",
                  "content": systemPrompt,
                },
                {
                  "role": "user",
                  "content": "Here are the articles:\n\n$cleanContext",
                }
              ],
              "temperature": 0.4,
              "max_tokens": 800,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].trim();
      } else {
        debugPrint('Mistral Daily Recap Error: ${response.body}');
        return isArabic
            ? 'عذراً، حدث خطأ في إنشاء الملخص اليومي. (${response.statusCode})'
            : 'Sorry, error generating daily summary. (${response.statusCode})';
      }
    } catch (e) {
      debugPrint('Mistral Daily Recap Exception: $e');
      return isArabic ? 'عذراً، حدث خطأ: $e' : 'Error: $e';
    }
  }
}
