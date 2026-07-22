import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:news_app/core/utils/responsive.dart';
import '../constants/app_colors.dart';
import '../constants/app_fonts.dart';

class DashboardHeader extends StatelessWidget {
  final int totalArticles;
  final String currentLangMode;
  final String tickerText;
  final double textWidth;
  final AnimationController? tickerController;
  final VoidCallback onToggleLanguage;

  const DashboardHeader({
    super.key,
    required this.totalArticles,
    required this.currentLangMode,
    required this.tickerText,
    required this.textWidth,
    required this.tickerController,
    required this.onToggleLanguage,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Container(
      margin:
          EdgeInsets.fromLTRB(isMobile ? 16 : 32, 24, isMobile ? 16 : 32, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentOrange.withOpacity(0.9),
            AppColors.accentGold.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentOrange.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Top bar ---
              Padding(
                padding: EdgeInsets.fromLTRB(
                    isMobile ? 20 : 28, 24, isMobile ? 20 : 28, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'LIVE FEED',
                              style: AppFonts.caption(
                                text: 'LIVE FEED',
                                fontSize: 10,
                                color: Colors.white,
                              ).copyWith(
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                '$totalArticles',
                                style: GoogleFonts.inter(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Articles',
                                style: AppFonts.body(
                                  text: 'Articles',
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildLangToggle(),
                  ],
                ),
              ),
              // --- Ticker bar ---
              Container(
                height: 54,
                width: double.infinity,
                color: Colors.black.withOpacity(0.2),
                child: tickerController == null
                    ? Center(
                        child: Text(
                          "Loading news feed...",
                          style: AppFonts.body(
                            text: "Loading news feed...",
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      )
                    : _buildTicker(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangToggle() {
    String displayText;
    IconData iconData;
    Color bgColor;

    switch (currentLangMode) {
      case 'arabic':
        displayText = 'AR';
        iconData = Icons.translate;
        bgColor = Colors.white.withOpacity(0.25);
        break;
      case 'english':
        displayText = 'EN';
        iconData = Icons.translate;
        bgColor = Colors.white.withOpacity(0.25);
        break;
      default:
        displayText = 'ORIG';
        iconData = Icons.language;
        bgColor = Colors.white.withOpacity(0.15);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggleLanguage,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                displayText,
                style: AppFonts.caption(
                  text: displayText,
                  fontSize: 12,
                  color: Colors.white,
                ).copyWith(letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicker() {
    return ClipRect(
      child: OverflowBox(
        maxWidth: double.infinity,
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: tickerController!,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(-textWidth * tickerController!.value, 0),
              child: child,
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTickerItem(tickerText),
              const SizedBox(width: 80),
              _buildTickerItem(tickerText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTickerItem(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 6, color: AppColors.accentGold),
          const SizedBox(width: 12),
          Text(
            text,
            style: AppFonts.body(
              text: text,
              fontSize: 15,
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
