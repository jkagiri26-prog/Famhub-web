/// ============================================================
/// AGRI CONNECT — ANNOUNCEMENT PROVIDERS
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/announcement.dart';
import '../../domain/enums/announcement_enums.dart';
import '../../domain/repositories/announcement_repository.dart';
import 'agri_connect_providers.dart';

final announcementsProvider =
    FutureProvider.family<List<Announcement>, String?>((
      ref,
      communityId,
    ) async {
      return ref
          .watch(announcementRepositoryProvider)
          .fetchAnnouncements(communityId: communityId);
    });

final famhubAnnouncementsProvider = FutureProvider<List<Announcement>>((
  ref,
) async {
  return ref
      .watch(announcementRepositoryProvider)
      .fetchAnnouncements(type: AnnouncementType.famhub);
});

/// Mutation controller for announcements.
class AnnouncementController extends Notifier<void> {
  AnnouncementRepository get _repo => ref.read(announcementRepositoryProvider);

  @override
  void build() {}

  Future<Announcement> createAnnouncement({
    required String title,
    required String body,
    required AnnouncementType type,
    String? communityId,
    bool isPublished = false,
  }) async {
    final announcement = await _repo.createAnnouncement(
      title: title,
      body: body,
      type: type,
      communityId: communityId,
      isPublished: isPublished,
    );
    ref.invalidate(announcementsProvider(communityId));
    ref.invalidate(famhubAnnouncementsProvider);
    return announcement;
  }

  Future<void> publishAnnouncement({
    required String announcementId,
    required String? communityId,
  }) async {
    await _repo.publishAnnouncement(announcementId);
    ref.invalidate(announcementsProvider(communityId));
    ref.invalidate(famhubAnnouncementsProvider);
  }
}

final announcementControllerProvider =
    NotifierProvider<AnnouncementController, void>(AnnouncementController.new);
