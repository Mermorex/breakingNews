import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:news_app/core/utils/responsive.dart';
import 'package:news_app/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:news_app/presentation/screens/irannews_screen.dart';
import 'package:news_app/presentation/screens/Tunisianscreen.dart';
import 'package:news_app/presentation/screens/international_screen.dart';
import 'package:news_app/presentation/screens/widget/lib/presentation/widget/web_nav_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../algeria_news_screen.dart';
import '../morocco_news_screen.dart';
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
    // No drawer logic needed anymore!
    if (_controller.selectedIndex != index) {
      _fadeController.reverse().then((_) {
        _controller.setSelectedIndex(index);
        _fadeController.forward();
      });
    }
  }

  // ✅ NEW: Opens a stylish bottom sheet for navigation
  void _openMobileMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1219),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Navigation',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              _buildMenuItem(Icons.dashboard, 'Dashboard', 0),
              _buildMenuItem(Icons.flag, 'Tunisia News', 1, color: Colors.red),
              _buildMenuItem(Icons.flag, 'Morocco News', 2,
                  color: Colors.green),
              _buildMenuItem(Icons.flag, 'Algeria News', 3,
                  color: Colors.lightGreen),
              _buildMenuItem(Icons.flag, 'Iran News', 4, color: Colors.teal),
              _buildMenuItem(Icons.public, 'International', 5,
                  color: Colors.purple),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(IconData icon, String title, int index,
      {Color? color}) {
    final isSelected = _controller.selectedIndex == index;
    return ListTile(
      leading: Icon(icon,
          color:
              isSelected ? const Color(0xFFFF8C00) : (color ?? Colors.white54)),
      title: Text(
        title,
        style: GoogleFonts.montserrat(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      tileColor: isSelected ? Colors.white.withOpacity(0.05) : null,
      onTap: () {
        Navigator.pop(context); // Close bottom sheet
        _handleNavigation(index);
      },
    );
  }

  Widget _buildCurrentView() {
    switch (_controller.selectedIndex) {
      case 0:
        return FadeTransition(
          opacity: _fadeController,
          child: _buildDashboard(),
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

  static const Color cryptoDarkBg = Color(0xFF0B0E14);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dashboardTheme,
      child: Scaffold(
        backgroundColor: cryptoDarkBg,
        // ❌ REMOVED: drawer property
        body: Column(
          children: [
            WebNavBar(
              selectedIndex: _controller.selectedIndex,
              onItemSelected: _handleNavigation,
              onRefresh: _loadData,
              isLoading: _controller.isLoading,
              searchController: _searchController,
              onMenuTap: _openMobileMenu, // ✅ Pass the bottom sheet callback
            ),
            Expanded(
              child: _controller.isLoading && _controller.selectedIndex == 0
                  ? const _LoadingView()
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildCurrentView(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return DashboardScreen(
      worldNewsArticles: _controller.internationalFeaturedArticles,
      tunisianArticles: _controller.tunisianFeaturedArticles,
      moroccanArticles: _controller.moroccanFeaturedArticles,
      algerianArticles: _controller.algerianFeaturedArticles,
      iranianArticles: _controller.iranianFeaturedArticles,
      totalArticles: _controller.totalArticles,
      tunisianCount: _controller.tunisianCount,
      moroccanCount: _controller.moroccanCount,
      algerianCount: _controller.algerianCount,
      iranianCount: _controller.iranianCount,
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
