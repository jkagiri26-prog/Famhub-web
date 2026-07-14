/// ============================================================
/// SYNC STATE PROVIDER — Live sync status
/// ============================================================
///
/// Provides the current sync status for the status bar.
/// Watches the module runtime sync engine state.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/core/module_runtime_sync/application/providers/module_runtime_sync_provider.dart';

/// Status of the synchronization engine.
enum SyncStatus {
  synced,
  syncing,
  pending,
  error,
}

/// Provider that derives sync status from the module runtime sync state.
/// If the runtime state has never been initialized (still loading),
/// returns pending. Otherwise returns synced.
final syncStateProvider = Provider<SyncStatus>((ref) {
  final runtimeState = ref.watch(moduleRuntimeSyncProvider);
  // If we have a runtime state, we're synced
  if (runtimeState.activeModules.isNotEmpty ||
      runtimeState.disabledModules.isNotEmpty) {
    return SyncStatus.synced;
  }
  return SyncStatus.pending;
});
