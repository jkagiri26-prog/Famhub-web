// ignore: dangling_library_doc_comments
/// ============================================================
/// WORKFLOW ENGINE — PHASE 3 EXPANSION
/// ============================================================
///
/// PURPOSE:
/// Provides a lightweight workflow runtime engine for cross-module
/// operational automation with priority, retry, and notification
/// capabilities. Extends the core workflow event definitions.
///
/// RESPONSIBILITIES:
/// - Register and execute WorkflowDefinitions
/// - Track active WorkflowState via AppEventBus
/// - Support priority metadata and pre-built operational workflows
/// - Emit WorkflowEvents for cross-module awareness
///
/// NON-RESPONSIBILITIES:
/// - Replacing existing event bus
/// - UI rendering
/// - Module lifecycle management
///
/// USAGE:
/// ```dart
/// final engine = WorkflowEngine(eventBus: bus);
/// engine.register(OperationalWorkflows.modulePublish);
/// engine.start('module_publish');
/// engine.completeStep('module_publish', 'validate_module');
/// ```
/// ============================================================

import 'package:famhub_app/core/events/app_event_bus.dart';
import 'package:famhub_app/core/events/workflow_events.dart';

/// Priority level for operational workflows
enum WorkflowPriority { low, normal, high, critical }

/// Extended metadata for operational workflow definitions
class WorkflowMetadata {
  final WorkflowPriority priority;
  final int maxRetries;
  final Duration retryDelay;
  final bool notifyOnCompletion;
  final bool notifyOnFailure;
  final List<String> notificationChannels;
  final Duration estimatedDuration;
  final String? ownerModule;
  final List<String> dependentModuleKeys;

  const WorkflowMetadata({
    this.priority = WorkflowPriority.normal,
    this.maxRetries = 0,
    this.retryDelay = const Duration(seconds: 5),
    this.notifyOnCompletion = false,
    this.notifyOnFailure = true,
    this.notificationChannels = const ['console'],
    this.estimatedDuration = const Duration(minutes: 5),
    this.ownerModule,
    this.dependentModuleKeys = const [],
  });
}

/// Runtime engine for executing workflows with dependency resolution
class WorkflowEngine {
  final AppEventBus _eventBus;
  final Map<String, WorkflowDefinition> _registry = {};
  final Map<String, WorkflowState> _activeStates = {};
  final Map<String, List<void Function(WorkflowState)>> _listeners = {};
  final Map<String, WorkflowMetadata> _metadata = {};

  WorkflowEngine({AppEventBus? eventBus})
      : _eventBus = eventBus ?? AppEventBus.instance;

  void register(WorkflowDefinition definition, {WorkflowMetadata? metadata}) {
    _registry[definition.name] = definition;
    if (metadata != null) _metadata[definition.name] = metadata;
  }

  WorkflowMetadata? metadata(String workflowName) => _metadata[workflowName];

  WorkflowState start(String workflowName) {
    final definition = _registry[workflowName];
    if (definition == null) throw ArgumentError('No workflow registered: $workflowName');
    final state = WorkflowState.initial(definition);
    _activeStates[workflowName] = state;
    _eventBus.emit(WorkflowEvent(workflowName: workflowName, stepName: '__start__', status: WorkflowStepStatus.inProgress));
    _notifyListeners(workflowName, state);
    return state;
  }

  WorkflowState completeStep(String workflowName, String stepName, {Map<String, dynamic> result = const {}}) {
    final current = _activeStates[workflowName];
    if (current == null) throw ArgumentError('No active workflow: $workflowName');
    final state = current.withStepCompleted(stepName, result: result);
    _activeStates[workflowName] = state;
    _eventBus.emit(WorkflowEvent.completed(workflowName: workflowName, stepName: stepName, payload: result));
    if (state.isComplete) {
      _eventBus.emit(WorkflowEvent.completed(workflowName: workflowName, stepName: '__complete__', payload: {'totalSteps': state.definition.steps.length}));
    }
    _notifyListeners(workflowName, state);
    return state;
  }

  WorkflowState failStep(String workflowName, String stepName, {String? error}) {
    final current = _activeStates[workflowName];
    if (current == null) throw ArgumentError('No active workflow: $workflowName');
    final state = current.withStepFailed(stepName, error: error);
    _activeStates[workflowName] = state;
    _eventBus.emit(WorkflowEvent.failed(workflowName: workflowName, stepName: stepName, error: error));
    _notifyListeners(workflowName, state);
    return state;
  }

  List<WorkflowStep> availableSteps(String workflowName) => _activeStates[workflowName]?.availableSteps ?? [];
  WorkflowState? state(String workflowName) => _activeStates[workflowName];
  bool isActive(String workflowName) => _activeStates.containsKey(workflowName);
  List<String> get activeWorkflows => _activeStates.keys.toList();

  void on(String workflowName, void Function(WorkflowState) listener) {
    _listeners.putIfAbsent(workflowName, () => []);
    _listeners[workflowName]!.add(listener);
  }

  void off(String workflowName, void Function(WorkflowState) listener) {
    _listeners[workflowName]?.remove(listener);
  }

  void _notifyListeners(String workflowName, WorkflowState state) {
    _listeners[workflowName]?.forEach((l) => l(state));
  }

  void reset(String workflowName) {
    _activeStates.remove(workflowName);
    _eventBus.emit(WorkflowEvent(workflowName: workflowName, stepName: '__reset__', status: WorkflowStepStatus.skipped));
  }

  void resetAll() => _activeStates.clear();
  List<String> get registeredWorkflows => _registry.keys.toList();
}

/// ============================================================
/// PRE-BUILT OPERATIONAL WORKFLOW DEFINITIONS
/// ============================================================
class OperationalWorkflows {
  OperationalWorkflows._();

  static const WorkflowDefinition modulePublish = WorkflowDefinition(
    name: 'module_publish', description: 'Publish a module to the marketplace', version: '1.0',
    steps: [
      WorkflowStep(name: 'validate_module', requires: [], description: 'Validate module integrity and security'),
      WorkflowStep(name: 'run_tests', requires: ['validate_module'], description: 'Run automated test suite'),
      WorkflowStep(name: 'build_artifact', requires: ['run_tests'], description: 'Build deployment artifact'),
      WorkflowStep(name: 'security_scan', requires: ['build_artifact'], description: 'Scan for vulnerabilities'),
      WorkflowStep(name: 'publish_to_marketplace', requires: ['build_artifact', 'security_scan'], description: 'Publish to marketplace'),
      WorkflowStep(name: 'notify_users', requires: ['publish_to_marketplace'], description: 'Notify subscribed users', isOptional: true),
    ],
  );

  static const WorkflowDefinition degradationRecovery = WorkflowDefinition(
    name: 'degradation_recovery', description: 'Automated recovery from module degradation', version: '1.0',
    steps: [
      WorkflowStep(name: 'assess_impact', requires: [], description: 'Assess degradation impact scope'),
      WorkflowStep(name: 'isolate_module', requires: ['assess_impact'], description: 'Isolate degraded module'),
      WorkflowStep(name: 'restore_checkpoint', requires: ['isolate_module'], description: 'Restore from last good checkpoint'),
      WorkflowStep(name: 'validate_recovery', requires: ['restore_checkpoint'], description: 'Validate recovery success'),
      WorkflowStep(name: 'reintegrate_module', requires: ['validate_recovery'], description: 'Reintegrate module into active set'),
    ],
  );

  static const WorkflowDefinition configRollout = WorkflowDefinition(
    name: 'config_rollout', description: 'Safe configuration rollout with rollback support', version: '1.0',
    steps: [
      WorkflowStep(name: 'validate_config', requires: [], description: 'Validate configuration schema'),
      WorkflowStep(name: 'apply_canary', requires: ['validate_config'], description: 'Apply to canary group'),
      WorkflowStep(name: 'monitor_canary', requires: ['apply_canary'], description: 'Monitor canary for 5 minutes'),
      WorkflowStep(name: 'full_rollout', requires: ['monitor_canary'], description: 'Rollout to all instances'),
      WorkflowStep(name: 'final_validation', requires: ['full_rollout'], description: 'Final validation sweep'),
    ],
  );

  static const WorkflowDefinition maintenanceWindow = WorkflowDefinition(
    name: 'maintenance_window', description: 'Orchestrated system maintenance', version: '1.0',
    steps: [
      WorkflowStep(name: 'notify_users_maintenance', requires: [], description: 'Notify users of maintenance'),
      WorkflowStep(name: 'drain_active_connections', requires: ['notify_users_maintenance'], description: 'Drain active connections'),
      WorkflowStep(name: 'disable_noncritical_modules', requires: ['drain_active_connections'], description: 'Disable non-critical modules'),
      WorkflowStep(name: 'perform_maintenance', requires: ['disable_noncritical_modules'], description: 'Perform maintenance tasks'),
      WorkflowStep(name: 're_enable_modules', requires: ['perform_maintenance'], description: 'Re-enable all modules'),
      WorkflowStep(name: 'verify_system_health', requires: ['re_enable_modules'], description: 'Verify system health'),
    ],
  );
}
