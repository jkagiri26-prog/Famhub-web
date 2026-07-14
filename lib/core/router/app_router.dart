import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/composition/router/dynamic_route_registrar.dart';
import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';

/// ============================================================
/// ⚠️ DEPRECATED — APP ROUTER
/// ============================================================
///
/// 🧠 ARCHITECTURAL NOTE (September 2026):
///   This file is retained as a thin compatibility wrapper
///   for any code that may still reference AppRouter.createRouter().
///
/// 🏛️ ROUTING DEFINITIONS NOW LIVE IN:
///   lib/core/composition/router/dynamic_route_registrar.dart
///   → DynamicRouteRegistrar.buildRouter()
///
/// 📋 MIGRATION HISTORY:
///   - STAGE 2, TASK 2A.2: Switched appRouterProvider from
///     AppRouter.createRouter() → DynamicRouteRegistrar.buildRouter()
///   - STAGE 2, TASK 2A.3: Stripped duplicate route definitions
///     from this file. Converted to delegation wrapper.
///
/// 🗺️ SOURCES OF TRUTH:
///   - route definitions:    DynamicRouteRegistrar + ModulePageRegistry
///   - route constants:      AppRoutes (lib/core/router/route_names.dart)
///   - route catalog:        RouteRegistry (lib/system/registry/route_registry.dart)
///   - module definitions:   ModuleRegistry (lib/system/registry/module_registry.dart)
///
/// ✅ If you need to add/change routes, edit:
///   lib/core/composition/router/dynamic_route_registrar.dart
///
/// ❌ Do NOT add routes here.
/// ============================================================
///
/// [DEPRECATED] AppRouter.createRouter() is a compatibility shim.
/// It delegates to DynamicRouteRegistrar.buildRouter() with an
/// empty module list. All runtime route building is now handled
/// by appRouterProvider → DynamicRouteRegistrar.
///
/// This method is NO LONGER CALLED by appRouterProvider.
/// It exists only to prevent import breakage in any legacy code.
class AppRouter {
  /// ⚠️ DEPRECATED — Use DynamicRouteRegistrar.buildRouter() instead.
  ///
  /// This method is kept as a compatibility shim.
  /// It delegates to DynamicRouteRegistrar.buildRouter() with
  /// an empty module list. Routes will NOT contain dynamic
  /// module routes when called through this method.
  ///
  /// The runtime route provider (appRouterProvider) now uses:
  ///   DynamicRouteRegistrar.buildRouter(enabledModules)
  ///   where enabledModules comes from runtimeModuleRegistryProvider.
  static GoRouter createRouter() {
    // ⚠️ Deliberately empty module list — this is a compatibility shim.
    // The real routing is done by appRouterProvider which passes
    // enabled modules from runtimeModuleRegistryProvider.
    return DynamicRouteRegistrar.buildRouter([]);
  }

  /// ⚠️ DEPRECATED — Use DynamicRouteRegistrar.buildRouter() instead.
  static GoRouter createRouterWithModules(List<RuntimeModule> modules) {
    return DynamicRouteRegistrar.buildRouter(modules);
  }
}
