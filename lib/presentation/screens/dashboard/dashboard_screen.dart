import 'package:flutter/material.dart';
import 'package:news_app/presentation/screens/algeria_news_screen.dart';
import 'package:news_app/presentation/screens/morocco_news_screen.dart';
import 'package:news_app/presentation/screens/widget/region_section.dart';
import 'package:news_app/presentation/screens/widget/sidebar.dart';
import 'package:news_app/presentation/screens/widget/stats_row.dart';
import 'package:news_app/presentation/screens/widget/top_bar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../Tunisianscreen.dart';
import '../francescreen.dart';
import '../international_screen.dart';
import 'dashboard_controller.dart';

class DesktopDashboardScreen extends StatefulWidget {
  const DesktopDashboardScreen({super.key});

  @override
  State<DesktopDashboardScreen> createState() => _DesktopDashboardScreenState();
}

class _DesktopDashboardScreenState extends State<DesktopDashboardScreen> {
  final DashboardController _controller = DashboardController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerUpdate);
    _controller.loadDashboardData();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onControllerUpdate() => setState(() {});

  void _handleNavigation(int index) {
    switch (index) {
      case 0:
        _controller.setSelectedIndex(index);
        break;
      case 1:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TunisianNewsScreen()));
        break;
      case 2:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const FranceNewsScreen()));
        break;
      case 3:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MoroccoNewsScreen()));
        break;
      case 4: // NEW
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AlgeriaNewsScreen()));
        break;
      case 5: // Shifted from 4
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InternationalNewsScreen()));
        break;
      default:
        _controller.setSelectedIndex(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dashboardTheme,
      child: Scaffold(
        body: Row(
          children: [
            Sidebar(
              selectedIndex: _controller.selectedIndex,
              onItemSelected: _handleNavigation,
            ),
            Expanded(
              child: Container(
                color: AppColors.background,
                child: Column(
                  children: [
                    TopBar(
                      onRefresh: _controller.loadDashboardData,
                      isLoading: _controller.isLoading,
                      searchController: _searchController,
                      title: 'test',
                    ),
                    Expanded(
                      child: _controller.isLoading
                          ? const _LoadingView()
                          : _buildContent(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatsRow(
            tunisianCount: _controller.tunisianCount,
            frenchCount: _controller.frenchCount,
            moroccanCount: _controller.moroccanCount,
            algerianCount: _controller.algerianCount, // NEW
            internationalCount: _controller.internationalCount,
            totalArticles: _controller.totalArticles,
          ),
          const SizedBox(height: 40),

          // Tunisian Section
          RegionSection(
            icon: '🇹🇳',
            title: 'Tunisian News',
            subtitle: 'Latest updates from Tunisia',
            accentColor: AppColors.tunisianRed,
            sources: _controller.tunisianFeatured,
            data: _controller.dashboardData,
            regionPrefix: 'TN',
            onViewAll: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TunisianNewsScreen()),
            ),
            onArticleTap: _controller.openArticle,
          ),
          const SizedBox(height: 48),

          // French Section
          RegionSection(
            icon: '🇫🇷',
            title: 'France News',
            subtitle: 'Latest updates from France',
            accentColor: AppColors.frenchBlue,
            sources: _controller.frenchFeatured,
            data: _controller.dashboardData,
            regionPrefix: 'FR',
            onViewAll: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FranceNewsScreen()),
            ),
            onArticleTap: _controller.openArticle,
          ),
          const SizedBox(height: 48),

          // Moroccan Section (NEW - Added between French and International)
          RegionSection(
            icon: '🇲🇦',
            title: 'Moroccan News',
            subtitle: 'Le360, Hespress, Morocco World News & more',
            accentColor: Colors.green.shade700, // Moroccan flag green
            sources: _controller.moroccanFeatured,
            data: _controller.dashboardData,
            regionPrefix: 'MA',
            onViewAll: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MoroccoNewsScreen()),
            ),
            onArticleTap: _controller.openArticle,
          ),
          const SizedBox(height: 48),
          RegionSection(
            icon: '🇩🇿',
            title: 'Algerian News',
            subtitle: 'TSA, El Watan, Liberté & more',
            accentColor: Colors.green.shade600, // Algerian flag green
            sources: _controller.algerianFeatured,
            data: _controller.dashboardData,
            regionPrefix: 'DZ',
            onViewAll: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlgeriaNewsScreen()),
            ),
            onArticleTap: _controller.openArticle,
          ),
          const SizedBox(height: 48),

          // International Section
          RegionSection(
            icon: '🌍',
            title: 'International News',
            subtitle: 'Al Jazeera, BBC, Reuters & more',
            accentColor: AppColors.internationalGreen,
            sources: _controller.internationalFeatured,
            data: _controller.dashboardData,
            regionPrefix: 'INT',
            onViewAll: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const InternationalNewsScreen()),
            ),
            onArticleTap: _controller.openArticle,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.frenchBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(AppColors.frenchBlue),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Loading your news feed...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fetching latest articles from all sources',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
