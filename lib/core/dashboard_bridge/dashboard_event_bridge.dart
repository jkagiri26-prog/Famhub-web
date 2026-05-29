import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/events/app_event_bus.dart';
import 'package:famhub_app/core/events/events.dart';

import '../dashboard_engine/application/providers/dashboard_runtime_patch_provider.dart';

/// ============================================================
/// DASHBOARD EVENT BRIDGE
/// ============================================================
/// Single safe entry point for all runtime → dashboard mutations.
///
/// Guarantees:
/// - No duplicate patch application
/// - Sequential execution (no race conditions)
/// - Decoupling from runtime engine
class DashboardEventBridge {
  DashboardEventBridge(this.ref, this.bus);

  final Ref ref;
  final AppEventBus bus;

  StreamSubscription<AppEvent>? _subscription;

  /// 🔒 prevents duplicate patch application
  final Set<String> _processedPatchIds = {};

  /// 🔒 ensures sequential execution
  bool _isProcessing = false;

  /// ============================================================
  /// START LISTENER
  /// ============================================================
  void start() {
    _subscription = bus.stream.listen(_handleEvent);
  }

  /// ============================================================
  /// EVENT DISPATCH
  /// ============================================================
  void _handleEvent(AppEvent event) {
    if (event is DashboardPatchEvent) {
      _handlePatch(event);
    }
  }

  /// ============================================================
  /// PATCH HANDLER (CRITICAL PATH)
  /// ============================================================
  void _handlePatch(DashboardPatchEvent event) async {
    final patch = event.patch;

    /// ------------------------------------------------------------
    /// 1. DEDUPLICATION STRATEGY
    /// ------------------------------------------------------------
    final patchId = _extractPatchId(patch);

    if (patchId != null) {
      if (_processedPatchIds.contains(patchId)) {
        return; // already applied
      }
      _processedPatchIds.add(patchId);
    }

    /// ------------------------------------------------------------
    /// 2. QUEUE PROCESSING (NO RACE CONDITIONS)
    /// ------------------------------------------------------------
    if (_isProcessing) {
      await Future.delayed(const Duration(milliseconds: 10));
      _handlePatch(event);
      return;
    }

    _isProcessing = true;

    try {
      /// --------------------------------------------------------
      /// 3. APPLY PATCH TO DASHBOARD STATE
      /// --------------------------------------------------------
      ref
          .read(dashboardRuntimePatchProvider.notifier)
          .applyPatch(patch);

    } catch (_) {
      /// intentionally swallowed — dashboard must not crash runtime
    } finally {
      _isProcessing = false;
    }
  }

  /// ============================================================
  /// PATCH IDENTIFIER EXTRACTION
  /// ============================================================
  /// Attempts to extract stable ID for deduplication.
  /// Falls back to hash if not available.
  String? _extractPatchId(dynamic patch) {
    try {
      if (patch == null) return null;

      /// common patterns:
      if (patch.id != null) return patch.id.toString();

      if (patch.runtimeType.toString().contains('Patch')) {
        return patch.hashCode.toString();
      }

      return patch.hashCode.toString();
    } catch (_) {
      return null;
    }
  }

  /// ============================================================
  /// STOP LISTENER
  /// ============================================================
  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}