/// ============================================================
/// AGRI CONNECT — ANNOUNCEMENT REPOSITORY IMPLEMENTATION
/// ============================================================
library;

import 'package:famhub_app/features/agri_connect/domain/entities/announcement.dart';
import 'package:famhub_app/features/agri_connect/domain/enums/announcement_enums.dart';
import 'package:famhub_app/features/agri_connect/domain/repositories/announcement_repository.dart';
import 'package:famhub_app/features/agri_connect/infrastructure/data_sources/announcement_remote_data_source.dart';

class AnnouncementRepositoryImpl implements AnnouncementRepository {
  final AnnouncementRemoteDataSource _dataSource;

  AnnouncementRepositoryImpl(this._dataSource);

  @override
  Future<List<Announcement>> fetchAnnouncements({
    String? communityId,
    AnnouncementType? type,
  }) async {
    final rows = await _dataSource.fetchAnnouncements(
      communityId: communityId,
      type: type?.name,
    );
    return rows.map(Announcement.fromJson).toList();
  }

  @override
  Future<Announcement> createAnnouncement({
    required String title,
    required String body,
    required AnnouncementType type,
    String? communityId,
    String? entityId,
    bool isPublished = false,
    DateTime? expiresAt,
  }) async {
    final row = await _dataSource.insertAnnouncement({
      'title': title,
      'body': body,
      'announcement_type': type.name,
      if (communityId != null && communityId.isNotEmpty)
        'community_id': communityId,
      if (entityId != null && entityId.isNotEmpty) 'entity_id': entityId,
      'is_published': isPublished,
      if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
    });
    return Announcement.fromJson(row);
  }

  @override
  Future<void> publishAnnouncement(String announcementId) async {
    await _dataSource.updateAnnouncement(announcementId, {
      'is_published': true,
      'published_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> unpublishAnnouncement(String announcementId) async {
    await _dataSource.updateAnnouncement(announcementId, {
      'is_published': false,
    });
  }

  @override
  Future<void> deleteAnnouncement(String announcementId) async {
    await _dataSource.deleteAnnouncement(announcementId);
  }
}
