// lib/core/constants/dashboard_constants.dart
import 'package:news_app/data/models/news_source.dart';

class DashboardConstants {
  // ═══════════════════════════════════════════════════════════
  // FEATURED LISTS (Used for Dashboard Widgets)
  // We slice the main lists to show only a few items on the dashboard.
  // ═══════════════════════════════════════════════════════════

  static List<NewsSource> get tunisianFeatured =>
      NewsSources.tunisian.take(3).toList();

  static List<NewsSource> get moroccanFeatured => NewsSources.moroccan;

  static List<NewsSource> get algerianFeatured => NewsSources.algerian;

  static List<NewsSource> get internationalFeatured =>
      NewsSources.international.take(7).toList();

  static List<NewsSource> get iranianFeatured => NewsSources.iranian;

  // ═══════════════════════════════════════════════════════════
  // CONSOLIDATED SOURCES (For Detailed Screens)
  // ═══════════════════════════════════════════════════════════

  /// Returns all Tunisian sources for the TunisianNewsScreen
  static List<NewsSource> get allTunisianSources => NewsSources.tunisian;

  /// Returns all International sources for the InternationalNewsScreen
  static List<NewsSource> get allInternationalSources =>
      NewsSources.international;
}
