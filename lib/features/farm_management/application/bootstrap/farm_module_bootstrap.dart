/// ============================================================
/// FARM MODULE BOOTSTRAP COORDINATOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/application/bootstrap/ = application bootstrap
///
/// ✅ Responsibilities:
///   - Centralized lifecycle entry point for Farm Management module
///   - Initialize repositories
///   - Load cached farm / restore previous session
///   - Initialize providers
///   - Synchronize with RuntimeSyncEngine
///   - Preload dashboard widgets
///   - Initialize dashboard state
///
/// ✅ Pattern:
///   This coordinator should become the standard lifecycle entry point
///   for EVERY FAMHUB module. Future modules (Marketplace, Commerce,
///   Knowledge Hub, Finance, Logistics, etc.) follow the same pattern.
///
///   Page code is SIMPLIFIED to:
///     await bootstrapModule();
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - No business logic in pages
///   - No large hardcoded UI in pages
///   - Fully modular and extensible
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/application/providers/farm_selector_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_cascade_coordinator.dart';

/// ============================================================
/// BOOTSTRAP MODULE
/// ============================================================
///
/// Main entry point for module initialization.
/// Called by FarmManagementPage on first build.
///
/// Returns a FarmModuleBootstrapResult with initialization status.
/// ============================================================
class FarmModuleBootstrapResult {
  final bool success;
  final String? errorMessage;
  final bool hasFarms;
  final bool isInitialized;

  const FarmModuleBootstrapResult({
    required this.success,
    this.errorMessage,
    this.hasFarms = false,
    this.isInitialized = false,
  });
}

/// ============================================================
/// FARM MODULE BOOTSTRAP COORDINATOR
/// ============================================================
///
/// Handles full module lifecycle:
///   1. Initialize repositories
///   2. Load farms (auto-select default)
///   3. Restore previous session (cached farm ID)
///   4. Initialize providers
///   5. Preload dashboard state
/// ============================================================
class FarmModuleBootstrapCoordinator {
  final Ref ref;

  FarmModuleBootstrapCoordinator(this.ref);

  /// Bootstrap the entire farm management module.
  ///
  /// This is the SINGLE entry point for module initialization.
  /// Call this once when the page opens.
  Future<FarmModuleBootstrapResult> bootstrapModule() async {
    try {
      // Step 1: Initialize repositories (handled by provider)
      // farmRepositoryProvider is lazy — no action needed

      // Step 1b: Activate the hierarchy cascade so selecting a farm/field
      // invalidates dependent providers (fields, crops, livestock, etc.).
      ref.read(hierarchyCascadeCoordinatorProvider).setupListener();

      // Step 2: Load farms and auto-select default
      final selectorNotifier = ref.read(farmSelectorProvider.notifier);
      await selectorNotifier.loadFarms();

      // Step 3: Check initialization result
      final selectorState = ref.read(farmSelectorProvider);
      final hasFarms = selectorState.farms.isNotEmpty;
      final hasError = selectorState.errorMessage != null;

      if (hasError) {
        return FarmModuleBootstrapResult(
          success: false,
          errorMessage: selectorState.errorMessage,
          hasFarms: hasFarms,
          isInitialized: true,
        );
      }

      return FarmModuleBootstrapResult(
        success: true,
        hasFarms: hasFarms,
        isInitialized: true,
      );
    } catch (e) {
      return FarmModuleBootstrapResult(
        success: false,
        errorMessage: e.toString(),
        isInitialized: true,
      );
    }
  }
}

/// ============================================================
/// PROVIDER: FARM MODULE BOOTSTRAP COORDINATOR
/// ============================================================
final farmModuleBootstrapCoordinatorProvider =
    Provider<FarmModuleBootstrapCoordinator>((ref) {
  return FarmModuleBootstrapCoordinator(ref);
});
