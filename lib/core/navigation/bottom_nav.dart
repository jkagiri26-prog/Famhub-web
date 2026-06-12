/// ============================================================
/// BOTTOM NAVIGATION (MOBILE NAV)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/navigation/ = navigation layer
///
/// ✅ Responsibilities:
///   - Mobile bottom navigation bar
///   - Route navigation on tap
///   - Active state tracking
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Reference registries directly
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/router/route_names.dart';

class BottomNav extends ConsumerWidget {
  const BottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).location;

    return NavigationBar(
      selectedIndex: _resolveIndex(location),
      onDestinationSelected: (index) => _onNavigate(context, index),
      backgroundColor: Colors.white,
      indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.store_outlined),
          selectedIcon: Icon(Icons.store_rounded),
          label: 'Market',
        ),
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    );
  }

  int _resolveIndex(String location) {
    if (location == AppRoutes.root) return 0;
    if (location.startsWith(AppRoutes.marketplace)) return 1;
    if (location.startsWith(AppRoutes.farm)) return 2;
    if (location.startsWith(AppRoutes.profile)) return 3;
    return 0;
  }

  void _onNavigate(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.root);
        break;
      case 1:
        context.go(AppRoutes.marketplace);
        break;
      case 2:
        context.go(AppRoutes.farm);
        break;
      case 3:
        context.go(AppRoutes.profile);
        break;
    }
  }
}
