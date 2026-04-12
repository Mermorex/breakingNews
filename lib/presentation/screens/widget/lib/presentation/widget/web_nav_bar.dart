import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:news_app/core/utils/responsive.dart';

class WebNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final VoidCallback? onRefresh;
  final bool isLoading;

  const WebNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.onRefresh,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1219),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // --- Logo Section ---
          _buildLogo(),

          // --- Navigation Links (Visible on Desktop) ---
          if (!isMobile && !isTablet) Expanded(child: _buildNavLinks()),

          // --- Live Status & Actions ---
          Expanded(
            child: _buildActions(context, isMobile || isTablet),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return InkWell(
      onTap: () => onItemSelected(0),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8C00), Color(0xFFFFD700)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.newspaper_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'NewsHub',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavLinks() {
    Widget navItem(String label, int index,
        {String? badge, Color? badgeColor}) {
      final isSelected = selectedIndex == index;
      return InkWell(
        onTap: () => onItemSelected(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color:
                    isSelected ? const Color(0xFFFF8C00) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Center(
            child: Row(
              children: [
                Text(
                  label,
                  style: GoogleFonts.montserrat(
                    color: isSelected ? Colors.white : const Color(0xFF8B95A5),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor ?? Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.montserrat(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        navItem('Dashboard', 0),
        navItem('Tunisia', 1, badge: 'TN', badgeColor: const Color(0xFFE74C3C)),
        navItem('Morocco', 2, badge: 'MA', badgeColor: const Color(0xFF006233)),
        navItem('Algeria', 3, badge: 'DZ', badgeColor: const Color(0xFF008000)),
        navItem('Iran', 4, badge: 'IR', badgeColor: const Color(0xFF4CAF50)),
        navItem('France', 6,
            badge: 'FR', badgeColor: const Color(0xFF0055A4)), // ADDED FRANCE
        navItem('World', 5, badge: 'INT', badgeColor: const Color(0xFF9B59B6)),
      ],
    );
  }

  Widget _buildActions(BuildContext context, bool compact) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // --- LIVE STATUS & REFRESH BUTTON ---
        _buildLiveStatusWithRefresh(context),

        const SizedBox(width: 20),

        // Mobile Menu Button
        if (compact) _buildCreativeMenuButton(context),

        const SizedBox(width: 16),
      ],
    );
  }

  // --- UPDATED: INVERSE ORDER & MOBILE FIX ---
  Widget _buildLiveStatusWithRefresh(BuildContext context) {
    // Check if mobile to hide the text message and prevent overflow
    final isMobile = ResponsiveHelper.isMobile(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Text Message (Left side) - Hidden on mobile to fix overflow
        if (!isMobile)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              'Refresh for better experience',
              style: GoogleFonts.montserrat(
                color: Colors.white54,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

        // 2. Live Status (Right side)
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.greenAccent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent.withOpacity(0.6),
                blurRadius: 6,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LIVE UPDATES',
              style: GoogleFonts.montserrat(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            // Real-time Clock
            StreamBuilder<DateTime>(
              stream: Stream.periodic(
                  const Duration(seconds: 1), (_) => DateTime.now()),
              builder: (context, snapshot) {
                final now = snapshot.data ?? DateTime.now();
                final timeStr =
                    '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
                return Text(
                  timeStr,
                  style: GoogleFonts.robotoMono(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  // --- CREATIVE MOBILE MENU BUTTON ---
  Widget _buildCreativeMenuButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showCreativeMenu(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.dashboard_rounded,
                  color: Colors.white.withOpacity(0.8),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Menu',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- CREATIVE BOTTOM SHEET NAVIGATION ---
  void _showCreativeMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF151A25).withOpacity(0.95),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Navigation',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            // Grid of Options - CHANGED TO 4 COLUMNS TO FIT FRANCE
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4, // Changed from 3 to 4
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0, // Adjusted for 4 columns
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildGridNavItem(context, 'Dashboard', 0,
                    Icons.dashboard_rounded, const Color(0xFFFF8C00)),
                _buildGridNavItem(
                    context, 'Tunisia', 1, Icons.flag, const Color(0xFFE74C3C)),
                _buildGridNavItem(
                    context, 'Morocco', 2, Icons.flag, const Color(0xFF006233)),
                _buildGridNavItem(
                    context, 'Algeria', 3, Icons.flag, const Color(0xFF008000)),
                _buildGridNavItem(
                    context, 'Iran', 4, Icons.flag, const Color(0xFF4CAF50)),
                _buildGridNavItem(context, 'France', 6, Icons.flag,
                    const Color(0xFF0055A4)), // ADDED FRANCE
                _buildGridNavItem(
                    context, 'World', 5, Icons.public, const Color(0xFF9B59B6)),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildGridNavItem(BuildContext context, String label, int index,
      IconData icon, Color color) {
    final isSelected = selectedIndex == index;

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onItemSelected(index);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.white70, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.montserrat(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
