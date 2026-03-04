// lib/data/models/news_source.dart
class NewsSource {
  final String name;
  final String url;
  final SourceType type;
  final Map<String, String>? selectors; // For scraping
  final bool useWebFeed; // Try webfeed first?

  NewsSource({
    required this.name,
    required this.url,
    this.type = SourceType.rss,
    this.selectors,
    this.useWebFeed = true,
  });
}

enum SourceType { rss, scrapable }

// Pre-configured sources
class NewsSources {
  // Standard RSS feeds (Tunisian - your existing ones)
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
  ];

  // International - Standard RSS
  static final List<NewsSource> international = [
    NewsSource(name: 'BBC News', url: 'http://feeds.bbci.co.uk/news/rss.xml'),
    NewsSource(
        name: 'Al Jazeera', url: 'https://www.aljazeera.com/xml/rss/all.xml'),
    NewsSource(
        name: 'Reuters',
        url:
            'https://www.reutersagency.com/feed/?taxonomy=markets&post_type=reuters-best'),
    NewsSource(name: 'CNN', url: 'http://rss.cnn.com/rss/edition.rss'),
  ];

  // Sites requiring scraping (NO native RSS)
  static final List<NewsSource> scrapable = [
    // Example: A news site without RSS
    NewsSource(
      name: 'Example News Site',
      url: 'https://example-news-site.com/latest',
      type: SourceType.scrapable,
      useWebFeed: false,
      selectors: {
        'item': 'article.news-item',
        'title': 'h2.headline',
        'link': 'a.read-more',
        'desc': 'p.summary',
        'date': 'time.publish-date',
        'image': 'img.thumbnail',
      },
    ),

    // Twitter via Nitter (RSS alternative)
    NewsSource(
      name: 'Twitter Trends',
      url: 'https://nitter.net',
      type: SourceType.scrapable,
      selectors: {
        'item': '.timeline-item',
        'title': '.tweet-content',
        'link': '.tweet-link',
        'desc': '.tweet-content',
        'date': '.tweet-date',
        'image': '.tweet-media img',
      },
    ),
  ];
}
