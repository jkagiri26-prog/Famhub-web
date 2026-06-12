/// ============================================================
/// PRODUCTION → MARKETPLACE CROSS-MODULE WORKFLOW
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/application/workflows/
///
/// FIRST CROSS-MODULE FLOW:
///   Farm Management → Production Recorded → Inventory Updated
///   → Marketplace Listing Suggested
///
/// ✅ PATTERN:
///   Uses existing providers from both modules.
///   NO duplicate state systems.
///   NO parallel workflow systems.
///   NO direct Supabase in presentation.
/// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/models/production_model.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/production_provider.dart';

/// State for the cross-module workflow
class CrossModuleWorkflowState {
  final bool isSyncing;
  final String? lastSyncResult;
  final String? errorMessage;

  const CrossModuleWorkflowState({
    this.isSyncing = false,
    this.lastSyncResult,
    this.errorMessage,
  });

  factory CrossModuleWorkflowState.initial() =>
      const CrossModuleWorkflowState();

  CrossModuleWorkflowState copyWith({
    bool? isSyncing,
    String? lastSyncResult,
    String? errorMessage,
  }) {
    return CrossModuleWorkflowState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncResult: lastSyncResult ?? this.lastSyncResult,
      errorMessage: errorMessage,
    );
  }
}

/// Notifier for cross-module workflow
class CrossModuleWorkflowNotifier extends StateNotifier<CrossModuleWorkflowState> {
  final FarmRepository _repository;
  final String? _farmId;

  CrossModuleWorkflowNotifier(this._repository, this._farmId)
      : super(CrossModuleWorkflowState.initial());

  /// When a production record is created, trigger:
  /// 1. Refresh production data
  /// 2. Sync to marketplace
  Future<void> onProductionRecorded() async {
    if (_farmId == null) return;

    state = state.copyWith(isSyncing: true, errorMessage: null);

    try {
      // Step 1: Sync inventory with marketplace
      await _repository.syncMarketplaceListing(farmId: _farmId!);

      state = state.copyWith(
        isSyncing: false,
        lastSyncResult: 'Production recorded and marketplace inventory synced.',
      );
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: 'Workflow failed: $e',
      );
    }
  }

  void clearState() {
    state = CrossModuleWorkflowState.initial();
  }
}

/// Provider for cross-module workflow
final crossModuleWorkflowProvider = StateNotifierProvider.family<
    CrossModuleWorkflowNotifier, CrossModuleWorkflowState, String?>(
  (ref, farmId) {
    final repository = ref.read(farmRepositoryProvider);
    return CrossModuleWorkflowNotifier(repository, farmId);
  },
);
