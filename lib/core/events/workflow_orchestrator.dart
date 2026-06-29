// ignore: dangling_library_doc_comments
/// ============================================================
/// WORKFLOW ORCHESTRATOR — CROSS-MODULE BRIDGE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/events/ = system event definitions & orchestration
///
/// ✅ PURPOSE:
///   Provides a unified event-driven orchestrator that bridges
///   the existing WorkflowEvent bus with Riverpod providers and
///   module integration points.
///
///   This fills the gap between raw event emission and reactive
///   provider-driven UI updates.
///
/// ✅ RESPONSIBILITIES:
///   - Listen to WorkflowEvents from any module
///   - Bridge events to Riverpod provider invalidations
///   - Track active workflow states from events
///   - Provide reactive stream for workflow status
///
/// ✅ PATTERN:
///   Event-driven bus → Orchestrator → Provider invalidation
///
/// ❌ Does NOT:
///   - Replace WorkflowEngine (exists at pipeline level)
///   - Replace existing event system
///   - Manage workflow execution lifecycle
///   - Duplicate the EventObserver
/// ============================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/events/app_event_bus.dart';
import 'package:famhub_app/core/events/event_bus_provider.dart';
import 'package:famhub_app/core/events/workflow_events.dart';

/// Status of a tracked workflow within the orchestrator
class TrackedWorkflow {
  final String name;
  final DateTime startedAt;
  final Map<String, WorkflowStepStatus> steps;
  final Set<String> completedSteps;
  DateTime? completedAt;
  bool hasFailed;

  TrackedWorkflow({
    required this.name,
    required this.startedAt,
    this.steps = const {},
    this.completedSteps = const {},
    this.completedAt,
    this.hasFailed = false,
  });

  bool get isComplete => steps.values.every(
    (s) => s == WorkflowStepStatus.completed || s == WorkflowStepStatus.skipped,
  );

  bool get isRunning => !isComplete && !hasFailed;

  Map<String, dynamic> toJson() => {
        'name': name,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'steps': steps.map((k, v) => MapEntry(k, v.name)),
        'completedSteps': completedSteps.toList(),
        'hasFailed': hasFailed,
        'isComplete': isComplete,
      };
}

/// Orchestrator that bridges WorkflowEvents → Provider invalidation
class WorkflowOrchestrator {
  final AppEventBus _bus;
  final OrchestratorConfig _config;
  StreamSubscription<WorkflowEvent>? _subscription;

  final Map<String, TrackedWorkflow> _activeWorkflows = {};

  /// Stream of active workflow state changes
  final StreamController<Map<String, TrackedWorkflow>> _workflowStream =
      StreamController<Map<String, TrackedWorkflow>>.broadcast();

  Stream<Map<String, TrackedWorkflow>> get workflowStream =>
      _workflowStream.stream;

  Map<String, TrackedWorkflow> get activeWorkflows =>
      Map.unmodifiable(_activeWorkflows);

  WorkflowOrchestrator({
    required AppEventBus bus,
    required OrchestratorConfig config,
  })  : _bus = bus,
        _config = config;

  /// Start listening to workflow events
  void start() {
    _subscription = _bus.on<WorkflowEvent>().listen(_handleWorkflowEvent);
  }

  /// Stop listening
  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _handleWorkflowEvent(WorkflowEvent event) {
    _trackWorkflow(event);
    _bridgeToProviders(event);
  }

  /// Track workflow state from events
  void _trackWorkflow(WorkflowEvent event) {
    _activeWorkflows.putIfAbsent(
      event.workflowName,
      () => TrackedWorkflow(
        name: event.workflowName,
        startedAt: DateTime.now(),
      ),
    );

    final workflow = _activeWorkflows[event.workflowName]!;
    final updatedSteps = Map<String, WorkflowStepStatus>.from(workflow.steps)
      ..[event.stepName] = event.status;

    final updatedCompleted = Set<String>.from(workflow.completedSteps);
    if (event.status == WorkflowStepStatus.completed) {
      updatedCompleted.add(event.stepName);
    }

    _activeWorkflows[event.workflowName] = TrackedWorkflow(
      name: workflow.name,
      startedAt: workflow.startedAt,
      steps: updatedSteps,
      completedSteps: updatedCompleted,
      completedAt: event.status == WorkflowStepStatus.failed
          ? DateTime.now()
          : workflow.completedAt,
      hasFailed: event.status == WorkflowStepStatus.failed
          ? true
          : workflow.hasFailed,
    );

    // Emit updated state
    if (!_workflowStream.isClosed) {
      _workflowStream.add(Map.from(_activeWorkflows));
    }
  }

  /// Bridge workflow events to provider invalidations
  void _bridgeToProviders(WorkflowEvent event) {
    final invalidators = _config.eventBridge[event.workflowName];
    if (invalidators != null) {
      for (final invalidate in invalidators) {
        invalidate();
      }
    }
  }

  void dispose() {
    stop();
    _workflowStream.close();
  }
}

// ═══════════════════════════════════════════════════════════════
// ORCHESTRATOR PROVIDER — BRIDGES EVENT BUS + PROVIDER SYSTEM
// ═══════════════════════════════════════════════════════════════
//
// Creates a WorkflowOrchestrator that uses real provider references
// for invalidation. This provider is consumed by the app bootstrap.
//
// Provider invalidation keys are passed as callbacks to avoid
// circular imports between core/events and feature modules.
// ═══════════════════════════════════════════════════════════════

/// Signature for provider invalidation callbacks
typedef ProviderInvalidator = void Function();

/// Orchestrator configuration with generic event-to-provider mapping
///
/// Instead of hardcoded workflow→provider mappings, each workflow
/// name can register any number of invalidation callbacks.
/// Modules register their own invalidators at startup.
///
/// Usage:
/// ```dart
/// final config = OrchestratorConfig(
///   eventBridge: {
///     'kpi_automation': [() => container.invalidate(farmDashboardProvider)],
///     'stock_mutation': [
///       () => container.invalidate(assetsProvider),
///       () => container.invalidate(farmDashboardProvider),
///     ],
///     'production_publish': [
///       () => container.invalidate(farmDashboardProvider),
///       () => container.invalidate(marketplaceProvider),
///     ],
///     'production_to_marketplace': [
///       () => container.invalidate(farmDashboardProvider),
///       () => container.invalidate(marketplaceProvider),
///     ],
///   },
/// );
/// ```
class OrchestratorConfig {
  /// Generic event-to-provider binding.
  /// Key = workflow name, Value = list of invalidation callbacks.
  final Map<String, List<ProviderInvalidator>> eventBridge;

  const OrchestratorConfig({
    this.eventBridge = const {},
  });
}

/// Provider for WorkflowOrchestrator
final workflowOrchestratorProvider =
    Provider.family<WorkflowOrchestrator, OrchestratorConfig>((ref, config) {
  final bus = ref.read(eventBusProvider);
  final orchestrator = WorkflowOrchestrator(
    bus: bus,
    config: config,
  );
  orchestrator.start();

  ref.onDispose(() => orchestrator.dispose());
  return orchestrator;
});
