// lib/presentation/screens/home/home_controller.dart
import 'package:flutter/material.dart';
import '../../../core/constants/dashboard_constants.dart';
import '../../../data/datasources/rss_remote_datasource.dart';
import '../../../data/models/rss_item_model.dart';

class HomeController extends ChangeNotifier {
  final RssRemoteDataSource _dataSource = RssRemoteDataSource();

  Map<String, List<RssItemModel>> _dashboardData = {};
  bool _isLoading = true;
  String? _error;
  int _selectedIndex = 0;

  // Getters
  Map<String, List<RssItemModel>> get dashboardData => _dashboardData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get selectedIndex => _selectedIndex;

  // Computed
  int get totalArticles => _dashboardData.values.fold(
        0,
        (sum, items) => sum + items.length,
      );

  // Featured sources from constants
  List<Map<String, String>> get tunisianFeatured =>
      DashboardConstants.tunisianFeatured;
  List<Map<String, String>> get frenchFeatured =>
      DashboardConstants.frenchFeatured;
  List<Map<String, String>> get moroccanFeatured =>
      DashboardConstants.moroccanFeatured;
  List<Map<String, String>> get internationalFeatured =>
      DashboardConstants.internationalFeatured;
  List<Map<String, String>> get algerianFeatured =>
      DashboardConstants.algerianFeatured;

  // Get articles by region prefix - SORTED BY DATE (newest first)
  List<RssItemModel> getTunisianArticles() => _getArticlesByRegion('TN');
  List<RssItemModel> getFrenchArticles() => _getArticlesByRegion('FR');
  List<RssItemModel> getMoroccanArticles() => _getArticlesByRegion('MA');
  List<RssItemModel> getInternationalArticles() => _getArticlesByRegion('INT');
  List<RssItemModel> getAlgerianArticles() => _getArticlesByRegion('DZ');

  // Featured articles for dashboard (limited to 3, sorted by date)
  // CHANGED: Take 3 instead of 6 for dashboard cards
  List<RssItemModel> get tunisianFeaturedArticles =>
      getTunisianArticles().take(3).toList();
  List<RssItemModel> get frenchFeaturedArticles =>
      getFrenchArticles().take(3).toList();
  List<RssItemModel> get moroccanFeaturedArticles =>
      getMoroccanArticles().take(3).toList();
  List<RssItemModel> get internationalFeaturedArticles =>
      getInternationalArticles().take(3).toList();
  List<RssItemModel> get algerianFeaturedArticles =>
      getAlgerianArticles().take(3).toList();

  // Count getters for StatsRow
  int get tunisianCount => getTunisianArticles().length;
  int get frenchCount => getFrenchArticles().length;
  int get moroccanCount => getMoroccanArticles().length;
  int get internationalCount => getInternationalArticles().length;
  int get algerianCount => getAlgerianArticles().length;

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  Future<void> loadDashboardData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _dashboardData.clear();

    final allSources = [
      ...tunisianFeatured.map((s) => {...s, 'region': 'TN'}),
      ...frenchFeatured.map((s) => {...s, 'region': 'FR'}),
      ...moroccanFeatured.map((s) => {...s, 'region': 'MA'}),
      ...algerianFeatured.map((s) => {...s, 'region': 'DZ'}),
      ...internationalFeatured.map((s) => {...s, 'region': 'INT'}),
    ];

    // FIX 1: Add error handling with eagerError: false
    // This prevents one failed feed from stopping all others
    try {
      await Future.wait(
        allSources.map((source) => _fetchSourceData(source)),
        eagerError: false, // Continue even if some fail
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('Error in batch fetch: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchSourceData(Map<String, String> source) async {
    try {
      final cleanUrl = source['url']!.trim();
      final sourceName = source['name']!;

      // FIX 2: Add timeout protection to prevent hanging
      final items = await _dataSource
          .fetchRssFeed(cleanUrl, limit: 6)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        debugPrint('⏱️ TIMEOUT: ${source['name']}');
        return <RssItemModel>[];
      });

      final key = '${source['region']}_${source['name']}';
      _dashboardData[key] = items;

      debugPrint('✅ Loaded ${items.length} articles from ${source['name']}');
    } catch (e) {
      debugPrint('❌ Error loading ${source['name']}: $e');
      final key = '${source['region']}_${source['name']}';
      _dashboardData[key] = []; // Empty list on error
    }
  }

  // FIX 3: Helper method with DATE SORTING (newest first)
  List<RssItemModel> _getArticlesByRegion(String regionPrefix) {
    final articles = _dashboardData.entries
        .where((entry) => entry.key.startsWith('${regionPrefix}_'))
        .expand((entry) => entry.value)
        .toList();

    // Sort by published date, newest first
    articles.sort((a, b) {
      final dateA = a.publishedAt ?? DateTime(1970);
      final dateB = b.publishedAt ?? DateTime(1970);
      return dateB.compareTo(dateA); // Descending order
    });

    return articles;
  }

  Future<void> openArticle(String url) async {
    if (url.isEmpty) return;

    String cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http')) {
      cleanUrl =
          cleanUrl.startsWith('//') ? 'https:$cleanUrl' : 'https://$cleanUrl';
    }

    // FIX 4: Implement actual URL opening
    try {
      // For web:
      // html.window.open(cleanUrl, '_blank');

      // For mobile/desktop with url_launcher:
      // final uri = Uri.parse(cleanUrl);
      // if (await canLaunchUrl(uri)) {
      //   await launchUrl(uri, mode: LaunchMode.externalApplication);
      // }

      debugPrint('🔗 Opening: $cleanUrl');
    } catch (e) {
      debugPrint('Error opening article: $e');
    }
  }
}
