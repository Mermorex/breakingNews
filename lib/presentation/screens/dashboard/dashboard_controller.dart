import 'package:flutter/material.dart';
import '../../../core/constants/dashboard_constants.dart';
import '../../../data/datasources/rss_remote_datasource.dart';
import '../../../data/models/rss_item_model.dart';

class DashboardController extends ChangeNotifier {
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

  // Get articles by region prefix
  List<RssItemModel> getTunisianArticles() => _getArticlesByRegion('TN');
  List<RssItemModel> getFrenchArticles() => _getArticlesByRegion('FR');
  List<RssItemModel> getMoroccanArticles() => _getArticlesByRegion('MA');
  List<RssItemModel> getInternationalArticles() => _getArticlesByRegion('INT');
  List<RssItemModel> getAlgerianArticles() => _getArticlesByRegion('DZ');

  // Featured articles for dashboard (limited to 6 per region)
  List<RssItemModel> get tunisianFeaturedArticles =>
      getTunisianArticles().take(6).toList();
  List<RssItemModel> get frenchFeaturedArticles =>
      getFrenchArticles().take(6).toList();
  List<RssItemModel> get moroccanFeaturedArticles =>
      getMoroccanArticles().take(6).toList();
  List<RssItemModel> get internationalFeaturedArticles =>
      getInternationalArticles().take(6).toList();
  List<RssItemModel> get algerianFeaturedArticles =>
      getAlgerianArticles().take(6).toList();

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
      ...internationalFeatured.map((s) => {...s, 'region': 'INT'}),
      ...algerianFeatured.map((s) => {...s, 'region': 'DZ'}),
    ];

    // ✅ OPTIMIZED: Run in parallel with a hard timeout
    // If sources don't respond within 15s total, we show what we have.
    try {
      await Future.wait(
        allSources.map((source) => _fetchSourceData(source)),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('⚠️ Dashboard loading timed out or failed: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchSourceData(Map<String, String> source) async {
    try {
      final cleanUrl = source['url']!.trim();
      // Reduced limit for faster initial load
      final items = await _dataSource.fetchRssFeed(cleanUrl, limit: 5);
      final key = '${source['region']}_${source['name']}';
      _dashboardData[key] = items;
    } catch (e) {
      debugPrint('Error loading ${source['name']}: $e');
      _dashboardData['${source['region']}_${source['name']}'] = [];
    }
  }

  // Helper method to get articles by region prefix
  List<RssItemModel> _getArticlesByRegion(String regionPrefix) {
    return _dashboardData.entries
        .where((entry) => entry.key.startsWith('${regionPrefix}_'))
        .expand((entry) => entry.value)
        .toList();
  }

  Future<void> openArticle(String url) async {
    if (url.isEmpty) return;

    String cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http')) {
      cleanUrl =
          cleanUrl.startsWith('//') ? 'https:$cleanUrl' : 'https://$cleanUrl';
    }

    // Ideally use url_launcher package here
    // await launchUrl(Uri.parse(cleanUrl));
  }
}
