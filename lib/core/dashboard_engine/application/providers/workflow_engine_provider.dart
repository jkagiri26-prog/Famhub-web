// ignore: dangling_library_doc_comments
/// ============================================================
/// WORKFLOW ENGINE PROVIDER — PHASE 3
/// ============================================================
///
/// PURPOSE:
/// Wires the WorkflowEngine into the Riverpod provider graph
/// and pre-registers operational workflow definitions.
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/application/providers/ = provider wiring
///
/// ✅ PROVIDERS:
///   - workflowEngineProvider — singleton WorkflowEngine instance
///   - workflowStateProvider — reactive state for a workflow
///   - activeWorkflowsProvider — list of active workflow names
/// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/events/workflow_events.dart';
import 'package:famhub_app/core/dashboard_engine/application/workflow/workflow_engine.dart';

/// Singleton WorkflowEngine with pre-registered operational workflows
final workflowEngineProvider = Provider<WorkflowEngine>((ref) {
  final engine = WorkflowEngine();

  // Pre-register operational workflows
  engine.register(
    OperationalWorkflows.modulePublish,
    metadata: const WorkflowMetadata(
      priority: WorkflowPriority.normal,
      maxRetries: 2,
      notifyOnCompletion: true,
      ownerModule: 'marketplace',
      dependentModuleKeys: ['module_registry', 'build_service'],
    ),
  );

  engine.register(
    OperationalWorkflows.degradationRecovery,
    metadata: const WorkflowMetadata(
      priority: WorkflowPriority.high,
      maxRetries: 3,
      retryDelay: Duration(seconds: 10),
      notifyOnFailure: true,
      ownerModule: 'system',
      estimatedDuration: Duration(minutes: 2),
    ),
  );

  engine.register(
    OperationalWorkflows.configRollout,
    metadata: const WorkflowMetadata(
      priority: WorkflowPriority.normal,
      maxRetries: 1,
      notifyOnCompletion: true,
      ownerModule: 'config_service',
    ),
  );

  engine.register(
    OperationalWorkflows.maintenanceWindow,
    metadata: const WorkflowMetadata(
      priority: WorkflowPriority.low,
      notifyOnCompletion: true,
      notifyOnFailure: true,
      ownerModule: 'system',
      estimatedDuration: Duration(minutes: 15),
    ),
  );

  ref.onDispose(() {
    engine.resetAll();
  });

  return engine;
});

/// Reactive provider for a specific workflow's current state
final workflowStateProvider = Provider.family<WorkflowState?, String>((ref, workflowName) {
  final engine = ref.read(workflowEngineProvider);
  return engine.state(workflowName);
});

/// List of currently active workflow names
final activeWorkflowsProvider = Provider<List<String>>((ref) {
  final engine = ref.read(workflowEngineProvider);
  return engine.activeWorkflows;
});

/// Registered workflow names
final registeredWorkflowsProvider = Provider<List<String>>((ref) {
  final engine = ref.read(workflowEngineProvider);
  return engine.registeredWorkflows;
});

/// Whether a specific workflow is active
final isWorkflowActiveProvider = Provider.family<bool, String>((ref, workflowName) {
  final engine = ref.read(workflowEngineProvider);
  return engine.isActive(workflowName);
});
