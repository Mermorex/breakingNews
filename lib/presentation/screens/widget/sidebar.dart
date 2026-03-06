import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  // Crypto Tech Palette
  static const Color _sidebarBg = Color(0xFF0F1219);
  static const Color _cryptoOrange = Color(0xFFFF8C00);
  static const Color _cryptoGold = Color(0xFFFFD700);
  static const Color _textWhite = Colors.white;
  static const Color _textGrey = Color(0xFF8B95A5);

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required bool isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: _sidebarBg,
      child: Column(
        children: [
          _buildHeader(),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.05),
            margin: const EdgeInsets.symmetric(horizontal: 24),
          ),
          Expanded(child: _buildNavigation()),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_cryptoOrange, _cryptoGold],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _cryptoOrange.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.newspaper_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NewsHub',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _textWhite,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Desktop Edition',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  color: _textGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigation() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      children: [
        // Index 0: Dashboard
        _NavItem(
          icon: Icons.dashboard_rounded,
          label: 'Dashboard',
          isSelected: selectedIndex == 0,
          onTap: () => onItemSelected(0),
        ),
        const SizedBox(height: 8),

        // Index 1: Tunisian News
        _NavItem(
          icon: Icons.flag_rounded,
          label: 'Tunisian News',
          badge: 'TN',
          badgeColor: const Color(0xFFE74C3C).withOpacity(0.2),
          badgeTextColor: const Color(0xFFE74C3C),
          isSelected: selectedIndex == 1,
          onTap: () => onItemSelected(1),
        ),
        const SizedBox(height: 8),

        // Index 2: Moroccan News (Fixed)
        _NavItem(
          icon: Icons.flag_rounded,
          label: 'Moroccan News',
          badge: 'MA',
          badgeColor: const Color(0xFF006233).withOpacity(0.2),
          badgeTextColor: const Color(0xFF006233),
          isSelected: selectedIndex == 2, // Changed from 3 to 2
          onTap: () => onItemSelected(2), // Changed from 3 to 2
        ),
        const SizedBox(height: 8),

        // Index 3: Algerian News (Fixed)
        _NavItem(
          icon: Icons.flag_rounded,
          label: 'Algerian News',
          badge: 'DZ',
          badgeColor: const Color(0xFF008000).withOpacity(0.2),
          badgeTextColor: const Color(0xFF008000),
          isSelected: selectedIndex == 3, // Changed from 4 to 3
          onTap: () => onItemSelected(3), // Changed from 4 to 3
        ),
        const SizedBox(height: 8),

        // Index 4: Iranian News (Fixed)
        _NavItem(
          icon: Icons.flag_rounded,
          label: 'Iranian News',
          badge: 'IR',
          badgeColor: const Color(0xFF4CAF50).withOpacity(0.2),
          badgeTextColor: const Color(0xFF4CAF50),
          isSelected: selectedIndex == 4, // Changed from 5 to 4
          onTap: () => onItemSelected(4), // Changed from 5 to 4
        ),
        const SizedBox(height: 8),

        // Index 5: International (Fixed)
        _NavItem(
          icon: Icons.language_rounded,
          label: 'International',
          badge: 'INT',
          badgeColor: const Color(0xFF9B59B6).withOpacity(0.2),
          badgeTextColor: const Color(0xFF9B59B6),
          isSelected: selectedIndex == 5, // Changed from 6 to 5
          onTap: () => onItemSelected(5), // Changed from 6 to 5
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.settings_outlined,
              size: 16,
              color: _textGrey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Settings',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: _textGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _cryptoOrange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'v2.0',
              style: GoogleFonts.montserrat(
                fontSize: 10,
                color: _cryptoOrange,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final Color? badgeColor;
  final Color? badgeTextColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.badge,
    this.badgeColor,
    this.badgeTextColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color activeColor = Color(0xFFFF8C00);
    const Color inactiveIcon = Color(0xFF8B95A5);
    const Color inactiveText = Color(0xFF8B95A5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:
                isSelected ? activeColor.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: activeColor.withOpacity(0.3))
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isSelected ? activeColor : inactiveIcon,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : inactiveText,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge!,
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: badgeTextColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
