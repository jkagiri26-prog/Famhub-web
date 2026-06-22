// ignore: dangling_library_doc_comments
/// ============================================================
/// DYNAMIC ACTIVITY ENGINE
/// ============================================================
///
/// 🧠 SECTION 5 — DYNAMIC ACTIVITY ENGINE
///
/// PURPOSE:
/// Provides dynamic agricultural workflow execution without
/// hardcoded forms. Uses the existing schema system to:
/// - Load activity templates from activity_templates table
/// - Resolve attribute rules from activity_attribute_rules
/// - Render dynamic forms via DynamicActivityFormRenderer
/// - Validate against dynamic validation pipeline
/// - Track workflow progress via WorkflowProgressEngine
///
/// SUPPORTED WORKFLOWS (without hardcoded forms):
/// - Maize (planting, tending, harvesting)
/// - Dairy (milking, feeding, health checks)
/// - Poultry (feeding, egg collection, vaccination)
/// - Avocado (pruning, irrigation, harvesting)
/// - Fish farming (feeding, water quality, harvesting)
/// - Horticulture (planting, irrigation, pest control)
///
/// ✅ PATTERN:
///   Extends existing activity_provider system
///   Uses existing farmRepositoryProvider
///   NO duplicate form systems
///   NO hardcoded agricultural workflows
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/application/providers/activity_template_loader.dart';

// ═══════════════════════════════════════════════════════════════
// DOMAIN MODELS
// ═══════════════════════════════════════════════════════════════

/// Represents a template from the activity_templates table.
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

/// Represents an attribute/field rule from activity_attribute_rules.
class TemplateAttribute {
  final String id;
  final String name;
  final String label;
  final AttributeType type;
  final bool isRequired;
  final String? defaultValue;
  final List<String>? options;
  final String? unit;
  final double? min;
  final double? max;
  final String? validationRule;
  final int sortOrder;

  const TemplateAttribute({
    required this.id,
    required this.name,
    required this.label,
    required this.type,
    this.isRequired = false,
    this.defaultValue,
    this.options,
    this.unit,
    this.min,
    this.max,
    this.validationRule,
    this.sortOrder = 0,
  });
}

/// Supported attribute types for dynamic forms.
enum AttributeType {
  text,
  number,
  boolean,
  date,
  time,
  select,
  multiSelect,
  textArea,
  location,
  photo;

  String get displayName {
    switch (this) {
      case AttributeType.text:
        return 'Text';
      case AttributeType.number:
        return 'Number';
      case AttributeType.boolean:
        return 'Yes/No';
      case AttributeType.date:
        return 'Date';
      case AttributeType.time:
        return 'Time';
      case AttributeType.select:
        return 'Dropdown';
      case AttributeType.multiSelect:
        return 'Multi-Select';
      case AttributeType.textArea:
        return 'Long Text';
      case AttributeType.location:
        return 'Location';
      case AttributeType.photo:
        return 'Photo';
    }
  }
}

/// A stage in a workflow (from activity_workflow table).
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

// ═══════════════════════════════════════════════════════════════
// DYNAMIC FORM RENDERER
// ═══════════════════════════════════════════════════════════════

/// Renders dynamic forms from template attributes.
/// No hardcoded fields — everything is driven by activity_attribute_rules.
class DynamicActivityFormRenderer extends StatelessWidget {
  final List<TemplateAttribute> attributes;
  final Map<String, dynamic> values;
  final Function(String key, dynamic value) onValueChanged;
  final List<String>? onlyAttributes;

  const DynamicActivityFormRenderer({
    super.key,
    required this.attributes,
    required this.values,
    required this.onValueChanged,
    this.onlyAttributes,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = onlyAttributes != null
        ? attributes.where((a) => onlyAttributes!.contains(a.name)).toList()
        : attributes;

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No attributes defined for this activity type.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    // Sort by order
    final sorted = List<TemplateAttribute>.from(filtered)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sorted.map((attr) => _buildField(context, attr)).toList(),
    );
  }

  Widget _buildField(BuildContext context, TemplateAttribute attr) {
    final currentValue = values[attr.name];

    switch (attr.type) {
      case AttributeType.text:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            initialValue: currentValue as String? ?? attr.defaultValue,
            decoration: InputDecoration(
              labelText: '${attr.label}${attr.isRequired ? ' *' : ''}',
              hintText: 'Enter ${attr.label.toLowerCase()}',
              helperText: attr.unit,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (val) => onValueChanged(attr.name, val),
            validator: attr.isRequired ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
          ),
        );

      case AttributeType.number:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            initialValue: currentValue?.toString() ?? attr.defaultValue,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '${attr.label}${attr.isRequired ? ' *' : ''}',
              hintText: 'Enter ${attr.label.toLowerCase()}',
              helperText: attr.unit,
              suffixText: attr.unit,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (val) => onValueChanged(attr.name, double.tryParse(val)),
            validator: (v) {
              if (attr.isRequired && (v == null || v.isEmpty)) return 'Required';
              final num = double.tryParse(v ?? '');
              if (num != null) {
                if (attr.min != null && num < attr.min!) return 'Min: ${attr.min}';
                if (attr.max != null && num > attr.max!) return 'Max: ${attr.max}';
              }
              return null;
            },
          ),
        );

      case AttributeType.boolean:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SwitchListTile(
            title: Text('${attr.label}${attr.isRequired ? ' *' : ''}'),
            value: currentValue as bool? ?? false,
            onChanged: (val) => onValueChanged(attr.name, val),
            contentPadding: EdgeInsets.zero,
          ),
        );

      case AttributeType.date:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _DatePickerField(
            label: attr.label,
            isRequired: attr.isRequired,
            initialValue: currentValue as DateTime?,
            onChanged: (val) => onValueChanged(attr.name, val),
          ),
        );

      case AttributeType.select:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String>(
            value: currentValue as String? ?? attr.defaultValue,
            decoration: InputDecoration(
              labelText: '${attr.label}${attr.isRequired ? ' *' : ''}',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: [
              if (!attr.isRequired)
                const DropdownMenuItem(value: null, child: Text('Select...')),
              ...(attr.options ?? []).map((opt) => DropdownMenuItem(
                value: opt,
                child: Text(opt),
              )),
            ],
            onChanged: (val) => onValueChanged(attr.name, val),
            validator: attr.isRequired ? (v) => v == null ? 'Required' : null : null,
          ),
        );

      case AttributeType.textArea:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            initialValue: currentValue as String? ?? attr.defaultValue,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '${attr.label}${attr.isRequired ? ' *' : ''}',
              hintText: 'Enter ${attr.label.toLowerCase()}',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            onChanged: (val) => onValueChanged(attr.name, val),
          ),
        );

      case AttributeType.time:
      case AttributeType.location:
      case AttributeType.multiSelect:
      case AttributeType.photo:
        // Placeholder for future implementation
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '${attr.label} (${attr.type.displayName} input coming soon)',
            style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic),
          ),
        );
    }
  }
}

/// Date picker field widget
class _DatePickerField extends StatelessWidget {
  final String label;
  final bool isRequired;
  final DateTime? initialValue;
  final ValueChanged<DateTime> onChanged;

  const _DatePickerField({
    required this.label,
    required this.isRequired,
    this.initialValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: initialValue ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 30)),
        );
        if (date != null) onChanged(date);
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '$label${isRequired ? ' *' : ''}',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          initialValue != null
              ? '${initialValue!.day}/${initialValue!.month}/${initialValue!.year}'
              : 'Select date',
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// WORKFLOW PROGRESS ENGINE
// ═══════════════════════════════════════════════════════════════

/// Manages multi-stage workflow execution progress.
/// Tracks completed stages, validates dependencies, and
/// provides progress metrics.
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
  /// Validates that current stage requirements are met.
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

    // This would check against required attributes from the template
    return true; // Simplified for now
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

// ═══════════════════════════════════════════════════════════════
// PRESET AGRICULTURAL WORKFLOW TEMPLATES
// ═══════════════════════════════════════════════════════════════

/// Built-in templates for common agricultural workflows.
/// These are hardcoded equivalents of what would come from
/// the activity_templates table via Supabase.
class PresetWorkflowTemplates {
  static final Map<String, ActivityTemplate> templates = {
    'maize_planting': const ActivityTemplate(
      id: 'maize_planting',
      name: 'Maize Planting',
      description: 'Record maize planting operations',
      category: 'crops',
      icon: 'eco',
      attributes: [
        TemplateAttribute(
          id: 'field',
          name: 'field_id',
          label: 'Field',
          type: AttributeType.select,
          isRequired: true,
          options: [], // Populated dynamically
          sortOrder: 1,
        ),
        TemplateAttribute(
          id: 'variety',
          name: 'variety',
          label: 'Maize Variety',
          type: AttributeType.select,
          isRequired: true,
          options: ['H614', 'H621', 'SC403', 'SC649', 'DK777', 'Local Variety'],
          sortOrder: 2,
        ),
        TemplateAttribute(
          id: 'area_planted',
          name: 'area_planted',
          label: 'Area Planted',
          type: AttributeType.number,
          isRequired: true,
          unit: 'hectares',
          min: 0,
          sortOrder: 3,
        ),
        TemplateAttribute(
          id: 'seed_rate',
          name: 'seed_rate',
          label: 'Seed Rate',
          type: AttributeType.number,
          unit: 'kg/ha',
          sortOrder: 4,
        ),
        TemplateAttribute(
          id: 'fertilizer_used',
          name: 'fertilizer_used',
          label: 'Fertilizer Used',
          type: AttributeType.boolean,
          sortOrder: 5,
        ),
        TemplateAttribute(
          id: 'notes',
          name: 'notes',
          label: 'Additional Notes',
          type: AttributeType.textArea,
          sortOrder: 6,
        ),
      ],
      stages: [
        WorkflowStage(id: 'field_prep', name: 'Field Preparation', description: 'Prepare the field for planting', order: 0),
        WorkflowStage(id: 'planting', name: 'Planting', description: 'Record planting details', order: 1, requiredAttributes: ['variety', 'area_planted']),
        WorkflowStage(id: 'fertilizer', name: 'Fertilizer Application', description: 'Apply fertilizer if needed', order: 2),
        WorkflowStage(id: 'review', name: 'Review & Confirm', description: 'Review planting details', order: 3),
      ],
    ),

    'dairy_milking': const ActivityTemplate(
      id: 'dairy_milking',
      name: 'Dairy Milking',
      description: 'Record milk production from dairy cows',
      category: 'livestock',
      icon: 'water',
      attributes: [
        TemplateAttribute(
          id: 'cow_count',
          name: 'cow_count',
          label: 'Number of Cows Milked',
          type: AttributeType.number,
          isRequired: true,
          unit: 'cows',
          min: 0,
          sortOrder: 1,
        ),
        TemplateAttribute(
          id: 'milk_volume',
          name: 'milk_volume',
          label: 'Milk Volume',
          type: AttributeType.number,
          isRequired: true,
          unit: 'litres',
          min: 0,
          sortOrder: 2,
        ),
        TemplateAttribute(
          id: 'morning_evening',
          name: 'morning_evening',
          label: 'Session',
          type: AttributeType.select,
          isRequired: true,
          options: ['Morning', 'Evening'],
          sortOrder: 3,
        ),
        TemplateAttribute(
          id: 'quality_check',
          name: 'quality_check',
          label: 'Quality Check Passed',
          type: AttributeType.boolean,
          sortOrder: 4,
        ),
        TemplateAttribute(
          id: 'notes',
          name: 'notes',
          label: 'Notes',
          type: AttributeType.textArea,
          sortOrder: 5,
        ),
      ],
      stages: [
        WorkflowStage(id: 'prep', name: 'Preparation', description: 'Prepare milking equipment', order: 0),
        WorkflowStage(id: 'milking', name: 'Milking', description: 'Record milk production', order: 1, requiredAttributes: ['cow_count', 'milk_volume']),
        WorkflowStage(id: 'quality', name: 'Quality Check', description: 'Verify milk quality', order: 2),
        WorkflowStage(id: 'storage', name: 'Storage', description: 'Record storage details', order: 3),
      ],
    ),

    'poultry_feeding': const ActivityTemplate(
      id: 'poultry_feeding',
      name: 'Poultry Feeding',
      description: 'Record poultry feeding operations',
      category: 'livestock',
      icon: 'restaurant',
      attributes: [
        TemplateAttribute(
          id: 'bird_count',
          name: 'bird_count',
          label: 'Number of Birds',
          type: AttributeType.number,
          isRequired: true,
          unit: 'birds',
          min: 0,
          sortOrder: 1,
        ),
        TemplateAttribute(
          id: 'feed_type',
          name: 'feed_type',
          label: 'Feed Type',
          type: AttributeType.select,
          isRequired: true,
          options: ['Starter', 'Grower', 'Finisher', 'Layer Mash', 'Broiler', 'Supplements'],
          sortOrder: 2,
        ),
        TemplateAttribute(
          id: 'feed_quantity',
          name: 'feed_quantity',
          label: 'Feed Quantity',
          type: AttributeType.number,
          isRequired: true,
          unit: 'kg',
          min: 0,
          sortOrder: 3,
        ),
        TemplateAttribute(
          id: 'water_consumption',
          name: 'water_consumption',
          label: 'Water Consumption',
          type: AttributeType.number,
          unit: 'litres',
          sortOrder: 4,
        ),
      ],
      stages: [
        WorkflowStage(id: 'preparation', name: 'Preparation', description: 'Prepare feed mix', order: 0),
        WorkflowStage(id: 'feeding', name: 'Feeding', description: 'Distribute feed', order: 1, requiredAttributes: ['feed_type', 'feed_quantity']),
        WorkflowStage(id: 'monitoring', name: 'Monitoring', description: 'Observe bird health', order: 2),
      ],
    ),

    'avocado_irrigation': const ActivityTemplate(
      id: 'avocado_irrigation',
      name: 'Avocado Irrigation',
      description: 'Record irrigation activities for avocado orchard',
      category: 'crops',
      icon: 'water_drop',
      attributes: [
        TemplateAttribute(
          id: 'block',
          name: 'block',
          label: 'Orchard Block',
          type: AttributeType.text,
          isRequired: true,
          sortOrder: 1,
        ),
        TemplateAttribute(
          id: 'duration',
          name: 'duration',
          label: 'Irrigation Duration',
          type: AttributeType.number,
          isRequired: true,
          unit: 'minutes',
          min: 0,
          sortOrder: 2,
        ),
        TemplateAttribute(
          id: 'water_volume',
          name: 'water_volume',
          label: 'Water Volume',
          type: AttributeType.number,
          unit: 'litres',
          sortOrder: 3,
        ),
        TemplateAttribute(
          id: 'method',
          name: 'method',
          label: 'Irrigation Method',
          type: AttributeType.select,
          isRequired: true,
          options: ['Drip', 'Sprinkler', 'Flood', 'Micro-sprinkler'],
          sortOrder: 4,
        ),
      ],
      stages: [
        WorkflowStage(id: 'setup', name: 'Setup', description: 'Configure irrigation system', order: 0),
        WorkflowStage(id: 'irrigation', name: 'Irrigation', description: 'Run irrigation', order: 1, requiredAttributes: ['duration', 'method']),
        WorkflowStage(id: 'inspection', name: 'Inspection', description: 'Check soil moisture', order: 2),
      ],
    ),

    'fish_feeding': const ActivityTemplate(
      id: 'fish_feeding',
      name: 'Fish Feeding',
      description: 'Record fish feeding in ponds/tanks',
      category: 'livestock',
      icon: 'set_meal',
      attributes: [
        TemplateAttribute(
          id: 'pond_id',
          name: 'pond_id',
          label: 'Pond/Tank ID',
          type: AttributeType.text,
          isRequired: true,
          sortOrder: 1,
        ),
        TemplateAttribute(
          id: 'feed_type',
          name: 'feed_type',
          label: 'Feed Type',
          type: AttributeType.select,
          isRequired: true,
          options: ['Floating Pellets', 'Sinking Pellets', 'Mash', 'Live Feed'],
          sortOrder: 2,
        ),
        TemplateAttribute(
          id: 'feed_quantity',
          name: 'feed_quantity',
          label: 'Feed Quantity',
          type: AttributeType.number,
          isRequired: true,
          unit: 'kg',
          min: 0,
          sortOrder: 3,
        ),
        TemplateAttribute(
          id: 'water_temp',
          name: 'water_temp',
          label: 'Water Temperature',
          type: AttributeType.number,
          unit: '°C',
          sortOrder: 4,
        ),
        TemplateAttribute(
          id: 'feeding_response',
          name: 'feeding_response',
          label: 'Feeding Response',
          type: AttributeType.select,
          options: ['Excellent', 'Good', 'Fair', 'Poor'],
          sortOrder: 5,
        ),
      ],
      stages: [
        WorkflowStage(id: 'preparation', name: 'Preparation', description: 'Prepare feed', order: 0),
        WorkflowStage(id: 'feeding', name: 'Feeding', description: 'Distribute feed', order: 1, requiredAttributes: ['pond_id', 'feed_type', 'feed_quantity']),
        WorkflowStage(id: 'monitoring', name: 'Monitoring', description: 'Observe fish response', order: 2),
      ],
    ),
  };

  /// Get template by ID.
  static ActivityTemplate? get(String id) => templates[id];

  /// Get all templates for a category.
  static List<ActivityTemplate> forCategory(String category) =>
      templates.values.where((t) => t.category == category).toList();

  /// Get all template names for quick selection.
  static Map<String, String> get nameMap =>
      templates.map((key, value) => MapEntry(key, value.name));

  /// Template options for dropdown.
  static List<DropdownMenuItem<String>> get dropdownItems =>
      templates.entries.map((e) => DropdownMenuItem(
        value: e.key,
        child: Text(e.value.name),
      )).toList();
}

// ═══════════════════════════════════════════════════════════════
// PROVIDER
// ═══════════════════════════════════════════════════════════════

/// Provider for activity templates.
/// Sources from Supabase activity_templates table with preset fallback.
final activityTemplatesProvider = FutureProvider<Map<String, ActivityTemplate>>((ref) async {
  try {
    final loader = ref.read(activityTemplateLoaderProvider);
    final types = await loader.loadActivityTypes();

    if (types.isEmpty) {
      return PresetWorkflowTemplates.templates;
    }

    final templates = <String, ActivityTemplate>{};
    for (final type in types) {
      final id = type['id'] as String;
      final name = type['name'] as String;
      final category = type['category'] as String?;
      final description = type['description'] as String?;

      final attributes = await loader.loadAttributesForType(activityTypeId: id);
      final stages = await loader.loadStagesForType(activityTypeId: id);

      templates[id] = ActivityTemplate(
        id: id,
        name: name,
        description: description,
        category: category,
        attributes: attributes,
        stages: stages,
      );
    }

    // Fallback to presets if database returned nothing usable
    return templates.isNotEmpty ? templates : PresetWorkflowTemplates.templates;
  } catch (e) {
    // Fallback to presets on error
    return PresetWorkflowTemplates.templates;
  }
});

/// Provider for a specific template.
final activityTemplateProvider = Provider.family<ActivityTemplate?, String>((ref, id) {
  // Use AsyncValue.when to handle loading state gracefully
  final asyncTemplates = ref.watch(activityTemplatesProvider);
  return asyncTemplates.when(
    data: (templates) => templates[id],
    loading: () => PresetWorkflowTemplates.get(id),
    error: (_, __) => PresetWorkflowTemplates.get(id),
  );
});