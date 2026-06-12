/// ============================================================
/// WORKFLOW EVENTS — FORMALIZED WORKFLOW ORCHESTRATION SEED
/// ============================================================
///
/// PURPOSE:
/// Provides event-based workflow orchestration structures as a
/// formalization seed for cross-module workflow patterns
/// (e.g. Production → Marketplace publishing pipeline).
///
/// This is the GAP-CLOSURE for G8: "No formalized cross-module
/// workflow engine."
///
/// LAYER 1: Workflow Event Definitions (this file)
/// LAYER 2: Workflow Definitions (workflow_definitions.dart)
/// LAYER 3: Workflow Engine (workflow_engine.dart) — future
///
/// 🧠 LOCATION CONTEXT:
///   core/events/ = system event definitions
///
/// ✅ CONTAINS:
///   - WorkflowEvent — base event type for workflow steps
///   - WorkflowStep — a single step in a workflow
///   - WorkflowDefinition — ordered steps + metadata
///   - WorkflowState — tracking state for active workflows
///   - WorkflowStepResult — outcome of a step execution
///
/// ❌ Does NOT:
///   - Implement the full workflow runtime (future phase)
///   - Replace existing event system
///   - Execute side effects
///
/// USAGE (FUTURE):
///   // Define a workflow
///   final publishWorkflow = WorkflowDefinition(
///     name: 'production_publish',
///     steps: [
///       WorkflowStep(name: 'validate_module', requires: []),
///       WorkflowStep(name: 'build_artifact', requires: ['validate_module']),
///       WorkflowStep(name: 'publish_to_marketplace', requires: ['build_artifact']),
///     ],
///   );
///
///   // Emit step event
///   AppEventBus.instance.emit(
///     WorkflowEvent(workflowName: 'production_publish', step: 'build_artifact'),
///   );
/// ============================================================

import 'package:famhub_app/core/events/app_event_bus.dart';

/// ============================================================
/// WORKFLOW EVENT
/// ============================================================
///
/// Emitted when a workflow step is triggered or completed.
/// The AppEventBus carries these for cross-module coordination.
/// ============================================================
class WorkflowEvent extends AppEvent {
  /// Name of the workflow (e.g., 'production_publish')
  final String workflowName;

  /// Name of the step being triggered/completed
  final String stepName;

  /// Status of this step
  final WorkflowStepStatus status;

  /// Payload data for this step
  final Map<String, dynamic> payload;

  const WorkflowEvent({
    required this.workflowName,
    required this.stepName,
    this.status = WorkflowStepStatus.pending,
    this.payload = const {},
  });

  /// Create a completed event
  factory WorkflowEvent.completed({
    required String workflowName,
    required String stepName,
    Map<String, dynamic> payload = const {},
  }) =>
      WorkflowEvent(
        workflowName: workflowName,
        stepName: stepName,
        status: WorkflowStepStatus.completed,
        payload: payload,
      );

  /// Create a failed event
  factory WorkflowEvent.failed({
    required String workflowName,
    required String stepName,
    String? error,
  }) =>
      WorkflowEvent(
        workflowName: workflowName,
        stepName: stepName,
        status: WorkflowStepStatus.failed,
        payload: error != null ? {'error': error} : const {},
      );
}

/// Status of a workflow step
enum WorkflowStepStatus {
  pending,
  inProgress,
  completed,
  failed,
  skipped,
}

/// ============================================================
/// WORKFLOW STEP DEFINITION
/// ============================================================
///
/// Defines a single step in a workflow. Steps have dependencies
/// on other steps and can be configured with timeouts and retries.
/// ============================================================
class WorkflowStep {
  /// Unique name of this step within the workflow
  final String name;

  /// Names of steps that must complete before this one
  final List<String> requires;

  /// Optional description
  final String? description;

  /// Timeout for this step (null = no timeout)
  final Duration? timeout;

  /// Whether this step is optional
  final bool isOptional;

  const WorkflowStep({
    required this.name,
    this.requires = const [],
    this.description,
    this.timeout,
    this.isOptional = false,
  });

  /// Check if this step has all dependencies satisfied
  bool areDependenciesMet(Set<String> completedSteps) {
    return requires.every((dep) => completedSteps.contains(dep));
  }
}

/// ============================================================
/// WORKFLOW DEFINITION
/// ============================================================
///
/// Immutable definition of a complete workflow.
/// Contains all steps and metadata for execution.
/// ============================================================
class WorkflowDefinition {
  /// Unique name for this workflow
  final String name;

  /// Ordered list of steps
  final List<WorkflowStep> steps;

  /// Optional description
  final String? description;

  /// Optional version for compatibility checks
  final String? version;

  const WorkflowDefinition({
    required this.name,
    required this.steps,
    this.description,
    this.version,
  });

  /// Get a specific step by name
  WorkflowStep? step(String name) {
    try {
      return steps.firstWhere((s) => s.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Get initial steps (no dependencies)
  List<WorkflowStep> get initialSteps =>
      steps.where((s) => s.requires.isEmpty).toList();

  /// Get available steps given completed set
  List<WorkflowStep> availableSteps(Set<String> completedSteps) {
    return steps
        .where((s) => !completedSteps.contains(s.name))
        .where((s) => s.areDependenciesMet(completedSteps))
        .toList();
  }

  /// Check if the workflow is complete
  bool isComplete(Set<String> completedSteps) {
    return steps.every((s) => completedSteps.contains(s.name));
  }
}

/// ============================================================
/// WORKFLOW STATE (RUNTIME TRACKING)
/// ============================================================
///
/// Tracks the runtime state of an active workflow instance.
/// Used by future workflow engine to manage execution.
/// ============================================================
class WorkflowState {
  /// Workflow definition this state corresponds to
  final WorkflowDefinition definition;

  /// Set of completed step names
  final Set<String> completedSteps;

  /// Map of step name → status
  final Map<String, WorkflowStepStatus> stepStatus;

  /// Map of step name → result payload
  final Map<String, Map<String, dynamic>> stepResults;

  /// Whether the overall workflow is complete
  final bool isComplete;

  /// When the workflow started
  final DateTime startedAt;

  /// When the workflow completed (if applicable)
  final DateTime? completedAt;

  const WorkflowState({
    required this.definition,
    this.completedSteps = const {},
    this.stepStatus = const {},
    this.stepResults = const {},
    this.isComplete = false,
    required this.startedAt,
    this.completedAt,
  });

  /// Create initial state for a workflow
  factory WorkflowState.initial(WorkflowDefinition definition) =>
      WorkflowState(
        definition: definition,
        startedAt: DateTime.now(),
      );

  /// Create a copy with updated step status
  WorkflowState withStepCompleted(
    String stepName, {
    Map<String, dynamic> result = const {},
  }) {
    final updatedSteps = Set<String>.from(completedSteps)..add(stepName);
    final updatedStatus =
        Map<String, WorkflowStepStatus>.from(stepStatus)
          ..[stepName] = WorkflowStepStatus.completed;
    final updatedResults =
        Map<String, Map<String, dynamic>>.from(stepResults)
          ..[stepName] = result;

    return WorkflowState(
      definition: definition,
      completedSteps: updatedSteps,
      stepStatus: updatedStatus,
      stepResults: updatedResults,
      isComplete: definition.isComplete(updatedSteps),
      startedAt: startedAt,
      completedAt: definition.isComplete(updatedSteps)
          ? DateTime.now()
          : completedAt,
    );
  }

  /// Create a copy with failed step
  WorkflowState withStepFailed(
    String stepName, {
    String? error,
  }) {
    final updatedStatus =
        Map<String, WorkflowStepStatus>.from(stepStatus)
          ..[stepName] = WorkflowStepStatus.failed;
    final updatedResults =
        Map<String, Map<String, dynamic>>.from(stepResults)
          ..[stepName] = error != null ? {'error': error} : {};

    return WorkflowState(
      definition: definition,
      completedSteps: completedSteps,
      stepStatus: updatedStatus,
      stepResults: updatedResults,
      isComplete: false,
      startedAt: startedAt,
      completedAt: completedAt,
    );
  }

  /// Get available steps (dependencies resolved)
  List<WorkflowStep> get availableSteps =>
      definition.availableSteps(completedSteps);

  /// Whether a specific step can run now
  bool canRunStep(String stepName) {
    final step = definition.step(stepName);
    if (step == null) return false;
    if (completedSteps.contains(stepName)) return false;
    return step.areDependenciesMet(completedSteps);
  }
}
