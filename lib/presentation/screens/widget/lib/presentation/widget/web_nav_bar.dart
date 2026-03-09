import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:news_app/core/utils/responsive.dart';

class WebNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final VoidCallback onRefresh;
  final bool isLoading;
  final TextEditingController searchController;
  final VoidCallback onMenuTap; // New: Callback for menu button

  const WebNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onRefresh,
    required this.isLoading,
    required this.searchController,
    required this.onMenuTap, // New
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

          // --- Search & Actions ---
          Expanded(
            child: _buildActions(context, isMobile || isTablet),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
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
        navItem('World', 5, badge: 'INT', badgeColor: const Color(0xFF9B59B6)),
      ],
    );
  }

  Widget _buildActions(BuildContext context, bool compact) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (!compact)
          Container(
            width: 240,
            height: 40,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              controller: searchController,
              style: GoogleFonts.montserrat(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search news...',
                hintStyle: GoogleFonts.montserrat(
                    color: const Color(0xFF8B95A5), fontSize: 13),
                prefixIcon: const Icon(Icons.search,
                    color: Color(0xFF8B95A5), size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.only(left: 10, top: 10),
              ),
            ),
          ),

        _buildRefreshButton(),

        // Mobile Menu Button - Calls the callback provided by HomeScreen
        if (compact)
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: onMenuTap,
          ),

        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildRefreshButton() {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8C00), Color(0xFFFFD700)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onRefresh,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                else
                  const Icon(Icons.refresh, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  isLoading ? 'Syncing' : 'Refresh',
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
}
