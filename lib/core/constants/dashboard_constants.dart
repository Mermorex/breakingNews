// lib/core/constants/dashboard_constants.dart

class DashboardConstants {
  // ═══════════════════════════════════════════════════════════
  // RELIABLE FEEDS (tested working with corsproxy.io)
  // ═══════════════════════════════════════════════════════════

  static const List<Map<String, String>> tunisianFeatured = [
    {'name': 'Mosaïque FM', 'url': 'https://www.mosaiquefm.net/ar/rss'},
    {'name': 'Al Chourouk', 'url': 'https://www.alchourouk.com/rss'},
    {'name': 'وزارة الداخلية', 'url': 'https://www.interieur.gov.tn/ar/feed'},
  ];

  static const List<Map<String, String>> frenchFeatured = [
    {'name': 'Le Monde', 'url': 'https://www.lemonde.fr/rss/une.xml'},
    {
      'name': 'Le Figaro',
      'url': 'https://www.lefigaro.fr/rss/figaro_actualites.xml'
    },
    {
      'name': 'Libération',
      'url': 'https://www.liberation.fr/arc/outboundfeeds/rss-all/'
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
  ];
}
