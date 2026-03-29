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
    NewsSource(name: 'diwanfm', url: 'https://diwanfm.net/feed'),
    NewsSource(
      name: 'Express FM',
      url: 'https://radioexpressfm.com/ar/feed/',
      type: SourceType.rss,
    ),
    NewsSource(
      name: 'Radio Tunisienne',
      url: 'https://www.radionationale.tn/articles/rss',
      type: SourceType.rss, // Changed from scrapable to rss!
      countryCode: 'TN',
    ),
    NewsSource(
      name: 'Radio Gafsa',
      url: 'https://www.radiogafsa.tn/articles/rss',
      type: SourceType.rss,
      countryCode: 'TN',
    ),
    NewsSource(
      name: 'Radio Tataouine',
      url: 'https://www.radiotataouine.tn/articles/rss',
      type: SourceType.rss,
      countryCode: 'TN',
    ),
    NewsSource(
      name: 'Tunisie Focus',
      url: 'https://www.tunisiefocus.com/category/politique/feed',
      type: SourceType.rss,
      countryCode: 'TN',
    ),
    NewsSource(name: 'Babnet', url: 'https://www.babnet.net/feed.php'),
    NewsSource(
        name: 'Jeune Afrique', url: 'https://www.jeuneafrique.com/feed/'),
    NewsSource(name: 'Al Chourouk', url: 'https://www.alchourouk.com/rss'),
    NewsSource(
        name: 'Business News', url: 'https://www.businessnews.com.tn/feed'),
    NewsSource(name: 'Nawaat', url: 'https://nawaat.org/feed/'),
    NewsSource(
      name: 'Tunisia TV',
      url:
          'https://www.tunisiatv.tn/ar/articles/1/693ff922b922dd47f3ea53c3/%D8%A7%D8%AE%D8%A8%D8%A7%D8%B1%D9%86%D8%A7',
      type: SourceType.scrapable,
      countryCode: 'TN',
      selectors: {
        'item': '.card-landscape, .card-main', // Main + sub articles
        'title': 'h3 a', // Article title
        'link': 'h3 a', // Article URL (relative)
        'image': 'figure img', // Image element
        'date': 'time', // Date element
        'category': '.desc a:first-child', // Category tag
      },
    ),

    // Inside the tunisian list
  ];
  // MOROCCAN SOURCES (MA)
  // ==========================================
  static final List<NewsSource> moroccan = [
    NewsSource(
      name: 'yabiladi',
      url: 'https://www.yabiladi.com/rss/?url=rubrik/',
      countryCode: 'MA',
    ),
    NewsSource(
      name: 'hihi2',
      url: 'https://hihi2.com/feed',
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
    // REMOVED: El Watan - facing closure since 2022, RSS unreliable [^25^] [^26^]
    NewsSource(
      name: 'djelfa',
      url: 'https://www.djelfa.info/vb/external.php?type=RSS2',
      countryCode: 'DZ',
    ),
    NewsSource(
      name: 'elkhadra',
      url: 'https://www.elkhadra.com/fr/feed/',
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
    // REMOVED: Duplicate TSA entry
  ];
  // ==========================================
  // IRANIAN SOURCES (IR)
  // ==========================================
  static final List<NewsSource> iranian = [
    NewsSource(
      name: 'Mehr News english',
      url: 'https://en.mehrnews.com/rss',
      countryCode: 'IR',
    ),
    NewsSource(
      name: 'Mehr News persian',
      url: 'https://www.mehrnews.com/rss',
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
      name: 'Asriran',
      url: 'https://www.asriran.com/fa/rss/allnews',
      countryCode: 'IR',
    ),
    NewsSource(
      name: 'Fars News',
      url: 'https://www.farsnews.ir/en/rss',
      countryCode: 'IR',
    ),
    NewsSource(
      name: 'UNA-OIC',
      url: 'https://una-oic.org/en/feed/',
      countryCode: 'IR', // Using IR tag to group with regional news
    ),
    NewsSource(
      name: 'Iran International',
      // STRATEGY: They have no official RSS. We use Google News RSS Mirror.
      // This URL directly queries Google News for "site:iranintl.com"
      url:
          'https://news.google.com/rss/search?q=site:iranintl.com&hl=en-US&gl=US&ceid=US:en',
      countryCode: 'IR',
    ),
    NewsSource(
      name: 'tabnak',
      // STRATEGY: They have no official RSS. We use Google News RSS Mirror.
      // This URL directly queries Google News for "site:iranintl.com"
      url: 'https://www.tabnak.ir/fa/rss/allnews',
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
      name: 'france24',
      url: 'https://www.france24.com/fr/afrique/rss',
      countryCode: 'FR',
    ),
    NewsSource(
      name: 'Reuters',
      url:
          'https://news.google.com/rss/search?q=site:reuters.com&hl=en-US&gl=US&ceid=US:en',
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
