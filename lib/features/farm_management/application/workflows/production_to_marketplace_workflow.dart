/// ============================================================
/// PRODUCTION → MARKETPLACE CROSS-MODULE WORKFLOW
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/marketplace/domain/repositories/marketplace_repository.dart';
import 'package:famhub_app/features/marketplace/application/providers/marketplace_provider.dart';

/// ============================================================
/// STATE
/// ============================================================
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
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// ============================================================
/// NOTIFIER (RIVERPOD 3 - CLEAN VERSION)
/// ============================================================
class CrossModuleWorkflowNotifier
    extends Notifier<CrossModuleWorkflowState> {
  FarmRepository get _farmRepository =>
      ref.read(farmRepositoryProvider);

  MarketplaceRepository get _marketplaceRepository =>
      ref.read(marketplaceRepositoryProvider);

  @override
  CrossModuleWorkflowState build() {
    return CrossModuleWorkflowState.initial();
  }

  /// ============================================================
  /// CROSS MODULE FLOW
  /// Production → Inventory → Marketplace sync
  /// ============================================================
  Future<void> syncProductionToMarketplace({String? farmId}) async {
    final effectiveFarmId = farmId ?? ref.read(farmContextProvider).farmId;
    if (effectiveFarmId == null) return;
    state = state.copyWith(isSyncing: true, errorMessage: null);
    try {
      final productionRecords =
          await _farmRepository.getProductionRecords(farmId: effectiveFarmId);
      var syncedCount = 0;
      for (final record in productionRecords) {
        try {
          await _marketplaceRepository.createListing({
            'title': 'Production #${record.id}',
            'quantity': record.quantity,
            'unit': record.unitId,
            'category': record.categoryId,
          });
          syncedCount++;
        } catch (_) {
          // Continue with next record
        }
      }
      state = state.copyWith(
        isSyncing: false,
        lastSyncResult: 'Synced $syncedCount records',
      );
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: e.toString(),
      );
    }
  }

  void clearState() {
    state = CrossModuleWorkflowState.initial();
  }
}

/// ============================================================
/// PROVIDER
/// ============================================================
final crossModuleWorkflowProvider =
    NotifierProvider<CrossModuleWorkflowNotifier, CrossModuleWorkflowState>(
  CrossModuleWorkflowNotifier.new,
);