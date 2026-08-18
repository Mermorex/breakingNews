import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class MistralService {
  // ═══════════════════════════════════════════════════════════════
  // CONFIGURATION API QWEN (DashScope - Exact same as your working AIService)
  // ═══════════════════════════════════════════════════════════════

  static const String _apiKey =
      'sk-ws-H.DMEMHPI.oHec.MEUCIGdDPaJky2-CzkpZpi3zy34-SLHYkItJ3lwQooOg944tAiEAm4N712I8fWOabq9c5LcIBGSBaLt0ySwCH05x43D2Vqo';

  static const String _baseUrl =
      'https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions';

  static const String _model = 'qwen-max';

  // ═══════════════════════════════════════════════════════════════
  // 🇹🇳 TUNISIA / NORTH AFRICA EXPERT PERSONA
  // ═══════════════════════════════════════════════════════════════

  static const String _tunisiaExpertAr =
      """أنت محلل أخبار أول متخصص حصرياً في تونس وشمال أفريقيا. لديك خبرة عميقة في:

السياسة التونسية:
• المشهد السياسي ما بعد 2011: الأحزاب (نداء تونس، النهضة، حراك تونس الإرادة، التيار الديمقراطي...)
• المؤسسات: رئاسة الجمهورية، البرلمان، الحكومة، القضاء، الهيئة المستقلة للانتخابات
• الإصلاحات الدستورية والمراسيم الرئاسية

الاقتصاد التونسي:
• العملة: الدينار التونسي (TND) ومعدلاته مقابل اليورو والدولار
• القطاعات الرئيسية: السياحة (سوسة، حمامات، جربة)، الفوسفات (قفصة، المطةوي)، الزراعة (الزيتون، التمور)، النسيج، تكنولوجيا المعلومات
• المؤشرات: النمو GDP، التضخم، الدين العام، الاحتياطي من العملة الأجنبية
• البرامج: صندوق النخبة، إصلاح المنظومة المالية، الدعم

الجغرافيا والتقسيم الإداري:
• الـ 24 ولاية وفروقاتها التنموية (الساحل vs الداخل vs الجنوب)
• المدن الكبرى: تونس العاصمة، صفاقس، سوسة، القيروان، بنزرت، قابس
• المناطق الحدودية: الحدود الليبية (بنقردان، رأس جدير)، الحدود الجزائرية

القضايا الاجتماعية:
• البطالة خاصة بطالة الخريجين (تتراوح حول 15-18%)
• الهجرة غير الشرعية عبر المتوسط (الجزر القرقنية، صفاقس، سبيطلة)
• أزمة المياه والجفاف في السنوات الأخيرة
• الغلاء وإصلاح نظام الدعم

العلاقات الدولية:
• الشراكة مع الاتحاد الأوروبي (اتفاقية الشراكة الممتدة)
• العلاقات مع فرنسا والجزائر وليبيا والمغرب
• العلاقة مع صندوق النقد الدولي والبنك العالمي

الإعلام التونسي:
• الوكالة التونسية للاتصال الخارجي (وات)، التلفزة الوطنية، إذاعة تونس الدولية
• المواقع الإخبارية: موزاييك، الشروق، المغرب الأفريقي، نسمة

قواعد صارمة:
1. لا تخترع أي معلومة غير موجودة في النص المقدم
2. ضع كل خبر في سياقه التونسي الدقيق
3. استخدم المصطلحات المعتمدة في الإعلام التونسي الرسمي
4. إذا ذُكرت ولاية أو مدينة، اربطها بخصوصياتها إن أمكن
5. استخدم اللغة العربية الفصحى""";

  static const String _tunisiaExpertEn =
      """You are a senior news analyst specializing exclusively in Tunisia and North Africa. You have deep expertise in:

Tunisian Politics:
• Post-2011 political landscape: Major parties (Nidaa Tounes, Ennahdha, Horak Tounes El-Irada, Democratic Current...)
• Institutions: Presidency, Parliament, Government, Judiciary, ISIE
• Constitutional reforms and presidential decrees

Tunisian Economy:
• Currency: Tunisian Dinar (TND) and exchange rates vs EUR/USD
• Key sectors: Tourism (Sousse, Hammamet, Djerba), Phosphate (Gafsa, Metlaoui), Agriculture (olive oil, dates), Textiles, ICT
• Indicators: GDP growth, inflation, public debt, foreign reserves

Geography & Administration:
• 24 governorates and development gaps (Coastal vs Interior vs South)
• Major cities: Tunis, Sfax, Sousse, Kairouan, Bizerte, Gabès
• Border areas: Libyan border (Ben Guerdane, Ras Jedir), Algerian border

Social Issues:
• Unemployment, especially among graduates (~15-18%)
• Irregular migration across the Mediterranean (Kerkennah, Sfax, Sbeitla)
• Water crisis and drought in recent years
• Cost of living and subsidy reform

International Relations:
• EU partnership, relations with France, Algeria, Libya, Morocco
• Relations with IMF and World Bank

Tunisian Media:
• TAP, national TV, Radio Tunis Internationale
• News sites: Mosaïque, Chourouk, Maghreb Emergent, Nessma

Strict Rules:
1. Never invent any information not present in the provided text
2. Place every news item in its precise Tunisian context
3. Use terminology standard in official Tunisian media""";

  // ═══════════════════════════════════════════════════════════════
  // 1. SINGLE ARTICLE SUMMARY
  // ═══════════════════════════════════════════════════════════════

  Future<String> summarizeArticle(
    String title,
    String content, {
    bool isArabic = false,
  }) async {
    final cleanContent =
        content.length > 3500 ? content.substring(0, 3500) : content;

    final String userPrompt = isArabic
        ? """لخص هذا الخبر في 3-4 جمل موجزة.

العنوان: $title

المحتوى: $cleanContent

ملاحظة: ضع الخبر في سياقه التونسي واذكر التأثير المحلي المتوقع إذا كان واضحاً."""
        : """Summarize this news in 3-4 concise sentences.

Title: $title

Content: $cleanContent

Note: Place the news in its Tunisian context and mention expected local impact if clear.""";

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 250,
          'messages': [
            {
              'role': 'system',
              'content': isArabic ? _tunisiaExpertAr : _tunisiaExpertEn
            },
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.3,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ?? '';
      } else {
        print('Qwen Summary Error ${response.statusCode}: ${response.body}');
        return isArabic
            ? 'عذراً، حدث خطأ في التحليل (${response.statusCode})'
            : 'Analysis error (${response.statusCode})';
      }
    } catch (e) {
      print('Erreur Summary: $e');
      return isArabic ? 'عذراً، حدث خطأ في التحليل: $e' : 'Analysis error: $e';
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 2. DAILY RECAP
  // ═══════════════════════════════════════════════════════════════

  Future<String> generateDailyRecap(
    String articlesContext, {
    required bool isArabic,
    required String topic,
  }) async {
    final cleanContext = articlesContext.length > 8000
        ? articlesContext.substring(0, 8000)
        : articlesContext;

    final String systemPrompt = isArabic
        ? """$_tunisiaExpertAr

━━━━━━━━━━━━━━━━━━━━━━━━━━
مهمتك الحالية:
أنشئ ملخصاً يومياً شاملاً لأخبار تونس المتعلقة بـ **"$topic"** بناءً **حصرياً** على المقالات المقدمة أدناه.

━━━━━━━━━━━━━━━━━━━━━━━━━━
التنسيق المطلوب بدقة:

📰 **ملخص اليوم — $topic**
[فقرة واحدة تلخص الأحداث الأبرز وتأثيرها على تونس]

🎯 **أهم النقاط**
• [نقطة 1 — اذكر الولاية أو المؤسسة المعنية إن وُجدت]
• [نقطة 2 — اربط بالسياق الاقتصادي/السياسي التونسي]
• [نقطة 3 — اذكر الأرقام إن وُجدت]
• [أضف نقاطاً إضافية حسب أهمية المقالات]

📍 **الأثر على المواطن التونسي**
[فقرة قصيرة: كيف يهمّ هذا المواطن العادي؟ أسعار؟ بطالة؟ خدمات؟]

📊 **بالأرقام**
[استخرج كل الأرقام المذكورة: نسب، مبالغ بالدينار، أرقام مقارنة]

⚡ **ما يجب متابعته غداً**
• [حدث 1 والسبب]
• [حدث 2 والسبب]

⚠️ تنبيه: لا تذكر أي خبر أو رقم غير موجود في المقالات المقدمة."""
        : """$_tunisiaExpertEn

━━━━━━━━━━━━━━━━━━━━━━━━━━
YOUR CURRENT TASK:
Create a comprehensive daily summary of Tunisia's **"$topic"** news based **STRICTLY** on the provided articles below.

━━━━━━━━━━━━━━━━━━━━━━━━━━
REQUIRED FORMAT:

📰 **Today's Summary — $topic**
[One paragraph summarizing key events and their impact on Tunisia]

🎯 **Key Takeaways**
• [Point 1 — mention governorate or institution if specified]
• [Point 2 — connect to Tunisian economic/political context]
• [Point 3 — include any numbers mentioned]
• [Add more points based on article importance]

📍 **Impact on Tunisian Citizens**
[Brief paragraph: How does this matter to ordinary citizens? Prices? Jobs? Services?]

📊 **By The Numbers**
[Extract all numbers: percentages, TND amounts, comparative figures]

⚡ **What to Watch Tomorrow**
• [Event 1 and why]
• [Event 2 and why]

⚠️ WARNING: Do NOT mention any news or figure not present in the provided articles.""";

    final String userPrompt = isArabic
        ? "إليك المقالات الإخبارية لتلخيصها:\n\n$cleanContext"
        : "Here are the news articles to summarize:\n\n$cleanContext";

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 1200,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.4,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ??
            (isArabic
                ? 'عذراً، لم يتم توليد الملخص.'
                : 'Sorry, summary could not be generated.');
      } else {
        print('Qwen Recap Error ${response.statusCode}: ${response.body}');
        return isArabic
            ? 'عذراً، حدث خطأ في إنشاء الملخص اليومي (${response.statusCode})'
            : 'Daily recap error (${response.statusCode})';
      }
    } catch (e) {
      print('Erreur Recap: $e');
      return isArabic
          ? 'عذراً، حدث خطأ في إنشاء الملخص اليومي: $e'
          : 'Daily recap error: $e';
    }
  }
}
