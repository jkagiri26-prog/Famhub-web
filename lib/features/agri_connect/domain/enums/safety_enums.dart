/// ============================================================
/// AGRI CONNECT — SAFETY / MODERATION ENUMS
/// ============================================================
/// Source: docs/Backend schemas/agri_connect.md
/// ============================================================
library;

/// `agri_connect.content_reports.target_type`
enum ReportTargetType {
  community,
  discussion,
  post,
  message,
  announcement,
  profile;

  static ReportTargetType fromValue(String? v) => ReportTargetType.values
      .firstWhere((e) => e.name == v, orElse: () => ReportTargetType.post);
}

/// `agri_connect.content_reports.status`
enum ReportStatus {
  pending,
  reviewing,
  resolved,
  dismissed;

  static ReportStatus fromValue(String? v) => ReportStatus.values.firstWhere(
    (e) => e.name == v,
    orElse: () => ReportStatus.pending,
  );
}

/// `agri_connect.moderation_actions.action_type`
enum ModerationActionType {
  warn,
  mute,
  remove,
  restore,
  suspend,
  ban,
  unban,
  lock,
  unlock;

  static ModerationActionType fromValue(String? v) => ModerationActionType
      .values
      .firstWhere((e) => e.name == v, orElse: () => ModerationActionType.warn);
}
