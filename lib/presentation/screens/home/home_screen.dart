// lib/presentation/screens/home/home_screen.dart
import 'package:flutter/material.dart' as flutter;
import 'package:flutter/material.dart' hide TextDirection;
import 'package:intl/intl.dart';
import 'package:news_app/presentation/screens/ai_chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:news_app/presentation/screens/Tunisianscreen.dart';
import 'package:news_app/presentation/screens/francescreen.dart';
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

  Widget _buildCurrentView() {
    switch (_controller.selectedIndex) {
      case 0:
        return FadeTransition(
          opacity: _fadeController,
          child: _buildDashboardView(),
        );
      case 1:
        return const TunisianNewsScreen(isEmbedded: true);
      case 2:
        return const FranceNewsScreen(isEmbedded: true);
      case 3:
        return const MoroccoNewsScreen(isEmbedded: true);
      case 4:
        return const AlgeriaNewsScreen(isEmbedded: true);
      case 5:
        return const InternationalNewsScreen(isEmbedded: true);
      case 6: // <--- THIS IS THE KEY ADDITION
        return const AIChatScreen();
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
        return 'France News';
      case 3:
        return 'Moroccan News';
      case 4:
        return 'Algerian News';
      case 5:
        return 'International News';
      case 6: // <--- THIS IS THE KEY ADDITION
        return 'AI News Assistant';
      default:
        return 'AI RSS Reader';
    }
  }

  // Crypto Tech Colors
  static const Color cryptoDarkBg = Color(0xFF0B0E14);
  static const Color cryptoCardBg = Color(0xFF151A25);
  static const Color cryptoOrange = Color(0xFFFF8C00);
  static const Color cryptoGold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dashboardTheme,
      child: Scaffold(
        // FIX: Force Dark Background on Scaffold
        backgroundColor: cryptoDarkBg,
        body: Row(
          children: [
            Sidebar(
              selectedIndex: _controller.selectedIndex,
              onItemSelected: _handleNavigation,
            ),
            Expanded(
              child: Container(
                // FIX: Force Dark Background on Main Container
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

  Widget _buildDashboardView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - 64;
        const cardMinWidth = 280.0;
        const cardMaxWidth = 400.0;
        const gap = 16.0;

        final cardsCount = 3;
        final totalGap = gap * (cardsCount - 1);
        final cardWidth = ((availableWidth - totalGap) / cardsCount)
            .clamp(cardMinWidth, cardMaxWidth);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeroStats()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 40),
                  _buildRegionRow(
                    emoji: '🇹🇳',
                    title: 'Tunisian News',
                    subtitle: 'Latest from Tunisia',
                    // Use Crypto Glow Colors
                    articles:
                        _controller.tunisianFeaturedArticles.take(3).toList(),
                    onViewAll: () => _handleNavigation(1),
                    cardWidth: cardWidth,
                    gap: gap,
                  ),
                  const SizedBox(height: 40),
                  _buildRegionRow(
                    emoji: '🇫🇷',
                    title: 'France News',
                    subtitle: 'Latest from France',
                    articles:
                        _controller.frenchFeaturedArticles.take(3).toList(),
                    onViewAll: () => _handleNavigation(2),
                    cardWidth: cardWidth,
                    gap: gap,
                  ),
                  const SizedBox(height: 40),
                  _buildRegionRow(
                    emoji: '🇲🇦',
                    title: 'Moroccan News',
                    subtitle: 'Le360, Hespress & more',
                    articles:
                        _controller.moroccanFeaturedArticles.take(3).toList(),
                    onViewAll: () => _handleNavigation(3),
                    cardWidth: cardWidth,
                    gap: gap,
                  ),
                  const SizedBox(height: 40),
                  _buildRegionRow(
                    emoji: '🇩🇿',
                    title: 'Algerian News',
                    subtitle: 'TSA, El Watan & more',
                    articles:
                        _controller.algerianFeaturedArticles.take(3).toList(),
                    onViewAll: () => _handleNavigation(4),
                    cardWidth: cardWidth,
                    gap: gap,
                  ),
                  const SizedBox(height: 40),
                  _buildRegionRow(
                    emoji: '🌍',
                    title: 'International',
                    subtitle: 'Al Jazeera, BBC, Reuters',
                    articles: _controller.internationalFeaturedArticles
                        .take(3)
                        .toList(),
                    onViewAll: () => _handleNavigation(5),
                    cardWidth: cardWidth,
                    gap: gap,
                  ),
                  const SizedBox(height: 48),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeroStats() {
    return Container(
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(24),
      // Crypto Gradient: Orange to Gold
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF8C00), // Dark Orange
            Color(0xFFFFD700), // Gold
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        // Intense Glow for Hero
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8C00).withOpacity(0.4),
            blurRadius: 40,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'News Overview',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 1.0, // Tech feel
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_controller.totalArticles} Articles',
                    style: GoogleFonts.montserrat(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildQuickStat('🇹🇳', _controller.tunisianCount),
              const SizedBox(width: 12),
              _buildQuickStat('🇫🇷', _controller.frenchCount),
              const SizedBox(width: 12),
              _buildQuickStat('🇲🇦', _controller.moroccanCount),
              const SizedBox(width: 12),
              _buildQuickStat('🇩🇿', _controller.algerianCount),
              const SizedBox(width: 12),
              _buildQuickStat('🌍', _controller.internationalCount),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String emoji, int count) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionRow({
    required String emoji,
    required String title,
    required String subtitle,
    required List<RssItemModel> articles,
    required VoidCallback onViewAll,
    required double cardWidth,
    required double gap,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // Crypto Glow Border for Header Icon
                  gradient:
                      const LinearGradient(colors: [cryptoOrange, cryptoGold]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: cryptoOrange.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              _buildViewAllButton(onViewAll),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 220,
          child: articles.isEmpty
              ? _buildEmptyState()
              : Row(
                  children: [
                    for (int i = 0; i < articles.length; i++) ...[
                      Expanded(
                        child: _buildArticleCard(
                          articles[i],
                          cardWidth: double.infinity,
                        ),
                      ),
                      if (i < articles.length - 1) SizedBox(width: gap),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildViewAllButton(VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: cryptoOrange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cryptoOrange.withOpacity(0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View All',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cryptoOrange,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: cryptoOrange,
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _getTextStyle(bool isArabic, TextStyle style) {
    if (isArabic) {
      return GoogleFonts.notoKufiArabic(textStyle: style);
    } else {
      return GoogleFonts.montserrat(textStyle: style);
    }
  }

  Widget _buildArticleCard(
    RssItemModel article, {
    double? cardWidth,
  }) {
    final sourceName = _articleSourceMap[article] ?? 'News';
    final bool hasArabic =
        _containsArabic(article.title) || _containsArabic(article.description);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          final Uri url = Uri.parse(article.link);
          if (await canLaunchUrl(url)) {
            await launchUrl(
              url,
              mode: LaunchMode.externalApplication,
              webOnlyWindowName: '_blank',
            );
          }
        },
        child: Container(
          width: cardWidth,
          height: 220,
          // Dark Crypto Card Style
          decoration: BoxDecoration(
            color: cryptoCardBg,
            borderRadius: BorderRadius.circular(20),
            // Glowing Border
            border: Border.all(
              color: cryptoOrange.withOpacity(0.2),
              width: 1,
            ),
            // Subtle Glow Shadow
            boxShadow: [
              BoxShadow(
                color: cryptoOrange.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: flutter.Directionality(
              textDirection: hasArabic
                  ? flutter.TextDirection.rtl
                  : flutter.TextDirection.ltr,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Left Accent Strip (Orange Glow)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            cryptoOrange,
                            cryptoGold.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: hasArabic
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Row(
                          textDirection: flutter.TextDirection.ltr,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: cryptoOrange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                sourceName,
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: cryptoOrange,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: Colors.white54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTimeAgo(article.publishedAt),
                              style: _getTextStyle(
                                  hasArabic,
                                  TextStyle(
                                    fontSize: 11,
                                    color: Colors.white54,
                                  )),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Text(
                            article.title,
                            style: _getTextStyle(
                                hasArabic,
                                TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                  color: Colors.white,
                                )),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign:
                                hasArabic ? TextAlign.right : TextAlign.left,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          textDirection: flutter.TextDirection.ltr,
                          children: [
                            Expanded(
                              child: Text(
                                _getSnippet(article.description),
                                style: _getTextStyle(
                                    hasArabic,
                                    TextStyle(
                                      fontSize: 12,
                                      height: 1.3,
                                      color: Colors.white60,
                                    )),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: hasArabic
                                    ? TextAlign.right
                                    : TextAlign.left,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cryptoOrange.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_outward_rounded,
                                size: 16,
                                color: cryptoOrange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _containsArabic(String text) {
    if (text.isEmpty) return false;
    final arabicRegex = RegExp(
        r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return arabicRegex.hasMatch(text);
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cryptoCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cryptoOrange.withOpacity(0.2),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rss_feed_outlined,
            size: 48,
            color: cryptoOrange.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No recent articles',
            style: GoogleFonts.montserrat(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
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
    final clean = description
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return clean.length > 80 ? '${clean.substring(0, 80)}...' : clean;
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
            width: 80,
            height: 80,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8C00).withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8C00)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Curating your news...',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gathering latest stories from around the world',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}
