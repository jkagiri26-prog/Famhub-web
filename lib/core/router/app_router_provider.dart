/// ============================================================
/// APP ROUTER PROVIDER
/// ============================================================
///
/// Maps the AppRouter into a Riverpod provider.
///
/// 🧠 LOCATION CONTEXT:
///   core/router/ = routing layer
///
/// ✅ Responsibilities:
///   - Provide GoRouter instance via Riverpod
///   - Single source of truth for routing
///
/// ❌ Does NOT:
///   - Define routes (delegated to AppRouter)
///   - Handle navigation logic
///   - Import registries
/// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/router/app_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return AppRouter.createRouter();
});
