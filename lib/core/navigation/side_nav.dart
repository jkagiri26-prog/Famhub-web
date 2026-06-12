/// ============================================================
/// SIDE NAVIGATION (TABLET/DESKTOP NAV)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/navigation/ = navigation layer
///
/// ✅ Responsibilities:
///   - Tablet/Desktop side navigation
///   - Module navigation
///   - Active state tracking
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Reference registries directly for business rules
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/router/route_names.dart';
import 'package:famhub_app/core/providers/module_provider.dart';
import 'package:famhub_app/shared/utils/icon_resolver.dart';
import 'package:famhub_app/system/registry/module_registry.dart';

class SideNav extends ConsumerWidget {
  const SideNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).location;
    final modulesAsync = ref.watch(moduleProvider);

    return NavigationRail(
      selectedIndex: _resolveIndex(location),
      onDestinationSelected: (index) => _onNavigate(context, index),
      labelType: NavigationRailLabelType.all,
      minWidth: 72,
      groupAlignment: -1.0,
      backgroundColor: Colors.white,
      indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.12),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(
              Icons.agriculture_rounded,
              color: theme.colorScheme.primary,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              'FAM',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.store_outlined),
          selectedIcon: Icon(Icons.store_rounded),
          label: Text('Market'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.agriculture_outlined),
          selectedIcon: Icon(Icons.agriculture_rounded),
          label: Text('Farm'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person_rounded),
          label: Text('Profile'),
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
