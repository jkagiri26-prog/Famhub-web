/// ============================================================
/// WORKFLOW PROGRESS ENGINE
/// ============================================================
///
/// Manages multi-stage workflow execution progress.
/// Tracks completed stages, validates dependencies, and
/// provides progress metrics.
/// ============================================================
library;

import 'package:famhub_app/features/farm_management/domain/models/workflow_stage.dart';
import 'package:famhub_app/features/farm_management/domain/models/workflow_execution_state.dart';

/// Manages multi-stage workflow execution progress.
class WorkflowProgressEngine {
  WorkflowExecutionState _state;

  WorkflowProgressEngine({
    required String templateId,
    required String templateName,
    required List<WorkflowStage> stages,
  }) : _state = WorkflowExecutionState(
          templateId: templateId,
          templateName: templateName,
          currentStageIndex: 0,
          stages: stages,
          startedAt: DateTime.now(),
        );

  WorkflowExecutionState get state => _state;

  /// Advance to the next stage in the workflow.
  bool advanceStage(Map<String, dynamic> collectedValues) {
    if (_state.isComplete) return false;
    if (_state.currentStageIndex >= _state.stages.length - 1) {
      _state = _state.copyWith(
        isComplete: true,
        completedAt: DateTime.now(),
        collectedValues: {..._state.collectedValues, ...collectedValues},
      );
      return true;
    }
    _state = _state.copyWith(
      currentStageIndex: _state.currentStageIndex + 1,
      collectedValues: {..._state.collectedValues, ...collectedValues},
    );
    return true;
  }

  /// Go back to the previous stage.
  bool previousStage() {
    if (_state.currentStageIndex <= 0) return false;
    _state = _state.copyWith(currentStageIndex: _state.currentStageIndex - 1);
    return true;
  }

  /// Check if all required attributes for current stage are filled.
  bool areStageRequirementsMet(Map<String, dynamic> values) {
    final stage = _state.currentStage;
    if (stage == null) return true;

    // Verify all required attributes for this stage have values
    for (final attrId in stage.requiredAttributes) {
      if (!values.containsKey(attrId) || values[attrId] == null) {
        return false;
      }
      final value = values[attrId];
      if (value is String && value.trim().isEmpty) {
        return false;
      }
    }

    return true;
  }

  /// Reset the workflow to initial state.
  void reset() {
    _state = WorkflowExecutionState(
      templateId: _state.templateId,
      templateName: _state.templateName,
      currentStageIndex: 0,
      stages: _state.stages,
      startedAt: DateTime.now(),
    );
  }
}

