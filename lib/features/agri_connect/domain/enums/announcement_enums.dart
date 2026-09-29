/// ============================================================
/// AGRI CONNECT — ANNOUNCEMENT ENUMS
/// ============================================================
/// Source: docs/Backend schemas/agri_connect.md
/// ============================================================
library;

/// `agri_connect.announcements.announcement_type`
enum AnnouncementType {
  community,
  organization,
  famhub;

  static AnnouncementType fromValue(String? v) => AnnouncementType.values
      .firstWhere((e) => e.name == v, orElse: () => AnnouncementType.famhub);
}
