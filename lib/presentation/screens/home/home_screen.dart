import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:news_app/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:news_app/presentation/screens/france_news_screen.dart';
import 'package:news_app/presentation/screens/irannews_screen.dart';
import 'package:news_app/presentation/screens/Tunisianscreen.dart';
import 'package:news_app/presentation/screens/international_screen.dart';
import 'package:news_app/presentation/screens/widget/lib/presentation/widget/web_nav_bar.dart';

// ✅ FIX: Added 'as theme' prefix to avoid conflicts with other AppColors classes
import '../../../core/theme/app_colors.dart' as theme;
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

  void _loadData() {
    _controller.loadDashboardData();
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
    if (_controller.totalArticles > 0 &&
        _fadeController.status == AnimationStatus.dismissed) {
      _fadeController.forward();
    }
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

  void _openMobileMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.AppColors.surface, // White background
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
                  color: theme.AppColors.border, // Light gray handle
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Navigation',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.AppColors.textPrimary, // Dark text
                ),
              ),
              const SizedBox(height: 24),
              _buildMenuItem(Icons.dashboard, 'Dashboard', 0),
              _buildMenuItem(Icons.flag, 'Tunisia News', 1,
                  color: theme.AppColors.tunisianRed),
              _buildMenuItem(Icons.flag, 'Morocco News', 2,
                  color: theme.AppColors.internationalGreen),
              _buildMenuItem(Icons.flag, 'Algeria News', 3,
                  color: theme.AppColors.internationalGreen),
              _buildMenuItem(Icons.flag, 'Iran News', 4,
                  color: theme.AppColors.tunisianRed),
              _buildMenuItem(Icons.public, 'International', 5,
                  color: theme.AppColors.frenchBlue),
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
      leading: Icon(
        icon,
        color: isSelected
            ? theme.AppColors.tunisianRed
            : (color ?? theme.AppColors.textSecondary),
      ),
      title: Text(
        title,
        style: GoogleFonts.montserrat(
          color: isSelected
              ? theme.AppColors.textPrimary
              : theme.AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      tileColor:
          isSelected ? theme.AppColors.tunisianRed.withOpacity(0.05) : null,
      onTap: () {
        Navigator.pop(context);
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
      case 6:
        return const FrenchNewsScreen(isEmbedded: true);
      default:
        return _buildDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dashboardTheme,
      child: Scaffold(
        backgroundColor: theme.AppColors.background, // Light background
        body: Column(
          children: [
            WebNavBar(
              selectedIndex: _controller.selectedIndex,
              onItemSelected: _handleNavigation,
            ),
            Expanded(
              child: _controller.selectedIndex == 0 &&
                      _controller.totalArticles == 0
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
      frenchArticles: _controller.frenchFeaturedArticles,
      totalArticles: _controller.totalArticles,
      tunisianCount: _controller.tunisianCount,
      moroccanCount: _controller.moroccanCount,
      algerianCount: _controller.algerianCount,
      iranianCount: _controller.iranianCount,
      frenchCount: _controller.frenchCount,
      onViewWorldNews: () => _handleNavigation(5),
      onViewTunisia: () => _handleNavigation(1),
      onViewMorocco: () => _handleNavigation(2),
      onViewAlgeria: () => _handleNavigation(3),
      onViewIran: () => _handleNavigation(4),
      onViewFrance: () => _handleNavigation(6),
      isLoading: _controller.isLoading,
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
              color:
                  theme.AppColors.tunisianRed.withOpacity(0.1), // Light red bg
              borderRadius: BorderRadius.circular(20),
            ),
            // ✅ FIX: Removed 'const' to prevent invalid constant value error
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.AppColors.tunisianRed),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Curating your news...',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.AppColors.textPrimary, // Dark text
            ),
          ),
        ],
      ),
    );
  }
}
