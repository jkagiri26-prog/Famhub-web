/// ============================================================
/// WORKFLOW SDK — Public facade for workflow execution
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/sdk/ = developer-facing SDK layer
///
/// ✅ Responsibilities:
///   - Expose workflow operations to feature modules
///   - Delegate to workflowEngineProvider
///   - Never expose WorkflowEngine directly
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Contain persistence logic
///   - Contain UI
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/events/workflow_events.dart';
import 'package:famhub_app/core/dashboard_engine/application/workflow/workflow_engine.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/workflow_engine_provider.dart';
import 'api/sdk_annotations.dart';

/// ============================================================
/// WORKFLOW SDK
/// ============================================================
///
/// Feature modules use this instead of reading providers directly.
///
/// Usage:
///   final wf = ref.read(famhubWorkflowSdkProvider);
///   await wf.execute('module_publish');
///   final status = wf.status('module_publish');
///   await wf.cancel('module_publish');
/// ============================================================
@PublicSdk()
class WorkflowSdk {
  final Ref _ref;

  WorkflowSdk(this._ref);

  WorkflowEngine get _engine => _ref.read(workflowEngineProvider);

  /// Execute/start a workflow by name
  @SdkMethod(version: '1.0.0')
  WorkflowState execute(String workflowName) =>
      _engine.start(workflowName);

  /// Validate whether a workflow is registered
  @SdkMethod(version: '1.0.0')
  bool validate(String workflowName) =>
      _engine.registeredWorkflows.contains(workflowName);

  /// Cancel/stop an active workflow
  @SdkMethod(version: '1.0.0')
  void cancel(String workflowName) => _engine.reset(workflowName);

  /// Resume a workflow (re-starts it)
  @SdkMethod(version: '1.0.0')
  WorkflowState resume(String workflowName) =>
      _engine.start(workflowName);

  /// Get the current state of a workflow
  @SdkMethod(version: '1.0.0')
  WorkflowState? status(String workflowId) =>
      _engine.state(workflowId);

  /// Complete a step in a workflow
  @SdkMethod(version: '1.0.0')
  WorkflowState completeStep(
    String workflowName,
    String stepName, {
    Map<String, dynamic> result = const {},
  }) =>
      _engine.completeStep(workflowName, stepName, result: result);

  /// Fail a step in a workflow
  @SdkMethod(version: '1.0.0')
  WorkflowState failStep(
    String workflowName,
    String stepName, {
    String? error,
  }) =>
      _engine.failStep(workflowName, stepName, error: error);

  /// Check if a workflow is currently active
  @SdkMethod(version: '1.0.0')
  bool isActive(String workflowName) =>
      _engine.isActive(workflowName);

  /// Get all active workflow names
  @SdkMethod(version: '1.0.0')
  List<String> activeWorkflows() => _engine.activeWorkflows;

  /// Get all registered workflow names
  @SdkMethod(version: '1.0.0')
  List<String> registeredWorkflows() => _engine.registeredWorkflows;

  /// Get available steps for an active workflow
  @SdkMethod(version: '1.0.0')
  List<WorkflowStep> availableSteps(String workflowName) =>
      _engine.availableSteps(workflowName);
}

/// ============================================================
/// PROVIDER: WORKFLOW SDK
/// ============================================================
@SdkProvider()
final famhubWorkflowSdkProvider = Provider<WorkflowSdk>((ref) {
  return WorkflowSdk(ref);
});
