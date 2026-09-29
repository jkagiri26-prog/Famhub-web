/// ============================================================
/// AGRI CONNECT — MODERATION REPOSITORY CONTRACT
/// ============================================================
///
/// Reporting, blocking and moderation actions.
/// Report identity/scope is immutable; moderators only update
/// moderation fields. All operations are RLS-enforced.
/// ============================================================
library;

import '../entities/content_report.dart';
import '../entities/moderation_action.dart';
import '../enums/safety_enums.dart';

abstract class ModerationRepository {
  /// Submit a content report for the caller.
  Future<ContentReport> submitReport({
    required String reporterProfileId,
    required ReportTargetType targetType,
    required String targetId,
    required String reason,
    String? description,
  });

  /// Reports a moderator/admin can review (RLS-scoped).
  Future<List<ContentReport>> fetchReviewableReports({String? communityId});

  /// Update only the moderation fields of a report.
  Future<void> reviewReport({
    required String reportId,
    required ReportStatus status,
    String? resolution,
  });

  /// Block another profile. The caller controls their own block list.
  Future<void> blockUser({
    required String blockerProfileId,
    required String blockedProfileId,
  });

  Future<void> unblockUser({
    required String blockerProfileId,
    required String blockedProfileId,
  });

  Future<List<String>> fetchBlockedProfileIds(String blockerProfileId);

  /// Record a moderation action (community-scoped where applicable).
  Future<ModerationAction> recordModerationAction({
    required String moderatorProfileId,
    String? communityId,
    required String targetType,
    required String targetId,
    required ModerationActionType actionType,
    String? reason,
  });
}
