/// ============================================================
/// ACTIVITY PERSISTENCE MAPPER (PURE DART — NO FLUTTER/SUPABASE)
/// ============================================================
///
/// Single source of truth for mapping [ActivityModel] to/from the
/// `farm_management.activities` table.
///
/// 🔒 DOCUMENTED CONTRACT:
///   - Only documented columns are inserted: activity_type_id,
///     performed_at, notes, asset_id, plan_id.
///   - `id` is NEVER inserted — the backend auto-generates it and it is
///     read back from the INSERT response.
///   - UI-context fields (farmId, fieldId, cropOrLivestockId,
///     cropOrLivestockType) are NOT persisted. They can only be
///     reconstructed when a caller resolves them from the linked
///     asset/plan (see farm_repository_impl).
///
/// Pure Dart so the persistence mapping can be unit-tested without
/// the Flutter/PostgREST runtime.
/// ============================================================
library;

import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';

/// Builds the exact INSERT payload sent to `farm_management.activities`.
/// Never includes `id` (backend-generated) or UI-context fields.
Map<String, dynamic> buildActivityInsertPayload(ActivityModel activity) {
  return {
    'activity_type_id': activity.activityTypeId,
    'performed_at': activity.performedAt.toIso8601String(),
    'notes': activity.notes,
    'asset_id': activity.assetId,
    'plan_id': activity.planId,
  };
}

/// Maps a persisted row back to an [ActivityModel].
///
/// [farmId]/[fieldId]/[cropOrLivestockId]/[cropOrLivestockType] are
/// optional UI-context values supplied by the caller when the hierarchy
/// can be reconstructed from the linked asset/plan. They are NOT read
/// from the activities row (no such columns exist).
ActivityModel activityFromRow(
  Map<String, dynamic> row, {
  String? farmId,
  String? fieldId,
  String? cropOrLivestockId,
  String? cropOrLivestockType,
}) {
  return ActivityModel(
    id: row['id'] as String,
    activityTypeId: row['activity_type_id'] as String,
    farmId: farmId,
    fieldId: fieldId,
    cropOrLivestockId: cropOrLivestockId,
    cropOrLivestockType: cropOrLivestockType,
    performedAt: DateTime.parse(row['performed_at'] as String),
    notes: row['notes'] as String?,
    assetId: row['asset_id'] as String?,
    planId: row['plan_id'] as String?,
  );
}
