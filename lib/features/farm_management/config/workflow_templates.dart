/// ============================================================
/// PRESET WORKFLOW TEMPLATES
/// ============================================================
///
/// Provides fallback templates when the database is unavailable.
/// These are static presets — NOT the source of truth.
/// The database (activity_templates table) is canonical.
/// ============================================================
library;

import 'package:famhub_app/features/farm_management/domain/models/activity_template.dart';
import 'package:famhub_app/features/farm_management/domain/models/template_attribute.dart';
import 'package:famhub_app/features/farm_management/domain/models/workflow_stage.dart';
import 'package:famhub_app/features/farm_management/domain/enums/attribute_type.dart';

/// Static fallback templates for offline/development use.
class PresetWorkflowTemplates {
  PresetWorkflowTemplates._();

  static const Map<String, ActivityTemplate> templates = {
    'maize_planting': ActivityTemplate(
      id: 'maize_planting',
      name: 'Maize Planting',
      description: 'Record maize planting activity with field and seed details',
      category: 'crops',
      icon: 'eco',
      attributes: [
        TemplateAttribute(
          id: 'field_id',
          name: 'field',
          label: 'Field',
          type: AttributeType.select,
          isRequired: true,
          sortOrder: 1,
        ),
        TemplateAttribute(
          id: 'seed_variety',
          name: 'seed_variety',
          label: 'Seed Variety',
          type: AttributeType.text,
          isRequired: true,
          sortOrder: 2,
        ),
        TemplateAttribute(
          id: 'seed_quantity',
          name: 'seed_quantity',
          label: 'Seed Quantity (kg)',
          type: AttributeType.number,
          isRequired: true,
          sortOrder: 3,
        ),
        TemplateAttribute(
          id: 'planting_date',
          name: 'planting_date',
          label: 'Planting Date',
          type: AttributeType.date,
          isRequired: true,
          sortOrder: 4,
        ),
        TemplateAttribute(
          id: 'notes',
          name: 'notes',
          label: 'Notes',
          type: AttributeType.textArea,
          isRequired: false,
          sortOrder: 5,
        ),
      ],
      stages: [
        WorkflowStage(id: 'field_selection', name: 'Field Selection', order: 1, requiredAttributes: ['field_id']),
        WorkflowStage(id: 'seed_details', name: 'Seed Details', order: 2, requiredAttributes: ['seed_variety', 'seed_quantity']),
        WorkflowStage(id: 'planting_info', name: 'Planting Info', order: 3, requiredAttributes: ['planting_date']),
        WorkflowStage(id: 'notes_optional', name: 'Additional Notes', order: 4, isOptional: true),
      ],
    ),
    'dairy_milking': ActivityTemplate(
      id: 'dairy_milking',
      name: 'Dairy Milking',
      description: 'Record milking session with yield and quality details',
      category: 'livestock',
      icon: 'water',
      attributes: [
        TemplateAttribute(
          id: 'animal_id',
          name: 'animal_id',
          label: 'Animal / Herd',
          type: AttributeType.select,
          isRequired: true,
          sortOrder: 1,
        ),
        TemplateAttribute(
          id: 'yield_quantity',
          name: 'yield_quantity',
          label: 'Milk Yield (litres)',
          type: AttributeType.number,
          isRequired: true,
          sortOrder: 2,
        ),
        TemplateAttribute(
          id: 'milking_time',
          name: 'milking_time',
          label: 'Milking Time',
          type: AttributeType.time,
          isRequired: true,
          sortOrder: 3,
        ),
        TemplateAttribute(
          id: 'quality_notes',
          name: 'quality_notes',
          label: 'Quality Notes',
          type: AttributeType.textArea,
          isRequired: false,
          sortOrder: 4,
        ),
      ],
      stages: [
        WorkflowStage(id: 'animal_selection', name: 'Select Animal', order: 1, requiredAttributes: ['animal_id']),
        WorkflowStage(id: 'yield_recording', name: 'Record Yield', order: 2, requiredAttributes: ['yield_quantity']),
        WorkflowStage(id: 'quality_check', name: 'Quality Check', order: 3, isOptional: true),
      ],
    ),
    'poultry_feeding': ActivityTemplate(
      id: 'poultry_feeding',
      name: 'Poultry Feeding',
      description: 'Record poultry feeding activity with feed type and quantity',
      category: 'livestock',
      icon: 'egg',
      attributes: [
        TemplateAttribute(
          id: 'poultry_type',
          name: 'poultry_type',
          label: 'Poultry Type',
          type: AttributeType.select,
          isRequired: true,
          sortOrder: 1,
          options: ['Broilers', 'Layers', 'Kienyeji', 'Ducks'],
        ),
        TemplateAttribute(
          id: 'feed_type',
          name: 'feed_type',
          label: 'Feed Type',
          type: AttributeType.text,
          isRequired: true,
          sortOrder: 2,
        ),
        TemplateAttribute(
          id: 'feed_quantity',
          name: 'feed_quantity',
          label: 'Feed Quantity (kg)',
          type: AttributeType.number,
          isRequired: true,
          sortOrder: 3,
        ),
        TemplateAttribute(
          id: 'feeding_time',
          name: 'feeding_time',
          label: 'Feeding Time',
          type: AttributeType.time,
          isRequired: false,
          sortOrder: 4,
        ),
      ],
      stages: [
        WorkflowStage(id: 'poultry_type', name: 'Poultry Type', order: 1, requiredAttributes: ['poultry_type']),
        WorkflowStage(id: 'feed_details', name: 'Feed Details', order: 2, requiredAttributes: ['feed_type', 'feed_quantity']),
      ],
    ),
    'avocado_irrigation': ActivityTemplate(
      id: 'avocado_irrigation',
      name: 'Avocado Irrigation',
      description: 'Record irrigation session for avocado trees',
      category: 'crops',
      icon: 'water_drop',
      attributes: [
        TemplateAttribute(
          id: 'field_id',
          name: 'field',
          label: 'Field / Orchard',
          type: AttributeType.select,
          isRequired: true,
          sortOrder: 1,
        ),
        TemplateAttribute(
          id: 'irrigation_type',
          name: 'irrigation_type',
          label: 'Irrigation Type',
          type: AttributeType.select,
          isRequired: true,
          sortOrder: 2,
          options: ['Drip', 'Sprinkler', 'Flood', 'Hand Watering'],
        ),
        TemplateAttribute(
          id: 'duration_minutes',
          name: 'duration_minutes',
          label: 'Duration (minutes)',
          type: AttributeType.number,
          isRequired: true,
          sortOrder: 3,
        ),
        TemplateAttribute(
          id: 'water_volume',
          name: 'water_volume',
          label: 'Water Volume (litres)',
          type: AttributeType.number,
          isRequired: false,
          sortOrder: 4,
        ),
        TemplateAttribute(
          id: 'notes',
          name: 'notes',
          label: 'Notes',
          type: AttributeType.textArea,
          isRequired: false,
          sortOrder: 5,
        ),
      ],
      stages: [
        WorkflowStage(id: 'field_selection', name: 'Select Orchard', order: 1, requiredAttributes: ['field_id']),
        WorkflowStage(id: 'irrigation_details', name: 'Irrigation Details', order: 2, requiredAttributes: ['irrigation_type', 'duration_minutes']),
      ],
    ),
    'fish_feeding': ActivityTemplate(
      id: 'fish_feeding',
      name: 'Fish Feeding',
      description: 'Record fish feeding activity with feed type and quantity',
      category: 'livestock',
      icon: 'set_meal',
      attributes: [
        TemplateAttribute(
          id: 'pond_id',
          name: 'pond_id',
          label: 'Pond',
          type: AttributeType.select,
          isRequired: true,
          sortOrder: 1,
        ),
        TemplateAttribute(
          id: 'feed_type',
          name: 'feed_type',
          label: 'Feed Type',
          type: AttributeType.text,
          isRequired: true,
          sortOrder: 2,
        ),
        TemplateAttribute(
          id: 'feed_quantity',
          name: 'feed_quantity',
          label: 'Feed Quantity (kg)',
          type: AttributeType.number,
          isRequired: true,
          sortOrder: 3,
        ),
        TemplateAttribute(
          id: 'water_temp',
          name: 'water_temp',
          label: 'Water Temperature (°C)',
          type: AttributeType.number,
          isRequired: false,
          sortOrder: 4,
        ),
      ],
      stages: [
        WorkflowStage(id: 'pond_selection', name: 'Select Pond', order: 1, requiredAttributes: ['pond_id']),
        WorkflowStage(id: 'feeding', name: 'Feeding Details', order: 2, requiredAttributes: ['feed_type', 'feed_quantity']),
      ],
    ),
  };

  /// Get a specific template by ID.
  static ActivityTemplate? get(String id) => templates[id];

  /// Get templates by category.
  static List<ActivityTemplate> getByCategory(String category) =>
      templates.values.where((t) => t.category == category).toList();
}
