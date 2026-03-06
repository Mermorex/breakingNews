// lib/presentation/screens/home/home_screen.dart
import 'package:flutter/material.dart' as flutter;
import 'package:flutter/material.dart' hide TextDirection;
import 'package:intl/intl.dart';
import 'package:news_app/presentation/screens/ai_chat_screen.dart';
import 'package:news_app/presentation/screens/irannews_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final Map<RssItemModel, String> _articleSourceMap = {};

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
    _buildArticleSourceMap();
    _fadeController.forward();
  }

  void _buildArticleSourceMap() {
    _articleSourceMap.clear();
    for (final entry in _controller.dashboardData.entries) {
      final sourceKey = entry.key;
      final sourceName = sourceKey.split('_').sublist(1).join('_');
      for (final article in entry.value) {
        _articleSourceMap[article] = sourceName;
      }
    }
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
    if (_controller.selectedIndex == 0 && !_controller.isLoading) {
      _buildArticleSourceMap();
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

  // ✅ UPDATED: Navigation Logic
  Widget _buildCurrentView() {
    switch (_controller.selectedIndex) {
      case 0:
        return FadeTransition(
          opacity: _fadeController,
          child: _buildDashboardView(),
        );
      case 1:
        return const TunisianNewsScreen(isEmbedded: true);
      case 2: // Was 3
        return const MoroccoNewsScreen(isEmbedded: true);
      case 3: // Was 4
        return const AlgeriaNewsScreen(isEmbedded: true);
      case 4: // Was 5
        return const IranianNewsScreen(isEmbedded: true);
      case 5: // Was 6
        return const InternationalNewsScreen(isEmbedded: true);
      default:
        return _buildDashboardView();
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
        return 'International News';
      default:
        return 'AI RSS Reader';
    }
  }

  // --- THEME CONSTANTS ---
  static const Color cryptoDarkBg = Color(0xFF0B0E14);
  static const Color cryptoCardBg = Color(0xFF151A25);
  static const Color cryptoOrange = Color(0xFFFF8C00);
  static const Color cryptoGold = Color(0xFFFFD700);

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

  // --- DASHBOARD LAYOUT ---
  Widget _buildDashboardView() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildCompactStatsHeader()),
        _buildSection(
          emoji: '🇹🇳',
          title: 'Tunisia Feed',
          articles: _controller.tunisianFeaturedArticles,
          onViewAll: () => _handleNavigation(1),
        ),
        _buildSection(
          emoji: '🇲🇦',
          title: 'Morocco Feed',
          articles: _controller.moroccanFeaturedArticles,
          onViewAll: () => _handleNavigation(3),
        ),
        _buildSection(
          emoji: '🇩🇿',
          title: 'Algeria Feed',
          articles: _controller.algerianFeaturedArticles,
          onViewAll: () => _handleNavigation(4),
        ),
        // ✅ NEW: Iran Section
        _buildSection(
          emoji: '🇮🇷',
          title: 'Iran Feed',
          articles: _controller
              .iranianFeaturedArticles, // Ensure this exists in Controller
          onViewAll: () => _handleNavigation(5),
        ),
        _buildSection(
          emoji: '🌍',
          title: 'International Feed',
          articles: _controller.internationalFeaturedArticles,
          onViewAll: () => _handleNavigation(6), // Updated Index
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  // --- HEADER ---
  Widget _buildCompactStatsHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(32, 24, 32, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [cryptoOrange, cryptoGold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cryptoOrange.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVE FEED',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.9),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_controller.totalArticles} Articles',
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildQuickStat('🇹🇳', _controller.tunisianCount),
              _buildQuickStat('🇲🇦', _controller.moroccanCount),
              _buildQuickStat('🇩🇿', _controller.algerianCount),
              _buildQuickStat('🇮🇷', _controller.iranianCount),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String emoji, int count) {
    return Container(
      margin: const EdgeInsets.only(left: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            count.toString(),
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION BUILDER ---
  Widget _buildSection({
    required String emoji,
    required String title,
    required List<RssItemModel> articles,
    required VoidCallback onViewAll,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [cryptoOrange, cryptoGold]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        height: 2,
                        width: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [cryptoOrange, cryptoGold]),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                    ],
                  ),
                ),
                _buildViewAllButton(onViewAll),
              ],
            ),
            const SizedBox(height: 20),
            if (articles.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildMainArticleCard(articles.first),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        if (articles.length > 1)
                          _buildSideArticleCard(articles[1]),
                        if (articles.length > 2) const SizedBox(height: 16),
                        if (articles.length > 2)
                          _buildSideArticleCard(articles[2]),
                      ],
                    ),
                  ),
                ],
              )
            else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildViewAllButton(VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: cryptoOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cryptoOrange.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View All',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cryptoOrange,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, size: 14, color: cryptoOrange),
            ],
          ),
        ),
      ),
    );
  }

  // --- FONT HELPER ---
  TextStyle _getTextStyle(bool isArabic, TextStyle style) {
    if (isArabic) {
      return GoogleFonts.notoKufiArabic(textStyle: style);
    } else {
      return GoogleFonts.montserrat(textStyle: style);
    }
  }

  // --- MAIN CARD ---
  Widget _buildMainArticleCard(RssItemModel article) {
    final sourceName = _articleSourceMap[article] ?? 'News';
    final bool hasArabic =
        _containsArabic(article.title) || _containsArabic(article.description);

    return GestureDetector(
      onTap: () => _launchUrl(article.link),
      child: Container(
        height: 320,
        decoration: BoxDecoration(
          color: cryptoCardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cryptoOrange.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: cryptoOrange.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [cryptoOrange, cryptoGold.withOpacity(0.5)],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: flutter.Directionality(
                  textDirection: hasArabic
                      ? flutter.TextDirection.rtl
                      : flutter.TextDirection.ltr,
                  child: Column(
                    crossAxisAlignment: hasArabic
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Row(
                        textDirection:
                            flutter.TextDirection.ltr, // Keep UI elements LTR
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: cryptoOrange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              sourceName.toUpperCase(),
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: cryptoOrange,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.access_time_rounded,
                              size: 14, color: Colors.white54),
                          const SizedBox(width: 6),
                          Text(
                            _formatTimeAgo(article.publishedAt),
                            style: GoogleFonts.montserrat(
                                fontSize: 12, color: Colors.white54),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Title with Arabic support
                      Text(
                        article.title,
                        style: _getTextStyle(
                          hasArabic,
                          const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        textAlign: hasArabic ? TextAlign.right : TextAlign.left,
                      ),
                      const SizedBox(height: 12),
                      // Description with Arabic support
                      Text(
                        _getSnippet(article.description),
                        style: _getTextStyle(
                          hasArabic,
                          TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.6),
                            height: 1.5,
                          ),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: hasArabic ? TextAlign.right : TextAlign.left,
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: hasArabic
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cryptoOrange.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.arrow_outward_rounded,
                              color: cryptoOrange, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SIDE CARD ---
  Widget _buildSideArticleCard(RssItemModel article) {
    final sourceName = _articleSourceMap[article] ?? 'News';
    final bool hasArabic = _containsArabic(article.title);

    return GestureDetector(
      onTap: () => _launchUrl(article.link),
      child: Container(
        height: 152,
        decoration: BoxDecoration(
          color: cryptoCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cryptoGold.withOpacity(0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      cryptoGold.withOpacity(0.5),
                      Colors.transparent
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: flutter.Directionality(
                  textDirection: hasArabic
                      ? flutter.TextDirection.rtl
                      : flutter.TextDirection.ltr,
                  child: Column(
                    crossAxisAlignment: hasArabic
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        sourceName.toUpperCase(),
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: cryptoGold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Title with Arabic support
                      Text(
                        article.title,
                        style: _getTextStyle(
                          hasArabic,
                          const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: hasArabic ? TextAlign.right : TextAlign.left,
                      ),
                      const Spacer(),
                      Row(
                        textDirection: flutter.TextDirection.ltr,
                        children: [
                          Text(
                            _formatTimeAgo(article.publishedAt),
                            style: GoogleFonts.montserrat(
                                fontSize: 11, color: Colors.white38),
                          ),
                          const Spacer(),
                          Icon(Icons.arrow_right_alt,
                              size: 16, color: cryptoGold.withOpacity(0.5)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- UTILS ---

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool _containsArabic(String text) {
    if (text.isEmpty) return false;
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    return arabicRegex.hasMatch(text);
  }

  Widget _buildEmptyState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: cryptoCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cryptoOrange.withOpacity(0.1)),
      ),
      child: Center(
        child: Text(
          'No articles found',
          style: GoogleFonts.montserrat(color: Colors.white38),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return 'Just now';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }

  String _getSnippet(String? description) {
    if (description == null || description.isEmpty) return '';
    return description
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
