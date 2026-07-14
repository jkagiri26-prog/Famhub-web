// ignore: dangling_library_doc_comments
/// ============================================================
/// APP ROUTER PROVIDER
/// ============================================================
///
/// Maps the DynamicRouteRegistrar into a Riverpod provider.
///
/// 🧠 LOCATION CONTEXT:
///   core/router/ = routing layer
///
/// ✅ Responsibilities:
///   - Provide GoRouter instance via Riverpod
///   - Single source of truth for routing
///   - Uses DynamicRouteRegistrar for dynamic route generation
///
/// ❌ Does NOT:
///   - Define routes (delegated to DynamicRouteRegistrar)
///   - Handle navigation logic
///   - Import registries
/// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/composition/router/dynamic_route_registrar.dart';
import 'package:famhub_app/core/composition/providers/composition_providers.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final enabledModules = ref.watch(runtimeModuleRegistryProvider);
  return DynamicRouteRegistrar.buildRouter(enabledModules);
});

