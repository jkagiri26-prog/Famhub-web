/// ============================================================
/// FARM ACTION NAVIGATION — Hierarchy-Context Navigation Helpers
/// ============================================================
///
/// 🏗️ HIERARCHY RULE:
///   Add Crop / Add Livestock require a Field/Block to be selected.
///   These helpers ensure the required context exists BEFORE opening a
///   creation page — never expose a form without its required context.
///
///   Farm Level:   Add Field
///   Field Level:  Add Crop, Add Livestock
///
/// Single source of truth = hierarchyProvider. No farmSelector state.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';

/// Ensure a Field/Block is selected in the hierarchy, then open a
/// field-scoped page (Add Crop / Add Livestock).
///
/// - A field is already selected → navigate immediately.
/// - Otherwise auto-select the farm's "Main Field" (or its first field)
///   and then navigate, so the form always has its required field context.
/// - If the farm has no fields → show a hint instead of opening a broken form.
Future<void> ensureFieldSelectedAndOpen(
  BuildContext context,
  WidgetRef ref,
  WidgetBuilder pageBuilder,
) async {
  final hierarchy = ref.read(hierarchyProvider);
  if (hierarchy.hasField) {
    _push(context, pageBuilder);
    return;
  }

  final farmId = hierarchy.entityId;
  if (farmId == null) return;

  try {
    final fields =
        await ref.read(farmRepositoryProvider).getFields(farmId: farmId);

    if (fields.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add a field first, then add crops or livestock.'),
          ),
        );
      }
      return;
    }

    FieldEntity field;
    try {
      field = fields.firstWhere(
        (f) => f.fieldName.trim().toLowerCase() == 'main field',
      );
    } on StateError {
      field = fields.first;
    }

    ref.read(hierarchyProvider.notifier).selectField(field);
    if (context.mounted) _push(context, pageBuilder);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load fields. Please try again.'),
        ),
      );
    }
  }
}

void _push(BuildContext context, WidgetBuilder pageBuilder) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: pageBuilder),
  );
}
