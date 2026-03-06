// lib/data/models/news_source.dart

class NewsSource {
  final String name;
  final String url;
  final SourceType type;
  final Map<String, String>? selectors; // For scraping
  final bool useWebFeed; // Try webfeed first?
  final Map<String, String>? headers; // Custom headers (for Reddit, etc.)

  NewsSource({
    required this.name,
    required this.url,
    this.type = SourceType.rss,
    this.selectors,
    this.useWebFeed = true,
    this.headers,
  });
}

enum SourceType { rss, scrapable, jsonApi }

class NewsSources {
  // ==========================================
  // TUNISIAN SOURCES (RSS)
  // ==========================================
  static final List<NewsSource> tunisian = [
    NewsSource(name: 'Mosaïque FM', url: 'https://www.mosaiquefm.net/ar/rss'),
    NewsSource(
        name: 'Jawhara FM',
        url: 'https://www.jawharafm.net/ar/rss/showRss/88/1/1'),
    NewsSource(name: 'tunisie-news', url: 'https://tunisie-news.com/feed/'),
    NewsSource(
        name: 'Express FM', url: 'https://www.radioexpressfm.com/ar/rss'),
    NewsSource(
        name: 'Tunisie Focus',
        url: 'https://www.tunisiefocus.com/category/politique/feed'),
    NewsSource(name: 'Al Chourouk', url: 'https://www.alchourouk.com/rss'),
    NewsSource(
        name: 'وزارة الداخلية', url: 'https://www.interieur.gov.tn/ar/feed'),
    NewsSource(
        name: 'رئاسة الحكومة',
        url:
            'https://www.tunisie.gov.tn/uploads/Document/fluxRssActualite.xml'),
    NewsSource(
        name: 'Business News', url: 'https://www.businessnews.com.tn/feed'),
    NewsSource(name: 'Nawaat', url: 'https://nawaat.org/feed/'),
  ];

  // ==========================================
  // ARAB WORLD SOURCES (RSS)
  // ==========================================
  static final List<NewsSource> arabWorld = [
    NewsSource(
        name: 'Al Jazeera', url: 'https://www.aljazeera.com/xml/rss/all.xml'),
    NewsSource(
        name: 'Al Jazeera Arabic',
        url: 'https://www.aljazeera.net/xml/rss/all.xml'),
    NewsSource(
        name: 'Al Arabiya', url: 'https://www.alarabiya.net/.mrss/ar.xml'),
    NewsSource(
        name: 'Sky News Arabia', url: 'https://www.skynewsarabia.com/rss.xml'),
    NewsSource(name: 'RT Arabic', url: 'https://arabic.rt.com/rss/'),
    NewsSource(
        name: 'BBC Arabic', url: 'https://feeds.bbci.co.uk/arabic/rss.xml'),
  ];

  // ==========================================
  // INTERNATIONAL SOURCES (RSS)
  // ==========================================
  static final List<NewsSource> international = [
    NewsSource(name: 'BBC News', url: 'http://feeds.bbci.co.uk/news/rss.xml'),
    NewsSource(
        name: 'Reuters',
        url:
            'https://www.reutersagency.com/feed/?taxonomy=markets&post_type=reuters-best'),
    NewsSource(name: 'CNN', url: 'http://rss.cnn.com/rss/edition.rss'),
    NewsSource(
        name: 'The Guardian', url: 'https://www.theguardian.com/world/rss'),
    NewsSource(
        name: 'The Verge', url: 'https://www.theverge.com/rss/index.xml'),
    NewsSource(name: 'TechCrunch', url: 'https://techcrunch.com/feed/'),
    NewsSource(name: 'Wired', url: 'https://www.wired.com/feed/rss'),
    NewsSource(
        name: 'NYT',
        url: 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml'),
    NewsSource(
        name: 'Washington Post',
        url: 'http://feeds.washingtonpost.com/rss/world'),
  ];

  // ==========================================
  // REDDIT SOURCES (JSON API)
  // ==========================================
  static final List<NewsSource> reddit = [
    NewsSource(
      name: 'Reddit Technology',
      url: 'https://www.reddit.com/r/technology.json',
      type: SourceType.jsonApi,
      headers: {
        'User-Agent': 'Flutter:RSSReader:v1.0 (by /u/yourusername)',
      },
    ),
    NewsSource(
      name: 'Reddit News',
      url: 'https://www.reddit.com/r/news.json',
      type: SourceType.jsonApi,
      headers: {
        'User-Agent': 'Flutter:RSSReader:v1.0 (by /u/yourusername)',
      },
    ),
    NewsSource(
      name: 'Reddit Science',
      url: 'https://www.reddit.com/r/science.json',
      type: SourceType.jsonApi,
      headers: {
        'User-Agent': 'Flutter:RSSReader:v1.0 (by /u/yourusername)',
      },
    ),
  ];

  // ==========================================
  // HACKER NEWS (JSON API)
  // ==========================================
  static final List<NewsSource> hackerNews = [
    NewsSource(
      name: 'Hacker News Top',
      url: 'https://hacker-news.firebaseio.com/v0/topstories.json',
      type: SourceType.jsonApi,
    ),
    NewsSource(
      name: 'Hacker News New',
      url: 'https://hacker-news.firebaseio.com/v0/newstories.json',
      type: SourceType.jsonApi,
    ),
  ];

  // ==========================================
  // SCRAPABLE SOURCES (No RSS)
  // ==========================================
  static final List<NewsSource> scrapable = [
    NewsSource(
      name: 'Rassd Tunisia',
      url: 'https://rassdtunisia.net/category/news',
      type: SourceType.scrapable,
      useWebFeed: false,
      selectors: {
        'item': 'article, .post, .entry',
        'title': 'h2.entry-title a, h1.entry-title',
        'link': 'h2.entry-title a[href], h1 a[href]',
        'desc': '.entry-summary p, .post-excerpt',
        'date': '.entry-date, time.entry-date, .published, .posted-on',
        'image': 'img.wp-post-image, .post-thumbnail img',
      },
    ),
  ];

  // ==========================================
  // ALL SOURCES COMBINED
  // ==========================================
  static List<NewsSource> get all => [
        ...tunisian,
        ...arabWorld,
        ...international,
        ...reddit,
        ...scrapable,
      ];
}
