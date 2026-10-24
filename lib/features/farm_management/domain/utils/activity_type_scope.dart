/// ============================================================
/// ACTIVITY TYPE SCOPE (PURE DART)
/// ============================================================
///
/// Decides which quick-form activity types are relevant to the currently
/// selected asset kind (crop vs livestock).
///
/// Source of truth is `farm_management.activity_types.category`, with a
/// name-keyword fallback so rows whose category is missing or drifted still
/// land in the right scope. Unknown categories default to BOTH so a type is
/// never hidden from the user just because its taxonomy label is new.
/// ============================================================
library;

/// Which asset kinds an activity type is offered for.
enum ActivityTypeScope {
  /// Only offered while a crop is selected.
  crop,

  /// Only offered while a livestock is selected.
  livestock,

  /// Offered for both crop and livestock activities.
  both;
}

/// Matches the string values used by [HierarchySelectionState] /
/// `cropOrLivestockType` ('crop' | 'livestock'), so [scope.name] can be
/// compared directly against the hierarchy type.
const String kAssetTypeCrop = 'crop';
const String kAssetTypeLivestock = 'livestock';

/// Scope for an `activity_types` row identified by [name] and [category].
ActivityTypeScope activityTypeScope({
  required String name,
  String? category,
}) {
  final n = name.toLowerCase();
  final c = (category ?? '').trim().toLowerCase();

  // ── 1) Name keywords — most precise for the seeded catalog ──
  if (const [
    'milking',
    'feeding',
    'vaccin',
    'inseminat',
    'shearing',
    'dairy',
    'poultry',
  ].any(n.contains)) {
    return ActivityTypeScope.livestock;
  }
  if (const [
    'plant',
    'irrigat',
    'fertiliz',
    'weed',
    'pest',
    'spray',
    'prun',
    'harvest',
  ].any(n.contains)) {
    return ActivityTypeScope.crop;
  }

  // ── 2) Category groups ──
  if (const ['dairy', 'livestock', 'poultry', 'fish'].any(c.contains)) {
    return ActivityTypeScope.livestock;
  }
  // 'harvest' is scoped to crops: livestock harvesting is blocked at
  // submit time until a canonical output unit is configured.
  if (const ['crop', 'plant', 'irrigation', 'protection', 'harvest']
      .any(c.contains)) {
    return ActivityTypeScope.crop;
  }

  // ── 3) Unknown/missing category (e.g. 'general') → both ──
  return ActivityTypeScope.both;
}

/// Whether an activity type should be shown for [assetType]
/// ('crop' | 'livestock').
bool activityTypeAppliesTo({
  required String name,
  String? category,
  required String assetType,
}) {
  final scope = activityTypeScope(name: name, category: category);
  return scope == ActivityTypeScope.both || scope.name == assetType;
}
