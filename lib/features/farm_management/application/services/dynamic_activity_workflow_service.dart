/// ============================================================
/// DYNAMIC ACTIVITY WORKFLOW SERVICE — Abstract contract
/// ============================================================
///
/// 🎯 PURPOSE:
///   Extract all business logic from DynamicActivityExecutionPage
///   into a testable service. The page becomes a thin UI controller.
///
/// ✅ Responsibilities:
///   - Activity creation (delegates to backend for ID generation)
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
/// Contains the backend-generated activity ID and any warnings.
/// The activity ID is null if execution fails before creation.
/// ============================================================
class WorkflowExecutionResult {
  /// Backend-generated activity ID (null if execution failed)
  final String? activityId;

  /// Non-blocking warnings (e.g., marketplace sync failure)
  final List<String> warnings;

  /// Error message if validation or backend call failed
  final String? errorMessage;

  const WorkflowExecutionResult({
    this.activityId,
    this.warnings = const [],
    this.errorMessage,
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
///
/// ⚠️ The frontend does NOT generate activity IDs.
///    Activity creation delegates to the backend, which returns
///    the generated ID in the [WorkflowExecutionResult].
/// ============================================================
abstract class DynamicActivityWorkflowService {
  /// Execute a complete workflow for the given template and form values.
  ///
  /// All created activities MUST be linked to a valid Farm → Field → Crop/Livestock path.
  /// The caller must ensure [fieldId], [cropOrLivestockId], and [cropOrLivestockType]
  /// are provided before invoking this method.
  ///
  /// [farmId] — The farm context ID
  /// [fieldId] — The field context ID (required)
  /// [cropOrLivestockId] — The crop or livestock entity ID (required)
  /// [cropOrLivestockType] — The type, either 'crop' or 'livestock' (required)
  /// [template] — The activity template being executed
  /// [formValues] — Collected form field values
  /// [activityId] — Optional pre-generated activity ID for propagation
  ///
  /// Returns a [WorkflowExecutionResult] on success.
  /// Throws on failure (caller handles UI error display).
  Future<WorkflowExecutionResult> executeWorkflow({
    required String farmId,
    required String fieldId,
    required String cropOrLivestockId,
    required String cropOrLivestockType,
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
