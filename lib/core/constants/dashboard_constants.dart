// lib/core/constants/dashboard_constants.dart

class DashboardConstants {
  // ═══════════════════════════════════════════════════════════
  // RELIABLE FEEDS (tested working with corsproxy.io)
  // ═══════════════════════════════════════════════════════════

  static const List<Map<String, String>> tunisianFeatured = [
    {'name': 'Mosaïque FM', 'url': 'https://www.mosaiquefm.net/ar/rss'},
    {'name': 'tunisie-news', 'url': 'https://tunisie-news.com/feed/'},
    {'name': 'وزارة الداخلية', 'url': 'https://www.interieur.gov.tn/ar/feed'},
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

    // --- REMOVED: Madhyamam and Ynetnews (RSS feeds broken/unavailable) ---
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
}
