// lib/core/constants/dashboard_constants.dart
import 'package:news_app/data/models/news_source.dart';

class DashboardConstants {
  // ═══════════════════════════════════════════════════════════
  // RAW LISTS (Used for Dashboard Widgets, Horizontal Lists, etc.)
  // ═══════════════════════════════════════════════════════════

  static const List<Map<String, String>> tunisianFeatured = [
    {'name': 'Mosaïque FM', 'url': 'https://www.mosaiquefm.net/ar/rss'},
    {'name': 'وزارة الداخلية', 'url': 'https://www.interieur.gov.tn/ar/feed'},
    {
      'name': 'La Presse',
      'url': 'https://www.lapresse.tn/category/actualites/feed'
    },
  ];

  static const List<Map<String, String>> moroccanFeatured = [
    {'name': 'Le360', 'url': 'https://fr.le360.ma/rss'},
    {'name': 'Hespress', 'url': 'https://www.hespress.com/feed'},
    {'name': 'Aujourd\'hui le Maroc', 'url': 'https://aujourdhui.ma/feed'},
    {
      'name': 'Morocco World News',
      'url': 'https://www.moroccoworldnews.com/feed/'
    },
  ];

  static const List<Map<String, String>> algerianFeatured = [
    {'name': 'TSA', 'url': 'https://www.tsa-algerie.com/feed/'},
    {'name': 'El Watan', 'url': 'https://elwatan.dz/feed/'},
    {'name': 'Liberté', 'url': 'https://www.liberte-algerie.com/feed/'},
    {'name': 'Algerie360', 'url': 'https://www.algerie360.com/feed/'},
    {'name': 'El Khabar', 'url': 'https://elkhabar.com/feed/'},
  ];

  static const List<Map<String, String>> internationalFeatured = [
    // --- Core Sources ---
    {
      'name': 'Al Jazeera English',
      'url': 'https://www.aljazeera.com/xml/rss/all.xml'
    },
    {
      'name': 'Al Jazeera Arabic',
      'url':
          'https://www.aljazeera.net/aljazeerarss/a7c186be-1baa-4bd4-9d80-a84db769f779/73d0e1b4-532f-45ef-b135-bfdff8b8cab9'
    },
    {'name': 'BBC', 'url': 'http://feeds.bbci.co.uk/news/rss.xml'},
    {
      'name': 'Reuters',
      'url':
          'https://news.google.com/rss/search?q=site%3Areuters.com&hl=en-US&gl=US&ceid=US%3Aen'
    },
    {'name': 'CNN', 'url': 'http://rss.cnn.com/rss/edition.rss'},
    {
      'name': 'NYT World',
      'url': 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml'
    },
    {'name': 'The Guardian', 'url': 'https://www.theguardian.com/world/rss'},

    // --- Verified New Sources ---
    {
      'name': 'The Moscow Times',
      'url': 'https://www.themoscowtimes.com/rss/news'
    },
    {'name': 'Kyiv Post', 'url': 'https://www.kyivpost.com/feed/'},
    {'name': 'Neos Kosmos', 'url': 'https://neoskosmos.com/en/feed/'},
    {'name': 'Indian Express', 'url': 'https://indianexpress.com/feed/'},
    {'name': 'Euronews', 'url': 'https://www.euronews.com/rss'},
    {
      'name': 'AP News',
      'url':
          'https://news.google.com/rss/search?q=site:apnews.com&hl=en-US&gl=US&ceid=US:en'
    },
    {'name': '7News Australia', 'url': 'https://7news.com.au/rss'},
    {
      'name': 'TRT World',
      'url':
          'https://news.google.com/rss/search?q=site:trtworld.com&hl=en-US&gl=US&ceid=US:en'
    },
  ];

  static const List<Map<String, String>> iranianFeatured = [
    {'name': 'Mehr News', 'url': 'https://en.mehrnews.com/rss'},
    {
      'name': 'Tasnim News',
      'url': 'https://www.tasnimnews.ir/en/rss/feed/0/0/8/1/TopStories'
    },
    {'name': 'Tehran Times', 'url': 'https://www.tehrantimes.com/rss'},
    {'name': 'Fars News', 'url': 'https://www.farsnews.ir/en/rss'},
  ];

  // ═══════════════════════════════════════════════════════════
  // CONSOLIDATED SOURCES (For Detailed Screens)
  // ═══════════════════════════════════════════════════════════

  /// Returns all Tunisian sources (Basic + Scrapable) for the TunisianNewsScreen
  static List<NewsSource> get allTunisianSources {
    return [
      // 1. Basic RSS Feeds
      ...tunisianFeatured.map((e) => NewsSource(
            name: e['name']!,
            url: e['url']!,
            type: SourceType.rss,
          )),

      // 2. Additional RSS Feeds specific to the screen

      NewsSource(
          name: 'Jawhara FM',
          url: 'https://www.jawharafm.net/ar/rss/showRss/88/1/1'),
      NewsSource(
          name: 'Express FM', url: 'https://www.radioexpressfm.com/ar/rss'),
      NewsSource(
          name: 'Tunisie Focus',
          url: 'https://www.tunisiefocus.com/category/politique/feed'),
      NewsSource(name: 'babnet', url: 'https://www.babnet.net/feed.php'),
      NewsSource(
          name: 'jeuneafrique', url: 'https://www.jeuneafrique.com/feed/'),

      // 3. Scrapable Sources
      NewsSource(
        name: 'التلفزة التونسية',
        url:
            'https://www.tunisiatv.tn/ar/articles/1/693ff922b922dd47f3ea53c3/%D8%A7%D8%AE%D8%A8%D8%A7%D8%B1%D9%86%D8%A7',
        type: SourceType.scrapable,
        selectors: {
          'item': 'article, .article, .news-item, .item, .col-md-4, .col-lg-4',
          'title': 'h3, .title, .article-title, h2, h4',
          'link': 'a[href*="/articles/"], a[href*="/ar/"]',
          'desc': '',
          'date': '.date, time, .published-date',
          'image': 'img, .article-image img',
        },
      ),
    ];
  }

  /// Returns all International sources for the InternationalNewsScreen
  static List<NewsSource> get allInternationalSources {
    return [
      // 1. Core International RSS Feeds
      ...internationalFeatured.map((e) => NewsSource(
            name: e['name']!,
            url: e['url']!,
            type: SourceType.rss,
          )),

      // 2. Additional sources that were hardcoded in the screen
      NewsSource(
          name: 'Sky News Arabia', url: 'https://www.skynewsarabia.com/rss'),
      NewsSource(
          name: 'The Hindu',
          url: 'https://www.thehindu.com/news/international/?service=rss'),
    ];
  }
}
