/// Represents a single row from `farm.activities` plus relevant fields
/// needed by the UI.
///
/// Schema source:
///   farm.activities:
///     - id (uuid)
///     - activity_type_id (uuid)
///     - performed_at (timestamptz)
///     - notes (text)
///     - asset_id (uuid, nullable)
///     - plan_id (uuid, nullable)
///
/// Also carries dynamic attribute values that are persisted
/// to farm_management.activity_values table.
class ActivityModel {
  final String id;
  final String activityTypeId;
  final DateTime performedAt;
  final String? notes;
  final String? assetId;
  final String? planId;

  /// Dynamic attribute values collected during workflow execution.
  /// These are persisted to activity_values table.
  /// Key = attribute_id (from attribute_registry) or attribute name
  /// Value = the collected value (text, number, boolean, etc.)
  final Map<String, dynamic> attributeValues;

  const ActivityModel({
    required this.id,
    required this.activityTypeId,
    required this.performedAt,
    this.notes,
    this.assetId,
    this.planId,
    this.attributeValues = const {},
  });

  /// Create a copy with updated fields
  ActivityModel copyWith({
    String? id,
    String? activityTypeId,
    DateTime? performedAt,
    String? notes,
    String? assetId,
    String? planId,
    Map<String, dynamic>? attributeValues,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      activityTypeId: activityTypeId ?? this.activityTypeId,
      performedAt: performedAt ?? this.performedAt,
      notes: notes ?? this.notes,
      assetId: assetId ?? this.assetId,
      planId: planId ?? this.planId,
      attributeValues: attributeValues ?? this.attributeValues,
    );
  }
}

