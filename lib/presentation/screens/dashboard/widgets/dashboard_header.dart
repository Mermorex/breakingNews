import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:news_app/data/models/rss_item_model.dart';

import '../constants/app_colors.dart';
import '../constants/app_fonts.dart';

class DashboardHeader extends StatelessWidget {
  final RssItemModel? topArticle;
  final String Function(RssItemModel) getDisplayTitle;
  final String Function(RssItemModel) getDisplaySource;
  final Future<void> Function(String) onLaunchUrl;

  const DashboardHeader({
    super.key,
    required this.topArticle,
    required this.getDisplayTitle,
    required this.getDisplaySource,
    required this.onLaunchUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (topArticle == null) {
      return Container(
        margin:
            EdgeInsets.fromLTRB(isMobile ? 16 : 32, 24, isMobile ? 16 : 32, 0),
        height: isMobile ? 200 : 280,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Center(
          child: CircularProgressIndicator(
              color: AppColors.accentOrange.withOpacity(0.5)),
        ),
      );
    }

    final displayTitle = getDisplayTitle(topArticle!);
    final displaySource = getDisplaySource(topArticle!);
    final isArabic = AppFonts.containsArabic(displayTitle);

    return GestureDetector(
      onTap: () => onLaunchUrl(topArticle!.link),
      child: Container(
        margin:
            EdgeInsets.fromLTRB(isMobile ? 16 : 32, 24, isMobile ? 16 : 32, 0),
        height: isMobile ? 320 : 400,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              AppColors.accentOrange.withOpacity(0.85),
              AppColors.bgDark.withOpacity(0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentOrange.withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Subtle texture overlay
              Container(color: Colors.white.withOpacity(0.03)),

              // Content
              Padding(
                padding: EdgeInsets.all(isMobile ? 24 : 40),
                child: Column(
                  crossAxisAlignment: isArabic
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'TOP STORY • $displaySource',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Massive Title
                    Text(
                      displayTitle,
                      style: AppFonts.title(
                        text: displayTitle,
                        fontSize: isMobile ? 24 : 34,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    ),

                    const SizedBox(height: 16),

                    // Read more indicator
                    Row(
                      mainAxisAlignment: isArabic
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.end,
                      children: [
                        Text(
                          isArabic ? 'اقرأ المزيد' : 'Read full story',
                          style: AppFonts.caption(
                            text: isArabic ? 'اقرأ المزيد' : 'Read full story',
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isArabic
                              ? Icons.arrow_back_rounded
                              : Icons.arrow_forward_rounded,
                          color: Colors.white.withOpacity(0.8),
                          size: 16,
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
    );
  }
}
