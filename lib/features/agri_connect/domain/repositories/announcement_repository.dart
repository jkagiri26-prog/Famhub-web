/// ============================================================
/// AGRI CONNECT — ANNOUNCEMENT REPOSITORY CONTRACT
/// ============================================================
///
/// Community / organization / FAMHUB announcements.
/// Anonymous + authenticated reads are RLS-scoped.
/// ============================================================
library;

import '../entities/announcement.dart';
import '../enums/announcement_enums.dart';

abstract class AnnouncementRepository {
  Future<List<Announcement>> fetchAnnouncements({
    String? communityId,
    AnnouncementType? type,
  });

  /// Create an announcement (authorization enforced by RLS).
  Future<Announcement> createAnnouncement({
    required String title,
    required String body,
    required AnnouncementType type,
    String? communityId,
    String? entityId,
    bool isPublished = false,
    DateTime? expiresAt,
  });

  Future<void> publishAnnouncement(String announcementId);

  Future<void> unpublishAnnouncement(String announcementId);

  Future<void> deleteAnnouncement(String announcementId);
}
