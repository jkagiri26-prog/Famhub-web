/// ============================================================
/// ACTIVITY TEMPLATE MODEL
/// ============================================================
///
/// Represents a template from the activity_templates table.
/// ============================================================
library;

import 'package:famhub_app/features/farm_management/domain/models/template_attribute.dart';
import 'package:famhub_app/features/farm_management/domain/models/workflow_stage.dart';

/// A template defining an agricultural activity with its attributes and stages.
class ActivityTemplate {
  final String id;
  final String name;
  final String? description;
  final String? category;
  final String? icon;
  final List<TemplateAttribute> attributes;
  final List<WorkflowStage> stages;
  final bool isActive;

  const ActivityTemplate({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.icon,
    this.attributes = const [],
    this.stages = const [],
    this.isActive = true,
  });
}

