/// ============================================================
/// DYNAMIC ACTIVITY WORKFLOW SERVICE — Abstract contract
/// ============================================================
///
/// 🎯 PURPOSE:
///   Extract all business logic from DynamicActivityExecutionPage
///   into a testable service. The page becomes a thin UI controller
///   that only renders the workflow UI, collects form values,
///   validates the form, calls this service, and shows results.
///
/// ✅ Responsibilities:
///   - Activity creation
///   - Notes generation
///   - Stock mutation logic
///   - Financial recording
///   - KPI updates
///   - Business validation
///   - Event emission
///   - Rollback preparation
///   - Activity ID propagation
///
/// ❌ Does NOT:
///   - Render UI
///   - Own form state
///   - Navigate
///   - Show SnackBars
/// ============================================================
library;

import 'package:famhub_app/features/farm_management/domain/models/activity_template.dart';

/// ============================================================
/// WORKFLOW RESULT
/// ============================================================
///
/// Encapsulates the outcome of workflow execution.
/// Contains the created activity ID and any warnings.
/// ============================================================
class WorkflowExecutionResult {
  final String activityId;
  final List<String> warnings;

  const WorkflowExecutionResult({
    required this.activityId,
    this.warnings = const [],
  });
}

/// ============================================================
/// DYNAMIC ACTIVITY WORKFLOW SERVICE
/// ============================================================
///
/// Abstract contract for executing dynamic activity workflows.
/// The implementation handles all business workflows:
///   activity creation, stock mutations, financial recording,
///   KPI automation, event emission, and rollback preparation.
/// ============================================================
abstract class DynamicActivityWorkflowService {
  /// Execute a complete workflow for the given template and form values.
  ///
  /// [farmId] — The farm context ID
  /// [template] — The activity template being executed
  /// [formValues] — Collected form field values
  /// [activityId] — Optional pre-generated activity ID for propagation
  ///
  /// Returns a [WorkflowExecutionResult] on success.
  /// Throws on failure (caller handles UI error display).
  Future<WorkflowExecutionResult> executeWorkflow({
    required String farmId,
    required ActivityTemplate template,
    required Map<String, dynamic> formValues,
    String? activityId,
  });

  /// Validate form values against template constraints.
  /// Returns null if valid, or an error message if invalid.
  String? validateFormValues(
    ActivityTemplate template,
    Map<String, dynamic> formValues,
  );
}
