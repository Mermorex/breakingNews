// lib/data/models/news_source.dart

class NewsSource {
  final String name;
  final String url;
  final SourceType type;
  final Map<String, String>? selectors;
  final bool useWebFeed;
  final Map<String, String>? headers;
  final String? countryCode; // Added for flag display
  final String? category; // Added for sub-filtering (politics, tech, etc.)

  NewsSource({
    required this.name,
    required this.url,
    this.type = SourceType.rss,
    this.selectors,
    this.useWebFeed = true,
    this.headers,
    this.countryCode,
    this.category,
  });
}

enum SourceType { rss, scrapable, jsonApi, reddit }

class NewsSources {
  // ==========================================
  // TUNISIAN SOURCES
  // ==========================================
  static final List<NewsSource> tunisian = [
    NewsSource(name: 'Mosaïque FM', url: 'https://www.mosaiquefm.net/ar/rss'),
    NewsSource(
        name: 'La Presse',
        url: 'https://www.lapresse.tn/category/actualites/feed'),
    NewsSource(
      name: 'Jawhara FM',
      url: 'https://www.jawharafm.net/ar/rss/showRss/88/1/17',
      type: SourceType.rss,
    ),
    NewsSource(
      name: 'Express FM',
      url: 'https://radioexpressfm.com/ar/feed/',
      type: SourceType.rss,
    ),
    NewsSource(
        name: 'Tunisie Focus',
        url: 'https://www.tunisiefocus.com/category/politique/feed'),
    NewsSource(name: 'Babnet', url: 'https://www.babnet.net/feed.php'),
    NewsSource(
        name: 'Jeune Afrique', url: 'https://www.jeuneafrique.com/feed/'),
    NewsSource(name: 'Al Chourouk', url: 'https://www.alchourouk.com/rss'),
    NewsSource(
        name: 'Business News', url: 'https://www.businessnews.com.tn/feed'),
    NewsSource(name: 'Nawaat', url: 'https://nawaat.org/feed/'),
  ];
  // MOROCCAN SOURCES (MA)
  // ==========================================
  static final List<NewsSource> moroccan = [
    NewsSource(
      name: 'Le360',
      url: 'https://fr.le360.ma/rss',
      countryCode: 'MA',
    ),
    NewsSource(
      name: 'Hespress',
      url: 'https://www.hespress.com/feed',
      countryCode: 'MA',
    ),
    NewsSource(
      name: 'Aujourd\'hui le Maroc',
      url: 'https://aujourdhui.ma/feed',
      countryCode: 'MA',
    ),
    NewsSource(
      name: 'Morocco World News',
      url: 'https://www.moroccoworldnews.com/feed/',
      countryCode: 'MA',
    ),
  ];

  // ==========================================
  // ALGERIAN SOURCES (DZ)
  // ==========================================
  static final List<NewsSource> algerian = [
    NewsSource(
      name: 'TSA',
      url: 'https://www.tsa-algerie.com/feed/',
      countryCode: 'DZ',
    ),
    NewsSource(
      name: 'El Watan',
      url: 'https://elwatan.dz/feed/',
      countryCode: 'DZ',
    ),
    NewsSource(
      name: 'Liberté',
      url: 'https://www.liberte-algerie.com/feed/',
      countryCode: 'DZ',
    ),
    NewsSource(
      name: 'Algerie360',
      url: 'https://www.algerie360.com/feed/',
      countryCode: 'DZ',
    ),
    NewsSource(
      name: 'El Khabar',
      url: 'https://elkhabar.com/feed/',
      countryCode: 'DZ',
    ),
  ];

  // ==========================================
  // IRANIAN SOURCES (IR)
  // ==========================================
  static final List<NewsSource> iranian = [
    NewsSource(
      name: 'Mehr News',
      url: 'https://en.mehrnews.com/rss',
      countryCode: 'IR',
    ),
    NewsSource(
      name: 'Tasnim News',
      url: 'https://www.tasnimnews.ir/en/rss/feed/0/0/8/1/TopStories',
      countryCode: 'IR',
    ),
    NewsSource(
      name: 'Tehran Times',
      url: 'https://www.tehrantimes.com/rss',
      countryCode: 'IR',
    ),
    NewsSource(
      name: 'Fars News',
      url: 'https://www.farsnews.ir/en/rss',
      countryCode: 'IR',
    ),
  ];

  // ==========================================
  // INTERNATIONAL SOURCES
  // ==========================================
  static final List<NewsSource> international = [
    // Middle East
    NewsSource(
      name: 'Al Jazeera English',
      url: 'https://www.aljazeera.com/xml/rss/all.xml',
      countryCode: 'QA',
    ),
    NewsSource(
      name: 'Al Jazeera Arabic',
      url:
          'https://www.aljazeera.net/aljazeerarss/a7c186be-1baa-4bd4-9d80-a84db769f779/73d0e1b4-532f-45ef-b135-bfdff8b8cab9',
      countryCode: 'QA',
    ),
    NewsSource(
      name: 'Sky News Arabia',
      url: 'https://www.skynewsarabia.com/rss',
      countryCode: 'AE',
    ),

    // Global English
    NewsSource(
      name: 'BBC',
      url: 'http://feeds.bbci.co.uk/news/rss.xml',
      countryCode: 'GB',
    ),
    NewsSource(
      name: 'Reuters',
      url:
          'https://news.google.com/rss/search?q=site:reuters.com&hl=en-US&gl=US&ceid=US:en',
      countryCode: 'US',
    ),
    NewsSource(
      name: 'CNN',
      url: 'http://rss.cnn.com/rss/edition.rss',
      countryCode: 'US',
    ),
    NewsSource(
      name: 'NYT World',
      url: 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml',
      countryCode: 'US',
    ),
    NewsSource(
      name: 'The Guardian',
      url: 'https://www.theguardian.com/world/rss',
      countryCode: 'GB',
    ),
    NewsSource(
      name: 'AP News',
      url:
          'https://news.google.com/rss/search?q=site:apnews.com&hl=en-US&gl=US&ceid=US:en',
      countryCode: 'US',
    ),
    NewsSource(
      name: 'The Verge',
      url: 'https://www.theverge.com/rss/index.xml',
      countryCode: 'US',
      category: 'tech',
    ),
    NewsSource(
      name: 'TechCrunch',
      url: 'https://techcrunch.com/feed/',
      countryCode: 'US',
      category: 'tech',
    ),
    NewsSource(
      name: 'Wired',
      url: 'https://www.wired.com/feed/rss',
      countryCode: 'US',
      category: 'tech',
    ),

    // Regional
    NewsSource(
      name: 'The Moscow Times',
      url: 'https://www.themoscowtimes.com/rss/news',
      countryCode: 'RU',
    ),
    NewsSource(
      name: 'Kyiv Post',
      url: 'https://www.kyivpost.com/feed/',
      countryCode: 'UA',
    ),
    NewsSource(
      name: 'Euronews',
      url: 'https://www.euronews.com/rss',
      countryCode: 'EU',
    ),
    NewsSource(
      name: 'TRT World',
      url:
          'https://news.google.com/rss/search?q=site:trtworld.com&hl=en-US&gl=US&ceid=US:en',
      countryCode: 'TR',
    ),

    // Asia-Pacific
    NewsSource(
      name: 'The Hindu',
      url: 'https://www.thehindu.com/news/international/?service=rss',
      countryCode: 'IN',
    ),
    NewsSource(
      name: 'Indian Express',
      url: 'https://indianexpress.com/feed/',
      countryCode: 'IN',
    ),
    NewsSource(
      name: '7News Australia',
      url: 'https://7news.com.au/rss',
      countryCode: 'AU',
    ),
    NewsSource(
      name: 'Neos Kosmos',
      url: 'https://neoskosmos.com/en/feed/',
      countryCode: 'GR',
    ),
  ];

  // ==========================================
  // UTILITY METHODS
  // ==========================================

  static List<NewsSource> get all => [
        ...tunisian,
        ...moroccan,
        ...algerian,
        ...iranian,
        ...international,
      ];

  static List<NewsSource> byCountry(String countryCode) {
    return all.where((s) => s.countryCode == countryCode).toList();
  }

  static List<NewsSource> byCategory(String category) {
    return all.where((s) => s.category == category).toList();
  }

  static List<NewsSource> get rssOnly =>
      all.where((s) => s.type == SourceType.rss).toList();

  static List<NewsSource> get scrapableOnly =>
      all.where((s) => s.type == SourceType.scrapable).toList();
}
