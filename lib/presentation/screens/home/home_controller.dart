// lib/presentation/screens/home/home_controller.dart
import 'package:flutter/material.dart';
import 'package:news_app/data/models/news_source.dart';
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

  int get totalArticles =>
      _dashboardData.values.fold(0, (sum, items) => sum + items.length);

  // Featured Lists (Now returning strongly typed NewsSource lists)
  List<NewsSource> get tunisianFeatured => DashboardConstants.tunisianFeatured;
  List<NewsSource> get moroccanFeatured => DashboardConstants.moroccanFeatured;
  List<NewsSource> get internationalFeatured =>
      DashboardConstants.internationalFeatured;
  List<NewsSource> get algerianFeatured => DashboardConstants.algerianFeatured;
  List<NewsSource> get iranianFeatured => DashboardConstants.iranianFeatured;

  // Article Getters
  List<RssItemModel> getTunisianArticles() => _getArticlesByRegion('TN');
  List<RssItemModel> getFrenchArticles() => _getArticlesByRegion('FR');
  List<RssItemModel> getMoroccanArticles() => _getArticlesByRegion('MA');
  List<RssItemModel> getInternationalArticles() => _getArticlesByRegion('INT');
  List<RssItemModel> getAlgerianArticles() => _getArticlesByRegion('DZ');
  List<RssItemModel> getIranianArticles() => _getArticlesByRegion('IR');

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
  List<RssItemModel> get iranianFeaturedArticles =>
      getIranianArticles().take(3).toList();

  int get tunisianCount => getTunisianArticles().length;
  int get frenchCount => getFrenchArticles().length;
  int get moroccanCount => getMoroccanArticles().length;
  int get internationalCount => getInternationalArticles().length;
  int get algerianCount => getAlgerianArticles().length;
  int get iranianCount => getIranianArticles().length;

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  Future<void> loadDashboardData() async {
    // 1. Setup initial loading state
    if (_dashboardData.isEmpty) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    // 2. Create a list of tasks (Futures)
    // We iterate over the strongly typed NewsSource lists
    final List<Future> tasks = [];

    // Helper to add tasks to the list
    void addFetchTasks(List<NewsSource> sources, String regionCode) {
      for (final source in sources) {
        tasks.add(
          _fetchSourceData(source, regionCode).then((_) {
            // ✅ MAGIC HAPPENS HERE:
            // As soon as ONE task finishes, turn off the initial loading spinner
            // so the UI renders the dashboard immediately.
            if (_isLoading) {
              _isLoading = false;
              notifyListeners();
            }
          }).catchError((e) {
            debugPrint('❌ Task failed: ${source.name}');
          }),
        );
      }
    }

    // Add tasks for each region
    addFetchTasks(tunisianFeatured, 'TN');
    addFetchTasks(moroccanFeatured, 'MA');
    addFetchTasks(algerianFeatured, 'DZ');
    addFetchTasks(iranianFeatured, 'IR');
    addFetchTasks(internationalFeatured, 'INT');

    // 3. Run all tasks in parallel
    await Future.wait(tasks);

    // 4. Final cleanup
    _isLoading = false;
    notifyListeners();
  }

  // Updated to accept NewsSource object and region string
  Future<void> _fetchSourceData(NewsSource source, String region) async {
    try {
      final cleanUrl = source.url.trim();
      final sourceName = source.name;

      final items = await _dataSource
          .fetchRssFeed(cleanUrl, limit: 6)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        debugPrint('⏱️ TIMEOUT: $sourceName');
        return <RssItemModel>[];
      });

      // Store data with composite key: "REGION_Sourcename"
      final key = '${region}_$sourceName';
      _dashboardData[key] = items;

      debugPrint('✅ Loaded ${items.length} articles from $sourceName');

      // Notify listeners updates the specific card on screen
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading ${source.name}: $e');
      final key = '${region}_${source.name}';
      _dashboardData[key] = [];
    }
  }

  List<RssItemModel> _getArticlesByRegion(String regionPrefix) {
    final articles = _dashboardData.entries
        .where((entry) => entry.key.startsWith('${regionPrefix}_'))
        .expand((entry) => entry.value)
        .toList();

    articles.sort((a, b) {
      final dateA = a.publishedAt ?? DateTime(1970);
      final dateB = b.publishedAt ?? DateTime(1970);
      return dateB.compareTo(dateA);
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
    debugPrint('🔗 Opening: $cleanUrl');
  }
}
