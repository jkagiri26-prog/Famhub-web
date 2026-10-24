/// ============================================================
/// ACTIVITY TYPE CATALOG PROVIDER
/// ============================================================
///
/// Loads the active `farm_management.activity_types` rows (id, name,
/// category) so the Record Activity quick form can:
///   * offer only real, submittable types (every chip resolves to a live
///     catalog id — no more "Unknown activity type: other/general/..."), and
///   * filter the list per selected asset kind (crop vs livestock) using
///     [activityTypeAppliesTo].
///
/// Static reference data → non-autoDispose FutureProvider (cached for the
/// app session).
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/application/providers/activity_template_loader.dart';

/// One selectable quick-form activity type.
typedef ActivityTypeOption = ({String id, String name, String? category});

/// Active activity-type catalog. Falls back to the loader's preset rows
/// when the table is unreachable (submission still requires the backend,
/// so this only degrades the picker, never silently succeeds).
final activityTypeCatalogProvider =
    FutureProvider<List<ActivityTypeOption>>((ref) async {
  final loader = ref.read(activityTemplateLoaderProvider);
  final rows = await loader.loadActivityTypes();
  final options = <ActivityTypeOption>[];
  for (final row in rows) {
    final id = row['id']?.toString();
    final name = row['name']?.toString();
    if (id == null || id.isEmpty || name == null || name.isEmpty) continue;
    options.add((
      id: id,
      name: name,
      category: row['category']?.toString(),
    ));
  }
  return options;
});
