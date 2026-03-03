import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts

// top_bar.dart - Crypto Tech Dark Theme
class TopBar extends StatelessWidget {
  final VoidCallback onRefresh;
  final bool isLoading;
  final TextEditingController? searchController;
  final Function(String)? onSearch;
  final String? title;

  // Crypto Tech Palette
  static const Color _bgColor = Color(0xFF0B0E14); // Matches Home Screen
  static const Color _cardColor = Color(0xFF151A25); // Dark Grey for inputs
  static const Color _accentOrange = Color(0xFFFF8C00);
  static const Color _textWhite = Colors.white;
  static const Color _textGrey = Color(0xFF8B95A5);

  const TopBar({
    super.key,
    required this.onRefresh,
    required this.isLoading,
    this.searchController,
    this.onSearch,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        // Use Dark Background
        color: _bgColor,
        // Subtle Bottom Border
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: GoogleFonts.montserrat(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _textWhite,
              ),
            ),
            const SizedBox(width: 32),
          ],
          Expanded(
            flex: 3,
            child: _SearchField(
              controller: searchController,
              onChanged: onSearch,
            ),
          ),
          const Spacer(),
          _ActionButton(
            icon: isLoading ? null : Icons.refresh_rounded,
            isLoading: isLoading,
            onPressed: isLoading ? null : onRefresh,
            tooltip: 'Refresh feeds',
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.notifications_outlined,
            onPressed: () {},
            badge: '3',
          ),
          const SizedBox(width: 16),
          _ProfileAvatar(),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController? controller;
  final Function(String)? onChanged;

  const _SearchField({this.controller, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      // Dark "Glassy" Input Style
      decoration: BoxDecoration(
        color: const Color(0xFF151A25), // Darker than bg
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          // Orange Icon for accent
          const Icon(Icons.search, color: Color(0xFFFF8C00), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search across all news sources...',
                hintStyle: GoogleFonts.montserrat(
                  color: const Color(0xFF8B95A5),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0E14),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Text(
              '⌘K',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: const Color(0xFF8B95A5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? badge;
  final String? tooltip;

  const _ActionButton({
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.badge,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Stack(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 40,
                height: 40,
                // Dark Button Style
                decoration: BoxDecoration(
                  color: const Color(0xFF151A25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF8C00)), // Orange Loader
                        ),
                      )
                    : Icon(icon, size: 20, color: const Color(0xFF8B95A5)),
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8C00), // Orange Badge
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0B0E14), width: 2),
                ),
                child: Text(
                  badge!,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      // Crypto Gradient (Orange to Gold)
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF8C00),
            Color(0xFFFFD700),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.person_outline,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}
