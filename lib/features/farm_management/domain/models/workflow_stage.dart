/// ============================================================
/// WORKFLOW STAGE MODEL
/// ============================================================
///
/// Represents a stage in an activity workflow (from activity_workflow table).
/// ============================================================
library;

/// A stage in a workflow.
class WorkflowStage {
  final String id;
  final String name;
  final String? description;
  final int order;
  final List<String> requiredAttributes;
  final bool isOptional;

  const WorkflowStage({
    required this.id,
    required this.name,
    this.description,
    required this.order,
    this.requiredAttributes = const [],
    this.isOptional = false,
  });
}

