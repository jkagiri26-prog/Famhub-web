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
class ActivityModel {
  final String id;
  final String activityTypeId;
  final DateTime performedAt;
  final String? notes;
  final String? assetId;
  final String? planId;

  const ActivityModel({
    required this.id,
    required this.activityTypeId,
    required this.performedAt,
    this.notes,
    this.assetId,
    this.planId,
  });
}

