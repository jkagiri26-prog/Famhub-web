/// ============================================================
/// ACTIVITY TEMPLATE LOADER
/// ============================================================
///
/// Loads activity templates from the Supabase database tables:
///   - activity_templates: template definitions
///   - activity_attribute_rules: attribute/field rules per activity type
///   - activity_workflow: multi-stage workflow definitions
///
/// Falls back to PresetWorkflowTemplates if database is unavailable.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../workflows/dynamic_activity_engine.dart';
import 'package:famhub_app/features/farm_management/domain/models/template_attribute.dart';
import 'package:famhub_app/features/farm_management/domain/models/workflow_stage.dart';
import 'package:famhub_app/features/farm_management/domain/enums/attribute_type.dart';

/// Loads activity templates from Supabase with fallback to presets.
class ActivityTemplateLoader {
  final SupabaseClient _client;

  ActivityTemplateLoader({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Load all activity types from the activity_types table.
  Future<List<Map<String, dynamic>>> loadActivityTypes() async {
    try {
      final response = await _client
          .schema('farm_management').from('activity_types')
          .select('id, name, category, description')
          .eq('is_active', true)
          .order('name');
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      // Fallback to known types
      return [
        {'id': 'maize_planting', 'name': 'Maize Planting', 'category': 'crops'},
        {'id': 'dairy_milking', 'name': 'Dairy Milking', 'category': 'livestock'},
        {'id': 'poultry_feeding', 'name': 'Poultry Feeding', 'category': 'livestock'},
        {'id': 'avocado_irrigation', 'name': 'Avocado Irrigation', 'category': 'crops'},
        {'id': 'fish_feeding', 'name': 'Fish Feeding', 'category': 'livestock'},
      ];
    }
  }

  /// Load attribute rules for a given activity type.
  Future<List<TemplateAttribute>> loadAttributesForType({
    required String activityTypeId,
  }) async {
    try {
      final response = await _client
          .schema('farm_management').from('activity_attribute_rules')
          .select('''
            id,
            attribute_id,
            is_required,
            attribute:attribute_id(name, type, label)
          ''')
          .eq('activity_type_id', activityTypeId);

      final rows = (response as List).cast<Map<String, dynamic>>();
      return rows.map((row) {
        final attr = row['attribute'] as Map<String, dynamic>? ?? {};
        return TemplateAttribute(
          id: row['attribute_id'] as String,
          name: attr['name'] as String? ?? row['attribute_id'] as String,
          label: attr['label'] as String? ?? 'Unknown',
          type: _parseAttributeType(attr['type'] as String?),
          isRequired: row['is_required'] as bool? ?? true,
          sortOrder: rows.indexOf(row),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Load workflow stages from activity_workflow table.
  Future<List<WorkflowStage>> loadStagesForType({
    required String activityTypeId,
  }) async {
    try {
      final response = await _client
          .schema('farm_management').from('activity_workflow')
          .select('id, stage_order, is_required')
          .eq('activity_type_id', activityTypeId)
          .order('stage_order');

      final rows = (response as List).cast<Map<String, dynamic>>();
      return rows.asMap().entries.map((entry) {
        final row = entry.value;
        return WorkflowStage(
          id: row['id'] as String,
          name: 'Stage ${row['stage_order'] ?? entry.key + 1}',
          description: null,
          order: (row['stage_order'] as num?)?.toInt() ?? entry.key,
          isOptional: !(row['is_required'] as bool? ?? true),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  AttributeType _parseAttributeType(String? type) {
    switch (type?.toLowerCase()) {
      case 'text':
        return AttributeType.text;
      case 'number':
        return AttributeType.number;
      case 'boolean':
        return AttributeType.boolean;
      case 'date':
        return AttributeType.date;
      case 'time':
        return AttributeType.time;
      case 'select':
        return AttributeType.select;
      case 'multiselect':
        return AttributeType.multiSelect;
      case 'textarea':
        return AttributeType.textArea;
      case 'location':
        return AttributeType.location;
      default:
        return AttributeType.text;
    }
  }
}

/// Provider for the template loader
final activityTemplateLoaderProvider = Provider<ActivityTemplateLoader>((ref) {
  return ActivityTemplateLoader();
});

