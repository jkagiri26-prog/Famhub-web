/// ============================================================
/// DASHBOARD RUNTIME VALIDATOR PROVIDER
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/application/providers/
///
/// Provides DashboardRuntimeValidator injected with user context
/// from the ContextEngine and maintenance state from runtime sync.
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/application/validation/dashboard_runtime_validator.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/module_runtime_sync/application/providers/module_runtime_sync_provider.dart';

/// Provider for the dashboard runtime validator.
/// Injects user role, tier, and maintenance module state.
///
/// The maintenance modules set is sourced from the runtime sync
/// state, which tracks which modules are under maintenance via
/// server-side flags from the ModuleRuntimeState.
final dashboardRuntimeValidatorProvider = Provider<DashboardRuntimeValidator>((ref) {
  final context = ref.watch(contextProvider);
  final runtimeState = ref.watch(moduleRuntimeSyncProvider);

  return DashboardRuntimeValidator(
    userRole: context.role,
    userTier: context.tier,
    maintenanceModules: runtimeState.maintenanceModules,
  );
});
