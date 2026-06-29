/// ============================================================
/// ACTIVITY TEMPLATE PROVIDER
/// ============================================================
///
/// Provides activity templates sourced from Supabase activity_templates
/// table with preset fallback for offline/development use.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/models/activity_template.dart';
import 'package:famhub_app/features/farm_management/application/providers/activity_template_loader.dart';
import 'package:famhub_app/features/farm_management/config/workflow_templates.dart';

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

    return templates.isNotEmpty ? templates : PresetWorkflowTemplates.templates;
  } catch (e) {
    return PresetWorkflowTemplates.templates;
  }
});

/// Provider for a specific template.
final activityTemplateProvider = Provider.family<ActivityTemplate?, String>((ref, id) {
  final asyncTemplates = ref.watch(activityTemplatesProvider);
  return asyncTemplates.when(
    data: (templates) => templates[id],
    loading: () => PresetWorkflowTemplates.get(id),
    error: (_, __) => PresetWorkflowTemplates.get(id),
  );
});

