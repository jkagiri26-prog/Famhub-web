import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/coordinators/module_runtime_sync_coordinator.dart';
import 'domain/events/module_runtime_event.dart';
import 'domain/models/module_runtime_state.dart';

import '../dashboard_engine/application/reconciliation/dashboard_runtime_diff.dart';
import '../dashboard_engine/application/reconciliation/dashboard_runtime_patch.dart';
import '../dashboard_engine/application/reconciliation/dashboard_runtime_reconciler.dart';

import '../dashboard_engine/domain/conflict/conflict_buffer.dart';
import '../dashboard_engine/domain/conflict/conflict_resolver.dart';
import '../dashboard_engine/domain/conflict/conflict_event.dart';
import '../dashboard_engine/domain/conflict/conflict_source.dart';

import '../dashboard_engine/application/pipeline/runtime_pipeline_context.dart';
import '../dashboard_engine/application/pipeline/runtime_pipeline_orchestrator.dart';

import '../dashboard_engine/application/pipeline/stages/reconciliation_stage.dart';
import '../dashboard_engine/application/pipeline/stages/diff_stage.dart';
import '../dashboard_engine/application/pipeline/stages/patch_stage.dart';
import '../dashboard_engine/application/pipeline/stages/execution_stage.dart';

import '../dashboard_engine/application/providers/safe_dashboard_patch_executor_provider.dart';

class RuntimeSyncEngine {
  RuntimeSyncEngine({
    required this.ref,
    required this.supabase,
    required this.coordinator,
  }) : _conflictBuffer = ConflictBuffer(const ConflictResolver()) {
    final reconciler = ref.read(dashboardRuntimeReconcilerProvider);

    _orchestrator = RuntimePipelineOrchestrator<
        ModuleRuntimeState,
        DashboardRuntimePatch,
        DashboardRuntimeDiff>(
      stages: [
        ReconciliationStage(coordinator: coordinator),
        DiffStage(reconciler: reconciler),
        PatchStage(reconciler: reconciler),
        ExecutionStage(
          executor: ref.read(safeDashboardPatchExecutorProvider),
        ),
      ],
    );
  }

  final Ref ref;
  final SupabaseClient supabase;
  final ModuleRuntimeSyncCoordinator coordinator;

  final ConflictBuffer _conflictBuffer;

  late final RuntimePipelineOrchestrator _orchestrator;

  RealtimeChannel? _channel;

  bool _initialized = false;
  bool _isProcessingScheduled = false;
  bool _isProcessingRunning = false;

  // ============================================================
  // INIT
  // ============================================================
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await coordinator.bootstrap();
    _subscribeToModuleChanges();
  }

  Future<void> dispose() async {
    await _channel?.unsubscribe();
  }

  // ============================================================
  // REALTIME SUBSCRIPTION
  // ============================================================
  void _subscribeToModuleChanges() {
    _channel = supabase.channel('module-runtime-sync');

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'system',
          table: 'modules',
          callback: (payload) => _ingestEvent(
            payload.newRecord,
            ModuleRuntimeEventType.moduleUpdated,
          ),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'system',
          table: 'module_installations',
          callback: (payload) => _ingestEvent(
            payload.newRecord,
            ModuleRuntimeEventType.installationUpdated,
          ),
        )
        .subscribe();
  }

  // ============================================================
  // EVENT INGESTION
  // ============================================================
  void _ingestEvent(
    Map<String, dynamic> payload,
    ModuleRuntimeEventType type,
  ) {
    _conflictBuffer.add(
      ConflictEvent(
        entityId: payload['id'].toString(),
        source: ConflictSource.realtime,
        timestamp: DateTime.now(),
        payload: {
          'type': type.name,
          'data': payload,
        },
      ),
    );

    _scheduleProcessing();
  }

  // ============================================================
  // PROCESSING SCHEDULER
  // ============================================================
  void _scheduleProcessing() {
    if (_isProcessingScheduled || _isProcessingRunning) return;

    _isProcessingScheduled = true;

    Future.microtask(() async {
      _isProcessingScheduled = false;
      await _processBufferedEvents();
    });
  }

  // ============================================================
  // PIPELINE EXECUTION
  // ============================================================
  Future<void> _processBufferedEvents() async {
    if (_isProcessingRunning) return;

    _isProcessingRunning = true;

    try {
      final events = _conflictBuffer.resolveAll();
      if (events.isEmpty) return;

      final currentState = ref.read(moduleRuntimeSyncProvider);

      final context = RuntimePipelineContext<
          ModuleRuntimeState,
          DashboardRuntimePatch,
          DashboardRuntimeDiff>(
        currentState: currentState,
        events: events,
      );

      /// ===============================
      /// PIPELINE EXECUTION
      /// ===============================
      await _orchestrator.run(context);

      /// ===============================
      /// FINALIZE CONTEXT (IMMUTABILITY LOCK)
      /// ===============================
      context.finalize();

      /// ===============================
      /// SAFE STATE COMMIT
      /// ===============================
      _safe(() {
        final nextState = context.nextState;

        if (nextState != null) {
          ref
              .read(moduleRuntimeSyncProvider.notifier)
              .updateState(nextState);
        }
      });

    } finally {
      _isProcessingRunning = false;
    }
  }

  // ============================================================
  // SAFE WRAPPER
  // ============================================================
  void _safe(void Function() fn) {
    try {
      fn();
    } catch (_) {
      // intentionally swallowed
    }
  }
}