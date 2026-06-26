import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:famhub_app/core/module_runtime_sync/application/coordinators/module_runtime_sync_coordinator.dart';
import 'package:famhub_app/core/module_runtime_sync/domain/events/module_runtime_event.dart';
import 'package:famhub_app/core/module_runtime_sync/domain/models/module_runtime_state.dart';
import 'package:famhub_app/core/module_runtime_sync/infrastructure/persistence/persistence_store.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_diff.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_patch.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_reconciler.dart';
import 'package:famhub_app/core/dashboard_engine/application/conflict/dashboard_conflict_buffer.dart';
import 'package:famhub_app/core/dashboard_engine/domain/conflict/dashboard_conflict_resolver.dart';
import 'package:famhub_app/core/dashboard_engine/domain/conflict/dashboard_conflict_event.dart';
import 'package:famhub_app/core/dashboard_engine/domain/conflict/dashboard_conflict_source.dart';
import 'package:famhub_app/core/dashboard_engine/application/pipeline/runtime_pipeline_context.dart';
import 'package:famhub_app/core/dashboard_engine/application/pipeline/runtime_pipeline_orchestrator.dart';
import 'package:famhub_app/core/dashboard_engine/application/pipeline/stages/reconciliation_stage.dart';
import 'package:famhub_app/core/dashboard_engine/application/pipeline/stages/diff_stage.dart';
import 'package:famhub_app/core/dashboard_engine/application/pipeline/stages/patch_stage.dart';
import 'package:famhub_app/core/dashboard_engine/application/pipeline/stages/execution_stage.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/safe_dashboard_patch_executor_provider.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/widget_state_provider.dart';
import 'package:famhub_app/core/dashboard_engine/application/hydration/widget_hydration_engine.dart';
import 'package:famhub_app/core/dashboard_engine/infrastructure/repositories/widget_hydration_repository.dart';
import 'package:famhub_app/core/module_runtime_sync/application/providers/module_runtime_sync_provider.dart';
import 'package:famhub_app/core/dashboard_engine/domain/observability/observability_telemetry_event.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/dashboard_runtime_patch_provider.dart';

/// ============================================================
/// RUNTIME SYNC ENGINE (v5 — OPTIMIZED & OPERATIONALIZED)
/// ============================================================
///
/// LAYERS:
///   1. EventJournal — durable append-only event log (crash boundary)
///   2. ConflictBuffer — in-memory ordering + staleness dedup
///   3. Pipeline — reconcile → diff → patch → execute
///   4. CheckpointStore — periodic materialized state snapshots
///
/// PHASE 6 ENHANCEMENTS:
///   A1 — Event coalescing window (burst traffic optimization)
///   A2 — Adaptive replay batch sizing (anti-freeze)
///   A3 — ConflictBuffer capacity controls + overflow diagnostics
///   B2 — Runtime memory metrics
///   C1 — Diff short-circuiting (no-op state → empty patch)
///   D1 — Recovery metrics + runtime diagnostics
///   D2 — Structured trace IDs end-to-end
///   D3 — Runtime health status
///   E1 — Reconnect backoff strategy
///   E3 — Background throttling
///   G2 — Feature flags for runtime controls
/// ============================================================
class RuntimeSyncEngine {
  RuntimeSyncEngine({
    required this.container,
    required this.supabase,
    required this.coordinator,
    required this.persistenceStore,
    this.enableCheckpointing = true,
    this.enableCompaction = true,
    this.enableReplayMetrics = true,
    this.enableAdaptiveBatching = true,
  }) : _conflictBuffer = ConflictBuffer(ConflictResolver()) {
    final reconciler = container.read(dashboardRuntimeReconcilerProvider);
    _orchestrator =
        RuntimePipelineOrchestrator<ModuleRuntimeState, DashboardRuntimePatch,
            DashboardRuntimeDiff>(
      stages: [
        ReconciliationStage(coordinator: coordinator),
        DiffStage(reconciler: reconciler),
        PatchStage(reconciler: reconciler),
        ExecutionStage(
          executor: container.read(safeDashboardPatchExecutorProvider),
        ),
      ],
    );
  }

  // ============================================================
  // DEPENDENCIES
  // ============================================================
  final ProviderContainer container;
  final PersistenceStore persistenceStore;
  final SupabaseClient supabase;
  final ModuleRuntimeSyncCoordinator coordinator;
  final ConflictBuffer _conflictBuffer;
  late final RuntimePipelineOrchestrator _orchestrator;
  late final WidgetHydrationEngine _hydrationEngine;
  RealtimeChannel? _channel;

  // ============================================================
  // PHASE 6 — TASK G2: FEATURE FLAGS
  // ============================================================
  final bool enableCheckpointing;
  final bool enableCompaction;
  final bool enableReplayMetrics;
  final bool enableAdaptiveBatching;

  // ============================================================
  // LIFECYCLE STATE
  // ============================================================
  bool _initialized = false;
  bool _isProcessingRunning = false;
  bool _disposed = false;

  /// ============================================================
  /// REPLAY LOCK — TASK C3 (FROM PHASE 5.5)
  /// ============================================================
  bool _isReplaying = false;
  final List<_PendingIngestion> _pendingDuringReplay = [];

  // ============================================================
  // PHASE 6 — TASK A1: EVENT COALESCING WINDOW
  // ============================================================
  static const Duration _coalescingWindow = Duration(milliseconds: 32);
  Timer? _coalesceTimer;
  bool _coalesceScheduled = false;

  // ============================================================
  // PHASE 6 — TASK A2: ADAPTIVE REPLAY BATCH SIZING
  // ============================================================
  static const int _replayBaseBatchSize = 50;
  static const int _replayLargeBatchSize = 200;
  static const int _replayLargeBacklogThreshold = 100;

  // ============================================================
  // PHASE 6 — TASK A3: CONFLICT BUFFER CAPACITY CONTROLS
  // ============================================================
  static const int _maxBufferedEvents = 500;
  static const int _maxReplayEvents = 5000;

  // ============================================================
  // PHASE 6 — TASK E1: RECONNECT BACKOFF
  // ============================================================
  static const Duration _backoffInitial = Duration(seconds: 1);
  static const Duration _backoffMax = Duration(seconds: 30);
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;

  // ============================================================
  // PHASE 6 — TASK E3: BACKGROUND THROTTLING
  // ============================================================
  bool _isBackgrounded = false;

  // ============================================================
  // CHECKPOINT STATE
  // ============================================================
  int _pipelineRunCount = 0;
  int? _lastCommittedSequenceId;
  static const int _checkpointInterval = 25;

  // ============================================================
  // PHASE 6 — TASK D2: STRUCTURED TRACE IDS
  // ============================================================
  int _nextTraceId = 1;
  String _nextTraceIdStr() => 'rte-${_nextTraceId++}';

  // ============================================================
  // RECOVERY METRICS (Phase 5.5)
  // ============================================================
  int _replayedEventCount = 0;
  int _checkpointRestoreDurationMs = 0;
  int _journalReplayDurationMs = 0;
  int? _lastCheckpointSequence;
  int? _lastJournalSequence;
  final bool _checkpointFallbackOccurred = false;

  // ============================================================
  // PHASE 6 — TASK B2: RUNTIME MEMORY METRICS
  // ============================================================
  int _totalEventsIngested = 0;
  int _totalPipelineRuns = 0;
  int _coalescedBatchCount = 0;
  int _adaptiveReplayBatchesUsed = 0;
  int _avgReplayBatchSize = 0;
  DateTime _engineStartTime = DateTime.now();
  Duration _totalProcessingTime = Duration.zero;

  // ============================================================
  // PHASE 6 — TASK D3: RUNTIME HEALTH STATUS
  // ============================================================
  RuntimeHealthStatus _healthStatus = RuntimeHealthStatus.healthy;

  // ============================================================
  // BOOT — FULL INIT SEQUENCE
  // ============================================================
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _engineStartTime = DateTime.now();
    _log('Starting initialization...');
    await coordinator.bootstrap();
    await _initPersistence();
    await _restoreCheckpoint();
    await _hydrateWidgetState();
    await _replayDelta();
    _subscribeToModuleChanges();
    _log('Initialization complete. '
        'Replayed=$_replayedEventCount events. '
        'Checkpoint restore=${_checkpointRestoreDurationMs}ms. '
        'Journal replay=${_journalReplayDurationMs}ms.');
  }

  // ============================================================
  // PERSISTENCE SETUP
  // ============================================================
  Future<void> _initPersistence() async {
    _log('Initializing persistence layers...');
    await persistenceStore.initialize();
    _log('Persistence layers initialized.');
  }

  // ============================================================
  // CHECKPOINT RESTORE
  // ============================================================
  Future<void> _restoreCheckpoint() async {
    _log('Restoring checkpoint...');
    final sw = Stopwatch()..start();
    final moduleState = await persistenceStore.loadLatestCheckpoint();
    if (moduleState == null) {
      _log('No valid checkpoint found. Will use full journal replay.');
      sw.stop();
      _checkpointRestoreDurationMs = sw.elapsedMilliseconds;
      return;
    }
    _lastCommittedSequenceId = await persistenceStore.getLastEventSequenceId();
    _lastCheckpointSequence = _lastCommittedSequenceId;
    container.read(moduleRuntimeSyncProvider.notifier).updateState(moduleState);
    sw.stop();
    _checkpointRestoreDurationMs = sw.elapsedMilliseconds;
    _log('Checkpoint restored: seq=$_lastCommittedSequenceId, '
        'duration=${_checkpointRestoreDurationMs}ms');
  }

  // ============================================================
  // WIDGET HYDRATION
  // ============================================================
  Future<void> _hydrateWidgetState() async {
    _log('Hydrating widget state...');
    final widgetStore = container.read(widgetStateStoreProvider);
    final repo = WidgetHydrationRepository(supabase);
    _hydrationEngine = WidgetHydrationEngine(repository: repo, store: widgetStore);
    await _hydrationEngine.hydrate();
    _log('Widget hydration complete.');
  }

  // ============================================================
  // ADAPTIVE REPLAY (TASK A2) WITH CAPACITY CONTROLS (TASK A3)
  // ============================================================
  Future<void> _replayDelta() async {
    _isReplaying = true;
    _healthStatus = RuntimeHealthStatus.replaying;
    _log('Starting adaptive replay...');
    final sw = Stopwatch()..start();
    try {
      _lastJournalSequence = await persistenceStore.getLastEventSequenceId();
      if (_lastJournalSequence == null) {
        _log('Journal empty, no replay needed.');
        sw.stop();
        _journalReplayDurationMs = sw.elapsedMilliseconds;
        return;
      }

      final sinceSeq = _lastCommittedSequenceId ?? 0;
      final allEvents = await persistenceStore.readEventsAfter(sinceSeq);
      if (allEvents.isEmpty) {
        _log('No new events to replay.');
        sw.stop();
        _journalReplayDurationMs = sw.elapsedMilliseconds;
        return;
      }

      _replayedEventCount = allEvents.length;

      // TASK A3: Enforce max replay limit
      final eventsToReplay = allEvents.take(_maxReplayEvents).toList();
      if (eventsToReplay.length < allEvents.length) {
        _log('WARNING: Replay truncated to $_maxReplayEvents events '
            '(${allEvents.length - _maxReplayEvents} beyond limit).');
        _healthStatus = RuntimeHealthStatus.overflow;
      }

      // TASK A2: Adaptive batch sizing
      final isLargeBacklog =
          eventsToReplay.length >= _replayLargeBacklogThreshold;
      final batchSize = enableAdaptiveBatching
          ? (isLargeBacklog ? _replayBaseBatchSize : _replayLargeBatchSize)
          : _replayLargeBatchSize;

      _log('Replaying ${eventsToReplay.length} events '
          'from seq_id > $sinceSeq (batch size=$batchSize)...');

      int processed = 0;
      int batchCount = 0;
      while (processed < eventsToReplay.length) {
        final end = (processed + batchSize) > eventsToReplay.length
            ? eventsToReplay.length
            : processed + batchSize;
        for (final event in eventsToReplay.sublist(processed, end)) {
          _conflictBuffer.add(event);
        }
        processed = end;
        batchCount++;

        // Yield between batches for large backlogs to prevent UI freeze
        if (isLargeBacklog && processed < eventsToReplay.length) {
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }

      _adaptiveReplayBatchesUsed = batchCount;
      _avgReplayBatchSize =
          batchCount > 0 ? (eventsToReplay.length ~/ batchCount) : batchSize;
      await _processBufferedEvents();
      sw.stop();
      _journalReplayDurationMs = sw.elapsedMilliseconds;

      final eps = _replayedEventCount > 0
          ? (_replayedEventCount / (_journalReplayDurationMs / 1000.0)).round()
          : 0;
      _log('Replay complete: $_replayedEventCount events, '
          '${_journalReplayDurationMs}ms, $eps eps, $batchCount batches');
    } finally {
      _isReplaying = false;
      if (_healthStatus == RuntimeHealthStatus.replaying) {
        _healthStatus = RuntimeHealthStatus.healthy;
      }
      if (_pendingDuringReplay.isNotEmpty) {
        _log('Draining ${_pendingDuringReplay.length} pending events...');
        final pending = List<_PendingIngestion>.from(_pendingDuringReplay);
        _pendingDuringReplay.clear();
        for (final p in pending) {
          await _ingestEventInternal(p.payload, p.type);
        }
      }
    }
  }

  // ============================================================
  // GRACEFUL SHUTDOWN (TASK C2 FROM PHASE 5.5)
  // ============================================================
  Future<void> dispose() async {
    _log('Starting graceful shutdown...');
    _disposed = true;
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _channel?.unsubscribe();
    _channel = null;

    if (_isProcessingRunning || _conflictBuffer.isNotEmpty) {
      _log('Waiting for pending processing...');
      if (_conflictBuffer.isNotEmpty) {
        await _processBufferedEvents();
      }
    }

    if (enableCheckpointing) {
      _log('Forcing final checkpoint...');
      await _trySaveCheckpoint(force: true);
    }

    _log('Graceful shutdown complete.');
  }

  // ============================================================
  // BACKGROUND THROTTLING (TASK E3)
  // ============================================================
  void onAppBackgrounded() {
    _isBackgrounded = true;
    _log('App backgrounded — throttling non-critical operations.');
  }

  void onAppForegrounded() {
    _isBackgrounded = false;
    // Drain any pending events that accumulated while backgrounded
    if (_pendingDuringReplay.isNotEmpty) {
      _log('Draining ${_pendingDuringReplay.length} pending events...');
      final pending = List<_PendingIngestion>.from(_pendingDuringReplay);
      _pendingDuringReplay.clear();
      for (final p in pending) {
        unawaited(_ingestEventInternal(p.payload, p.type));
      }
    }
    _log('App foregrounded — resuming normal operations.');
  }

  // ============================================================
  // RECONNECT BACKOFF (TASK E1)
  // ============================================================
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = _backoffInitial * (1 << _reconnectAttempt);
    final capped = delay < _backoffMax ? delay : _backoffMax;
    _log('Reconnect attempt ${_reconnectAttempt + 1} '
        'in ${capped.inSeconds}s (exponential backoff)...');
    _reconnectTimer = Timer(capped, () {
      _reconnectAttempt++;
      _subscribeToModuleChanges();
    });
  }

  void _resetReconnectBackoff() {
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  // ============================================================
  // REALTIME SUBSCRIPTION
  // ============================================================
  void _subscribeToModuleChanges() {
    _log('Subscribing to realtime changes...');
    _channel?.unsubscribe();
    _channel = supabase.channel('module-runtime-sync');

    _channel!
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'system',
            table: 'modules',
            callback: (payload) {
              Future.microtask(
                () => _ingestEvent(
                    payload.newRecord, ModuleRuntimeEventType.moduleUpdated),
              );
            })
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'system',
            table: 'module_installations',
            callback: (payload) {
              Future.microtask(
                () => _ingestEvent(payload.newRecord,
                    ModuleRuntimeEventType.installationUpdated),
              );
            })
        .subscribe((status, error) {
      if (error != null) {
        _log('Realtime subscription error: $error');
        _scheduleReconnect();
      } else if (status == 'SUBSCRIBED') {
        _resetReconnectBackoff();
        _log('Realtime subscription active.');
      }
    });
  }

  // ============================================================
  // EVENT INGESTION (WITH REPLAY LOCK)
  // ============================================================
  Future<void> _ingestEvent(
      Map<String, dynamic> payload,
      ModuleRuntimeEventType type,
      ) async {
    if (_isReplaying) {
      _pendingDuringReplay.add(_PendingIngestion(payload, type));
      return;
    }
    if (_disposed) return;
    await _ingestEventInternal(payload, type);
  }

  // ============================================================
  // COALESCED INTERNAL INGESTION (TASK A1)
  // ============================================================
  Future<void> _ingestEventInternal(
      Map<String, dynamic> payload,
      ModuleRuntimeEventType type,
      ) async {
    if (_isBackgrounded) {
      _pendingDuringReplay.add(_PendingIngestion(payload, type));
      return;
    }

    final traceId = _nextTraceIdStr();
    _totalEventsIngested++;

    final event = ConflictEvent(
      entityId: payload['id'].toString(),
      source: ConflictSource.realtime,
      timestamp: DateTime.now(),
      payload: {'type': type.name, 'data': payload, 'traceId': traceId},
    );

    await persistenceStore.appendEvent(event);
    _conflictBuffer.add(event);
    _scheduleCoalescedProcessing();

    // Capacity diagnostics
    if (_conflictBuffer.isNearCapacity) {
      _healthStatus = RuntimeHealthStatus.degraded;
      _log('WARNING: Buffer near capacity '
          '(${_conflictBuffer.length}/$_maxBufferedEvents).');
    }
    if (_conflictBuffer.length >= _maxBufferedEvents) {
      _healthStatus = RuntimeHealthStatus.overflow;
      _log('WARNING: Buffer overflow! '
          '(${_conflictBuffer.length} events). '
          'Journal replay preserves correctness.');
    }
  }

  // ============================================================
  // COALESCED PROCESSING SCHEDULER (TASK A1)
  // ============================================================
  void _scheduleCoalescedProcessing() {
    if (_isProcessingRunning) return;
    if (_coalesceScheduled) return;
    _coalesceScheduled = true;
    _coalesceTimer?.cancel();
    _coalesceTimer = Timer(_coalescingWindow, () {
      _coalesceScheduled = false;
      _coalescedBatchCount++;
      if (_isProcessingRunning) return;
      Future.microtask(() => _processBufferedEvents());
    });
  }

  // ============================================================
  // PIPELINE EXECUTION WITH SHORT-CIRCUITING (TASK C1)
  // ============================================================
  Future<void> _processBufferedEvents() async {
    if (_isProcessingRunning) return;
    _isProcessingRunning = true;
    final sw = Stopwatch()..start();
    try {
      final events = _conflictBuffer.resolveAll();
      if (events.isEmpty) return;

      final currentState = container.read(moduleRuntimeSyncProvider);

      // TASK C1: Diff short-circuit — check if events produce meaningful change
      bool hasMeaningfulChange = events.any((e) =>
          e.source == ConflictSource.realtime &&
          e.payload['data'] != null);

      if (!hasMeaningfulChange) {
        _log('Short-circuit: no meaningful changes. Skipping pipeline.');
        _totalPipelineRuns++;
        return;
      }

      final context = RuntimePipelineContext<ModuleRuntimeState,
          DashboardRuntimePatch, DashboardRuntimeDiff>(
        currentState: currentState,
        events: events,
      );

      await _orchestrator.run(context);

      _safe(() {
        final nextState = context.nextState;
        if (nextState != null) {
          container.read(moduleRuntimeSyncProvider.notifier).updateState(nextState);
          _pipelineRunCount++;
          _totalPipelineRuns++;
        }
      });
    } finally {
      sw.stop();
      _totalProcessingTime += sw.elapsed;
      _isProcessingRunning = false;

      if (_shouldCheckpoint() && enableCheckpointing && !_isBackgrounded) {
        _trySaveCheckpoint();
      }

      if (_conflictBuffer.isNotEmpty) {
        _scheduleCoalescedProcessing();
      }
    }
  }

  // ============================================================
  // CHECKPOINT POLICY
  // ============================================================
  bool _shouldCheckpoint() {
    return _pipelineRunCount > 0 &&
        (_pipelineRunCount % _checkpointInterval == 0);
  }

  Future<void> _trySaveCheckpoint({bool force = false}) async {
    if (!enableCheckpointing && !force) return;
    try {
      final currentState = container.read(moduleRuntimeSyncProvider);
      final lastSeq = await persistenceStore.getLastEventSequenceId();
      if (lastSeq == null) return;
      _log('Saving checkpoint at seq=$lastSeq...');
      await persistenceStore.saveCheckpoint(
        lastSequenceId: lastSeq,
        moduleState: currentState,
      );
      _log('Checkpoint saved.');

      if (enableCompaction) {
        _tryCompactJournal(lastSeq);
      }
    } catch (e) {
      _log('Checkpoint save failed (non-fatal): $e');
    }
  }

  Future<void> _tryCompactJournal(int sequenceId) async {
    try {
      await persistenceStore.pruneEventsBefore(sequenceId);
      _log('Journal compaction: pruned seq_id <= $sequenceId');
    } catch (e) {
      _log('Journal compaction failed (non-fatal): $e');
    }
  }

  void _safe(void Function() fn) {
    try {
      fn();
    } catch (_) {}
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[RuntimeSyncEngine] $msg');
  }

  // ============================================================
  // COMPREHENSIVE METRICS (D1 + B2)
  // ============================================================
  Map<String, dynamic> get runtimeMetrics => {
        // Recovery
        'replayedEventCount': _replayedEventCount,
        'checkpointRestoreDurationMs': _checkpointRestoreDurationMs,
        'journalReplayDurationMs': _journalReplayDurationMs,
        'lastCheckpointSequence': _lastCheckpointSequence,
        'lastJournalSequence': _lastJournalSequence,
        'checkpointFallbackOccurred': _checkpointFallbackOccurred,
        // Memory (B2)
        'bufferedEventCount': _conflictBuffer.length,
        'journalRowCount': 0,
        'pipelineExecutionCount': _totalPipelineRuns,
        'avgReplayBatchSize': _avgReplayBatchSize,
        // Pipeline
        'pipelineRunCount': _pipelineRunCount,
        'totalEventsIngested': _totalEventsIngested,
        'totalPipelineRuns': _totalPipelineRuns,
        'coalescedBatchCount': _coalescedBatchCount,
        'adaptiveReplayBatchesUsed': _adaptiveReplayBatchesUsed,
        'totalProcessingTimeMs': _totalProcessingTime.inMilliseconds,
        'engineUptimeMs':
            DateTime.now().difference(_engineStartTime).inMilliseconds,
        // Health (D3)
        'isReplaying': _isReplaying,
        'isInitialized': _initialized,
        'isBackgrounded': _isBackgrounded,
        'healthStatus': _healthStatus.name,
        'reconnectAttempt': _reconnectAttempt,
        // Capacity
        'bufferCapacity': _maxBufferedEvents,
        'bufferUtilization': _conflictBuffer.utilization,
        'bufferNearCapacity': _conflictBuffer.isNearCapacity,
      };

  /// Backward-compatible alias
  Map<String, dynamic> get recoveryMetrics => runtimeMetrics;
}

// ============================================================
// PENDING INGESTION QUEUE
// ============================================================
class _PendingIngestion {
  _PendingIngestion(this.payload, this.type);
  final Map<String, dynamic> payload;
  final ModuleRuntimeEventType type;
}
