/// ============================================================
/// WORKFLOW EXECUTION STATE MODEL
/// ============================================================
///
/// Runtime state of an active workflow execution.
/// ============================================================
library;

import 'package:famhub_app/features/farm_management/domain/models/workflow_stage.dart';

/// Runtime state of an active workflow execution.
class WorkflowExecutionState {
  final String templateId;
  final String templateName;
  final int currentStageIndex;
  final List<WorkflowStage> stages;
  final Map<String, dynamic> collectedValues;
  final bool isComplete;
  final DateTime startedAt;
  final DateTime? completedAt;

  const WorkflowExecutionState({
    required this.templateId,
    required this.templateName,
    required this.currentStageIndex,
    required this.stages,
    this.collectedValues = const {},
    this.isComplete = false,
    required this.startedAt,
    this.completedAt,
  });

  WorkflowStage? get currentStage =>
      currentStageIndex < stages.length ? stages[currentStageIndex] : null;

  double get progress =>
      stages.isEmpty ? 1.0 : (currentStageIndex / stages.length);

  WorkflowExecutionState copyWith({
    int? currentStageIndex,
    Map<String, dynamic>? collectedValues,
    bool? isComplete,
    DateTime? completedAt,
  }) {
    return WorkflowExecutionState(
      templateId: templateId,
      templateName: templateName,
      currentStageIndex: currentStageIndex ?? this.currentStageIndex,
      stages: stages,
      collectedValues: collectedValues ?? this.collectedValues,
      isComplete: isComplete ?? this.isComplete,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

