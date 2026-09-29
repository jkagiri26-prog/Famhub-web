/// ============================================================
/// AGRI CONNECT — DISCUSSION ENUMS
/// ============================================================
/// Source: docs/Backend schemas/agri_connect.md
/// ============================================================
library;

/// `agri_connect.discussions.discussion_type`
enum DiscussionType {
  question,
  discussion,
  announcement,
  poll;

  static DiscussionType fromValue(String? v) => DiscussionType.values
      .firstWhere((e) => e.name == v, orElse: () => DiscussionType.discussion);
}
