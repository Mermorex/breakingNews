// lib/data/models/news_source.dart

class NewsSource {
  final String name;
  final String url;
  final SourceType type;
  final Map<String, String>? selectors; // For scraping
  final bool useWebFeed; // Try webfeed first?
  final Map<String, String>? headers; // Custom headers

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
  // TUNISIAN SOURCES
  // ==========================================
  static final List<NewsSource> tunisian = [
    // Core RSS
    NewsSource(name: 'Mosaïque FM', url: 'https://www.mosaiquefm.net/ar/rss'),
    NewsSource(
        name: 'وزارة الداخلية', url: 'https://www.interieur.gov.tn/ar/feed/'),
    NewsSource(
        name: 'La Presse',
        url: 'https://www.lapresse.tn/category/actualites/feed'),
    NewsSource(
        name: 'Jawhara FM',
        url: 'https://www.jawharafm.net/ar/rss/showRss/88/1/1'),
    NewsSource(
        name: 'Express FM', url: 'https://www.radioexpressfm.com/ar/rss'),
    NewsSource(
        name: 'Tunisie Focus',
        url: 'https://www.tunisiefocus.com/category/politique/feed'),
    NewsSource(name: 'Babnet', url: 'https://www.babnet.net/feed.php'),
    NewsSource(
        name: 'Jeune Afrique', url: 'https://www.jeuneafrique.com/feed/'),

    // Additional from original model
    NewsSource(name: 'Al Chourouk', url: 'https://www.alchourouk.com/rss'),
    NewsSource(
        name: 'رئاسة الحكومة',
        url:
            'https://www.tunisie.gov.tn/uploads/Document/fluxRssActualite.xml'),
    NewsSource(
        name: 'Business News', url: 'https://www.businessnews.com.tn/feed'),
    NewsSource(name: 'Nawaat', url: 'https://nawaat.org/feed/'),

    // Scrapable Sources
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

  // ==========================================
  // MOROCCAN SOURCES
  // ==========================================
  static final List<NewsSource> moroccan = [
    NewsSource(name: 'Le360', url: 'https://fr.le360.ma/rss'),
    NewsSource(name: 'Hespress', url: 'https://www.hespress.com/feed'),
    NewsSource(
        name: 'Aujourd\'hui le Maroc', url: 'https://aujourdhui.ma/feed'),
    NewsSource(
        name: 'Morocco World News',
        url: 'https://www.moroccoworldnews.com/feed/'),
  ];

  // ==========================================
  // ALGERIAN SOURCES
  // ==========================================
  static final List<NewsSource> algerian = [
    NewsSource(name: 'TSA', url: 'https://www.tsa-algerie.com/feed/'),
    NewsSource(name: 'El Watan', url: 'https://elwatan.dz/feed/'),
    NewsSource(name: 'Liberté', url: 'https://www.liberte-algerie.com/feed/'),
    NewsSource(name: 'Algerie360', url: 'https://www.algerie360.com/feed/'),
    NewsSource(name: 'El Khabar', url: 'https://elkhabar.com/feed/'),
  ];

  // ==========================================
  // IRANIAN SOURCES
  // ==========================================
  static final List<NewsSource> iranian = [
    NewsSource(name: 'Mehr News', url: 'https://en.mehrnews.com/rss'),
    NewsSource(
        name: 'Tasnim News',
        url: 'https://www.tasnimnews.ir/en/rss/feed/0/0/8/1/TopStories'),
    NewsSource(name: 'Tehran Times', url: 'https://www.tehrantimes.com/rss'),
    NewsSource(name: 'Fars News', url: 'https://www.farsnews.ir/en/rss'),
  ];

  // ==========================================
  // INTERNATIONAL SOURCES
  // ==========================================
  static final List<NewsSource> international = [
    // Core
    NewsSource(
        name: 'Al Jazeera English',
        url: 'https://www.aljazeera.com/xml/rss/all.xml'),
    NewsSource(
        name: 'Al Jazeera Arabic',
        url:
            'https://www.aljazeera.net/aljazeerarss/a7c186be-1baa-4bd4-9d80-a84db769f779/73d0e1b4-532f-45ef-b135-bfdff8b8cab9'),
    NewsSource(name: 'BBC', url: 'http://feeds.bbci.co.uk/news/rss.xml'),
    NewsSource(
        name: 'Reuters',
        url:
            'https://news.google.com/rss/search?q=site%3Areuters.com&hl=en-US&gl=US&ceid=US%3Aen'),
    NewsSource(name: 'CNN', url: 'http://rss.cnn.com/rss/edition.rss'),
    NewsSource(
        name: 'NYT World',
        url: 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml'),
    NewsSource(
        name: 'The Guardian', url: 'https://www.theguardian.com/world/rss'),

    // Verified/Additional
    NewsSource(
        name: 'The Moscow Times',
        url: 'https://www.themoscowtimes.com/rss/news'),
    NewsSource(name: 'Kyiv Post', url: 'https://www.kyivpost.com/feed/'),
    NewsSource(name: 'Neos Kosmos', url: 'https://neoskosmos.com/en/feed/'),
    NewsSource(name: 'Indian Express', url: 'https://indianexpress.com/feed/'),
    NewsSource(name: 'Euronews', url: 'https://www.euronews.com/rss'),
    NewsSource(
        name: 'AP News',
        url:
            'https://news.google.com/rss/search?q=site:apnews.com&hl=en-US&gl=US&ceid=US:en'),
    NewsSource(name: '7News Australia', url: 'https://7news.com.au/rss'),
    NewsSource(
        name: 'TRT World',
        url:
            'https://news.google.com/rss/search?q=site:trtworld.com&hl=en-US&gl=US&ceid=US:en'),
    NewsSource(
        name: 'Sky News Arabia', url: 'https://www.skynewsarabia.com/rss'),
    NewsSource(
        name: 'The Hindu',
        url: 'https://www.thehindu.com/news/international/?service=rss'),

    // Tech/Other
    NewsSource(
        name: 'The Verge', url: 'https://www.theverge.com/rss/index.xml'),
    NewsSource(name: 'TechCrunch', url: 'https://techcrunch.com/feed/'),
    NewsSource(name: 'Wired', url: 'https://www.wired.com/feed/rss'),
  ];

  // ==========================================
  // REDDIT & HACKER NEWS (JSON API)
  // ==========================================
  static final List<NewsSource> reddit = [
    NewsSource(
      name: 'Reddit Technology',
      url: 'https://www.reddit.com/r/technology.json',
      type: SourceType.jsonApi,
      headers: {'User-Agent': 'Flutter:RSSReader:v1.0 (by /u/yourusername)'},
    ),
    NewsSource(
      name: 'Reddit News',
      url: 'https://www.reddit.com/r/news.json',
      type: SourceType.jsonApi,
      headers: {'User-Agent': 'Flutter:RSSReader:v1.0 (by /u/yourusername)'},
    ),
  ];

  static final List<NewsSource> hackerNews = [
    NewsSource(
      name: 'Hacker News Top',
      url: 'https://hacker-news.firebaseio.com/v0/topstories.json',
      type: SourceType.jsonApi,
    ),
  ];

  // ==========================================
  // GETTERS FOR ALL
  // ==========================================
  static List<NewsSource> get all => [
        ...tunisian,
        ...moroccan,
        ...algerian,
        ...iranian,
        ...international,
        ...reddit,
        ...hackerNews,
      ];
}
