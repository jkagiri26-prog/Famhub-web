// ignore: dangling_library_doc_comments
/// ============================================================
/// ROUTE REGISTRY (PURE STATIC ROUTE MAPPING)
/// ============================================================
///
/// SYSTEM/REGISTRY = SOURCE OF TRUTH CATALOG ONLY
///
/// Static mapping from module IDs to their route paths.
///
/// ✅ Allowed:
///   - Static module → route mapping
///   - Route name definitions
///
/// ❌ Forbidden:
///   - Navigation/routing runtime logic
///   - GoRouter configuration
///   - Widget/page imports
///   - Provider imports
///   - Async/service calls
/// ============================================================

import 'registry_contracts.dart';

/// ============================================================
/// ROUTE REGISTRY — STATIC ROUTE MAPPING CATALOG
/// ============================================================
///
/// Maps each module to its primary entry route.
/// This is a STATIC mapping only.
///
/// 🧠 SEPARATION OF CONCERNS:
///   - system/registry/route_registry.dart = WHAT routes exist
///   - core/router/ = HOW routing/navigation works
///   - core/router/app_router.dart = GoRouter configuration
/// ============================================================
class RouteRegistry {
  /// ============================================================
  /// ALL ROUTE MAPPINGS (STATIC DECLARATIONS)
  /// ============================================================
  static const List<RouteMapping> mappings = [
    RouteMapping(
      moduleId: 'root',
      route: '/',
      routeName: 'root',
    ),
    RouteMapping(
      moduleId: 'farm_management',
      route: '/farm',
      routeName: 'farm',
    ),
    RouteMapping(
      moduleId: 'marketplace',
      route: '/marketplace',
      routeName: 'marketplace',
    ),
    RouteMapping(
      moduleId: 'analytics',
      route: '/analytics',
      routeName: 'analytics',
    ),
    RouteMapping(
      moduleId: 'finance',
      route: '/finance',
      routeName: 'finance',
    ),
    RouteMapping(
      moduleId: 'logistics',
      route: '/logistics',
      routeName: 'logistics',
    ),
    RouteMapping(
      moduleId: 'traceability',
      route: '/traceability',
      routeName: 'traceability',
    ),
    RouteMapping(
      moduleId: 'carbon_credit',
      route: '/carbon-credit',
      routeName: 'carbonCredit',
    ),
    RouteMapping(
      moduleId: 'knowledge',
      route: '/knowledge',
      routeName: 'knowledge',
    ),
    RouteMapping(
      moduleId: 'agribusiness',
      route: '/agribusiness',
      routeName: 'agribusiness',
    ),
    RouteMapping(
      moduleId: 'opportunities',
      route: '/opportunities',
      routeName: 'opportunities',
    ),
    RouteMapping(
      moduleId: 'extension_services',
      route: '/extension',
      routeName: 'extension',
    ),
    RouteMapping(
      moduleId: 'agri_connect',
      route: '/connect',
      routeName: 'agriConnect',
    ),
    RouteMapping(
      moduleId: 'agri_tech_lab',
      route: '/tech-lab',
      routeName: 'agriTechLab',
    ),
    RouteMapping(
      moduleId: 'referral_hub',
      route: '/referrals',
      routeName: 'referrals',
    ),
    RouteMapping(
      moduleId: 'profile',
      route: '/profile',
      routeName: 'profile',
    ),
    RouteMapping(
      moduleId: 'admin_console',
      route: '/admin',
      routeName: 'admin',
    ),
    RouteMapping(
      moduleId: 'guest',
      route: '/guest',
      routeName: 'guest',
    ),
    RouteMapping(
      moduleId: 'not_found',
      route: '/404',
      routeName: 'notFound',
    ),
  ];

  /// ============================================================
  /// PURE LOOKUP HELPERS
  /// ============================================================

  /// Get route for a module ID.
  static RouteMapping? forModule(String moduleId) {
    for (final mapping in mappings) {
      if (mapping.moduleId == moduleId) return mapping;
    }
    return null;
  }

  /// Get module ID for a route path.
  static RouteMapping? forRoute(String route) {
    for (final mapping in mappings) {
      if (mapping.route == route) return mapping;
    }
    return null;
  }

  /// Get all route paths as a list.
  static List<String> get allRoutes =>
      mappings.map((m) => m.route).toList();

  /// Get all route names as a map (routeName → route).
  static Map<String, String> get routeNameMap => {
        for (final m in mappings)
          if (m.routeName != null) m.routeName!: m.route,
      };
}
