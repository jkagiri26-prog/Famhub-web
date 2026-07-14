/// ============================================================
/// SELECTED SPATIAL ASSET PROVIDER — DEDICATED NOTIFIER
/// ============================================================
///
/// 📍 LOCATION CONTEXT:
///   core/spatial/application/ = spatial application layer
///
/// Central notifier for the currently selected spatial asset.
/// This is the single source of truth for what spatial asset
/// the user is currently working with.
///
/// ✅ Responsibilities:
///   - Manage the currently selected spatial asset
///   - Clear selection when context changes
///   - Provide reactive state for other providers
///
/// ❌ Does NOT:
///   - Import Flutter
///   - Contain business logic
///   - Contain UI
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/core/spatial/domain/spatial_asset.dart';

/// ============================================================
/// SELECTED SPATIAL ASSET NOTIFIER
/// ============================================================
///
/// Manages the currently selected spatial asset.
/// Other providers and the SDK read this to know what asset
/// the user is working with.
/// ============================================================
class SelectedSpatialAssetNotifier extends Notifier<SpatialAsset?> {
  @override
  SpatialAsset? build() => null;

  /// Select an asset.
  void select(SpatialAsset asset) {
    state = asset;
  }

  /// Select an asset by matching it from a list.
  /// Used for syncing with external sources.
  void selectById(String id, List<SpatialAsset> assets) {
    try {
      final asset = assets.firstWhere((a) => a.id == id);
      state = asset;
    } catch (_) {
      // Asset not found in the list; keep current selection
    }
  }

  /// Clear the selection.
  void clear() {
    state = null;
  }

  /// Update the current selection with new data.
  void update(SpatialAsset updated) {
    if (state?.id == updated.id) {
      state = updated;
    }
  }
}

/// ============================================================
/// PROVIDER
/// ============================================================
///
/// Provides the selected spatial asset state.
/// ============================================================
final selectedSpatialAssetProvider =
    NotifierProvider<SelectedSpatialAssetNotifier, SpatialAsset?>(
  SelectedSpatialAssetNotifier.new,
);

