class SourceExtractor {
  static final Map<String, String> _domainMappings = {
    'mosaiquefm': 'Mosaïque FM',
    'lapresse': 'La Presse',
    'jawharafm': 'Jawhara FM',
    'diwanfm': 'Diwan FM',
    'radioexpressfm': 'Express FM',
    'tunisiefocus': 'Tunisie Focus',
    'babnet': 'Babnet',
    'jeuneafrique': 'Jeune Afrique',
    'alchourouk': 'Al Chourouk',
    'businessnews': 'Business News',
    'nawaat': 'Nawaat',
    'yabiladi': 'Yabiladi',
    'hihi2': 'Hihi2',
    'aujourdhui': "Aujourd'hui le Maroc",
    'moroccoworldnews': 'Morocco World News',
    'tsa-algerie': 'TSA',
    'elwatan': 'El Watan',
    'djelfa': 'Djelfa',
    'elkhadra': 'El Khadra',
    'liberte-algerie': 'Liberté',
    'algerie360': 'Algérie 360',
    'elkhabar': 'El Khabar',
    'mehrnews': 'Mehr News',
    'tasnimnews': 'Tasnim',
    'tehrantimes': 'Tehran Times',
    'asriran': 'Asriran',
    'farsnews': 'Fars News',
    'una-oic': 'UNA-OIC',
    'iranintl': 'Iran International',
    'tabnak': 'Tabnak',
    'aljazeera': 'Al Jazeera',
    'skynewsarabia': 'Sky News Arabia',
    'bbc': 'BBC',
    'france24': 'France 24',
    'reuters': 'Reuters',
    'nytimes': 'NYT',
    'theguardian': 'The Guardian',
    'apnews': 'AP News',
    'theverge': 'The Verge',
    'techcrunch': 'TechCrunch',
    'wired': 'Wired',
    'themoscowtimes': 'The Moscow Times',
    'kyivpost': 'Kyiv Post',
    'euronews': 'Euronews',
    'trtworld': 'TRT World',
    'thehindu': 'The Hindu',
    'indianexpress': 'Indian Express',
    '7news': '7News Australia',
    'neoskosmos': 'Neos Kosmos',
  };

  static String extractSource(String? rssSource, String articleUrl) {
    if (rssSource != null &&
        rssSource.isNotEmpty &&
        rssSource != 'Unknown' &&
        !_isGenericName(rssSource)) {
      return _cleanSourceName(rssSource);
    }
    return _extractFromUrl(articleUrl);
  }

  static bool _isGenericName(String name) {
    const genericNames = [
      'world news',
      'tunisia feed',
      'morocco feed',
      'algeria feed',
      'iran feed',
      'news',
      'feed',
      'articles',
      'unknown',
      'rss',
      'xml',
      'feedburner',
    ];
    return genericNames.any((generic) => name.toLowerCase().contains(generic));
  }

  static String _cleanSourceName(String name) {
    String clean = name
        .replaceAll(RegExp(r'\s*-\s*.*$'), '')
        .replaceAll(RegExp(r'\s*\|.*$'), '')
        .replaceAll(RegExp(r'\s*RSS.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*Feed.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*News.*$', caseSensitive: false), '')
        .trim();

    for (final entry in _domainMappings.entries) {
      if (clean.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return clean;
  }

  static String _extractFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      String host = uri.host.toLowerCase();
      if (host.startsWith('www.')) host = host.substring(4);
      if (host.contains(':')) host = host.split(':')[0];

      if (_domainMappings.containsKey(host)) {
        return _domainMappings[host]!;
      }

      final parts = host.split('.');
      for (int i = 0; i < parts.length; i++) {
        final domainPart = parts.sublist(i).join('.');
        if (_domainMappings.containsKey(domainPart)) {
          return _domainMappings[domainPart]!;
        }
        if (i == parts.length - 2) {
          final namePart = parts[i];
          if (_domainMappings.containsKey(namePart)) {
            return _domainMappings[namePart]!;
          }
        }
      }

      if (parts.isNotEmpty) {
        final firstPart = parts[0];
        return firstPart[0].toUpperCase() + firstPart.substring(1);
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }
}
