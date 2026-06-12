import 'dart:async';

import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_patch.dart';

class SmartPatchCoalescer {
  SmartPatchCoalescer({
    required this.onExecute,
  });

  /// Final execution callback (your Patch Executor hook)
  final Future<void> Function(DashboardRuntimePatch patch) onExecute;

  final List<DashboardRuntimePatch> _buffer = [];

  Timer? _timer;

  bool _isProcessing = false;

  /// ============================================================
  /// ADD PATCH INTO BUFFER
  /// ============================================================
  void add(DashboardRuntimePatch patch) {
    if (patch.isEmpty) return;

    _buffer.add(patch);

    _scheduleFlush();
  }

  /// ============================================================
  /// SCHEDULE FLUSH (DEBOUNCED BATCH WINDOW)
  /// ============================================================
  void _scheduleFlush() {
    _timer?.cancel();

    _timer = Timer(
      const Duration(milliseconds: 120),
      _flush,
    );
  }

  /// ============================================================
  /// FLUSH + MERGE + EXECUTE
  /// ============================================================
    Future<void> _flush() async {
    if (_isProcessing || _buffer.isEmpty) return;

    _isProcessing = true;

    /// ==========================================================
    /// SNAPSHOT COPY + IMMEDIATE CLEAR (PREVENTS PATCH LOSS)
    /// ==========================================================
    final batch = List<DashboardRuntimePatch>.from(_buffer);
    _buffer.clear();

    final merged = _mergePatches(batch);

    await onExecute(merged);

    _isProcessing = false;
  }

  /// ============================================================
  /// PATCH MERGER (CORE INTELLIGENCE)
  /// ============================================================
  DashboardRuntimePatch _mergePatches(
    List<DashboardRuntimePatch> patches,
  ) {
    final Map<String, DashboardPatchAction> mergedActions = {};

    for (final patch in patches) {
      for (final action in patch.actions) {
        final key = '${action.type}_${action.target}';

        /// LAST WRITE WINS (safe for UI state)
        mergedActions[key] = action;
      }
    }

    return DashboardRuntimePatch(
      actions: mergedActions.values.toList(),
    );
  }

  void dispose() {
    _timer?.cancel();
    _buffer.clear();
  }
}