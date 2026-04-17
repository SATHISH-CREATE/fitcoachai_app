import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/floating_ai_coach.dart';
import '../../shared/utils/image_utils.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.home_rounded,           label: 'Home',    route: '/'),
    _NavItem(icon: Icons.menu_book_rounded,       label: 'Library', route: '/library'),
    _NavItem(icon: Icons.calendar_month_rounded,  label: 'Plans',   route: '/schedules'),
    _NavItem(icon: Icons.calculate_rounded,       label: 'Tools',   route: '/calculators'),
    _NavItem(icon: Icons.map_rounded,             label: 'Gyms',    route: '/gyms'),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  int _getSelectedIndex(String location) {
    if (location.startsWith('/gyms'))        return 4;
    if (location.startsWith('/calculators')) return 3;
    if (location.startsWith('/schedules'))   return 2;
    if (location.startsWith('/library'))     return 1;
    if (location.startsWith('/profile'))     return -1;
    return 0;
  }

  void _onItemTapped(int index, String currentRoute) {
    _animController.forward().then((_) => _animController.reverse());
    final route = _navItems[index].route;
    if (currentRoute != route) context.go(route);
  }
  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    final bool isHome     = location == '/' || location == '';
    final int  current    = _getSelectedIndex(location);
    final bool isProfile  = location.startsWith('/profile');

    final double bottomPad = MediaQuery.of(context).padding.bottom;
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Page content ──────────────────────────────────────────
          widget.child,

          // ── Floating AI coach ─────────────────────────────────────
          if (isHome && !isKeyboardVisible) const FloatingAICoach(),

          // ── 3D Spatial Navigation Bar ──────────────────────────────
          if (!isKeyboardVisible)
            Positioned(
              left: 6,
              right: 6,
              bottom: 12 + bottomPad,
              child: RepaintBoundary(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _PillNavBar(
                        items:         _navItems,
                        selectedIndex: current,
                        onTap:         (i) => _onItemTapped(i, location),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _ProfileCircle(
                      isActive: isProfile,
                      onTap:    () => context.go('/profile'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PillNavBar extends StatelessWidget {
  final List<_NavItem> items;
  final int            selectedIndex;
  final Function(int)  onTap;

  const _PillNavBar({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(0.04), // Slight 3D Tilt
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 25, offset: const Offset(0, 8)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(items.length, (i) {
            final isSel = selectedIndex == i;
            return Flexible(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: _ActiveBubble(
                  icon: items[i].icon,
                  isSelected: isSel,
                  label: items[i].label,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _ActiveBubble extends StatelessWidget {
  final IconData icon;
  final bool     isSelected;
  final String   label;

  const _ActiveBubble({
    required this.icon,
    required this.isSelected,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isSelected ? 30 : 20,
          height: isSelected ? 30 : 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isSelected ? AppColors.primaryGradient : null,
            color: isSelected ? null : Colors.transparent,
          ),
          child: Icon(
            icon, 
            size: isSelected ? 15 : 13, 
            color: isSelected ? Colors.white : AppColors.textMuted
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 8.5,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileCircle extends StatelessWidget {
  final bool     isActive;
  final VoidCallback onTap;

  const _ProfileCircle({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(0.04), // Matching 3D Tilt
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: isActive ? AppColors.primary : Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: isActive ? AppColors.primary.withOpacity(0.3) : Colors.black.withOpacity(0.12),
                blurRadius: 40,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.person_rounded,
              size: 32,
              color: isActive ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String   label;
  final String   route;
  const _NavItem({required this.icon, required this.label, required this.route});
}