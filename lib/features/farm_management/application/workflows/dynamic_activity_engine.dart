/// ============================================================
/// DYNAMIC ACTIVITY ENGINE
/// ============================================================
///
/// This file has been split into separate layer-specific files:
///
/// ✅ DOMAIN LAYER
///   domain/models/activity_template.dart
///   domain/models/template_attribute.dart
///   domain/models/workflow_stage.dart
///   domain/models/workflow_execution_state.dart
///   domain/enums/attribute_type.dart
///
/// ✅ APPLICATION LAYER
///   application/workflows/workflow_progress_engine.dart
///   application/providers/activity_template_provider.dart
///
/// ✅ PRESENTATION LAYER
///   presentation/widgets/dynamic_activity_form_renderer.dart
///   presentation/widgets/date_picker_field.dart
///
/// ✅ CONFIG LAYER
///   config/workflow_templates.dart
///
/// ⚠️  This file is kept as a migration shim. Import directly
///     from the specific files above instead.
/// ============================================================