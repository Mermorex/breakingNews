import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:news_app/presentation/screens/dashboard/dashboard_screen.dart'; // Import new screen
import 'package:news_app/presentation/screens/ai_chat_screen.dart';
import 'package:news_app/presentation/screens/irannews_screen.dart';
import 'package:news_app/presentation/screens/Tunisianscreen.dart';
import 'package:news_app/presentation/screens/international_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/rss_item_model.dart';
import '../algeria_news_screen.dart';
import '../morocco_news_screen.dart';
import '../widget/sidebar.dart';
import '../widget/top_bar.dart';
import 'home_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final HomeController _controller = HomeController();
  final TextEditingController _searchController = TextEditingController();
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _controller.addListener(_onControllerUpdate);
    _loadData();
  }

  Future<void> _loadData() async {
    await _controller.loadDashboardData();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    setState(() {});
  }

  void _handleNavigation(int index) {
    if (_controller.selectedIndex != index) {
      _fadeController.reverse().then((_) {
        _controller.setSelectedIndex(index);
        _fadeController.forward();
      });
    }
  }

  // ✅ UPDATED: Navigation Logic to match new order
  Widget _buildCurrentView() {
    switch (_controller.selectedIndex) {
      case 0:
        return FadeTransition(
          opacity: _fadeController,
          child: _buildDashboard(), // Use new separated Dashboard
        );
      case 1:
        return const TunisianNewsScreen(isEmbedded: true);
      case 2:
        return const MoroccoNewsScreen(isEmbedded: true);
      case 3:
        return const AlgeriaNewsScreen(isEmbedded: true);
      case 4:
        return const IranianNewsScreen(isEmbedded: true);
      case 5:
        return const InternationalNewsScreen(isEmbedded: true);
      default:
        return _buildDashboard();
    }
  }

  String _getTitle() {
    switch (_controller.selectedIndex) {
      case 0:
        return 'Dashboard Overview';
      case 1:
        return 'Tunisian News';
      case 2:
        return 'Moroccan News';
      case 3:
        return 'Algerian News';
      case 4:
        return 'Iranian News';
      case 5:
        return 'World News';
      default:
        return 'AI RSS Reader';
    }
  }

  static const Color cryptoDarkBg = Color(0xFF0B0E14);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dashboardTheme,
      child: Scaffold(
        backgroundColor: cryptoDarkBg,
        body: Row(
          children: [
            Sidebar(
              selectedIndex: _controller.selectedIndex,
              onItemSelected: _handleNavigation,
              isCompact: false,
            ),
            Expanded(
              child: Container(
                color: cryptoDarkBg,
                child: Column(
                  children: [
                    TopBar(
                      title: _getTitle(),
                      onRefresh: _loadData,
                      isLoading: _controller.isLoading,
                      searchController: _searchController,
                    ),
                    Expanded(
                      child: _controller.isLoading &&
                              _controller.selectedIndex == 0
                          ? const _LoadingView()
                          : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _buildCurrentView(),
                            ),
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

  // ✅ DASHBOARD BUILDER: Passes data to DashboardScreen
  Widget _buildDashboard() {
    return DashboardScreen(
      // Data
      worldNewsArticles: _controller
          .internationalFeaturedArticles, // Using International feed for World News
      tunisianArticles: _controller.tunisianFeaturedArticles,
      moroccanArticles: _controller.moroccanFeaturedArticles,
      algerianArticles: _controller.algerianFeaturedArticles,
      iranianArticles: _controller.iranianFeaturedArticles,
      // Stats
      totalArticles: _controller.totalArticles,
      tunisianCount: _controller.tunisianCount,
      moroccanCount: _controller.moroccanCount,
      algerianCount: _controller.algerianCount,
      iranianCount: _controller.iranianCount,
      // Navigation
      onViewWorldNews: () => _handleNavigation(5),
      onViewTunisia: () => _handleNavigation(1),
      onViewMorocco: () => _handleNavigation(2),
      onViewAlgeria: () => _handleNavigation(3),
      onViewIran: () => _handleNavigation(4),
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
              color: const Color(0xFFFF8C00).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8C00)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Curating your news...',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
