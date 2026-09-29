/// ============================================================
/// AGRI CONNECT — SHARED PROVIDERS
/// ============================================================
///
/// Canonical identity + repository wiring shared by all capability
/// controllers. Profile id comes from the existing session profile
/// (`users.profiles.id`) — never `auth.users.id`.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/core/session/app_session.dart';
import 'package:famhub_app/core/session/session_provider.dart';

import '../../domain/repositories/announcement_repository.dart';
import '../../domain/repositories/community_repository.dart';
import '../../domain/repositories/discussion_repository.dart';
import '../../domain/repositories/messaging_repository.dart';
import '../../domain/repositories/moderation_repository.dart';
import '../../infrastructure/data_sources/agri_connect_media.dart';
import '../../infrastructure/data_sources/agri_connect_profile_names.dart';
import '../../infrastructure/data_sources/announcement_remote_data_source.dart';
import '../../infrastructure/data_sources/community_remote_data_source.dart';
import '../../infrastructure/data_sources/discussion_remote_data_source.dart';
import '../../infrastructure/data_sources/messaging_remote_data_source.dart';
import '../../infrastructure/data_sources/moderation_remote_data_source.dart';
import '../../infrastructure/repositories/announcement_repository_impl.dart';
import '../../infrastructure/repositories/community_repository_impl.dart';
import '../../infrastructure/repositories/discussion_repository_impl.dart';
import '../../infrastructure/repositories/messaging_repository_impl.dart';
import '../../infrastructure/repositories/moderation_repository_impl.dart';

/// The authenticated caller's canonical profile id, or null (guest / no
/// profile yet). Derived from the existing session profile row.
final agriConnectProfileIdProvider = Provider<String?>((ref) {
  final session = ref.watch(sessionProvider);
  if (session is! AuthenticatedSession) return null;
  final id = session.profile?['id']?.toString();
  return (id == null || id.isEmpty) ? null : id;
});

// ── Shared infra providers ──────────────────────────────────

final agriConnectProfileNamesProvider = Provider<AgriConnectProfileNames>((
  ref,
) {
  return AgriConnectProfileNames(Supabase.instance.client);
});

final agriConnectMediaProvider = Provider<AgriConnectMediaDataSource>((ref) {
  return AgriConnectMediaDataSource(Supabase.instance.client);
});

final communityRemoteDataSourceProvider = Provider<CommunityRemoteDataSource>(
  (ref) => CommunityRemoteDataSource(),
);

final discussionRemoteDataSourceProvider = Provider<DiscussionRemoteDataSource>(
  (ref) => DiscussionRemoteDataSource(),
);

final messagingRemoteDataSourceProvider = Provider<MessagingRemoteDataSource>(
  (ref) => MessagingRemoteDataSource(),
);

final announcementRemoteDataSourceProvider =
    Provider<AnnouncementRemoteDataSource>(
      (ref) => AnnouncementRemoteDataSource(),
    );

final moderationRemoteDataSourceProvider = Provider<ModerationRemoteDataSource>(
  (ref) => ModerationRemoteDataSource(),
);

// ── Repository providers ─────────────────────────────────────

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepositoryImpl(
    ref.watch(communityRemoteDataSourceProvider),
    ref.watch(agriConnectProfileNamesProvider),
  );
});

final discussionRepositoryProvider = Provider<DiscussionRepository>((ref) {
  return DiscussionRepositoryImpl(
    ref.watch(discussionRemoteDataSourceProvider),
    ref.watch(agriConnectProfileNamesProvider),
  );
});

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  return MessagingRepositoryImpl(
    ref.watch(messagingRemoteDataSourceProvider),
    ref.watch(agriConnectProfileNamesProvider),
  );
});

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepositoryImpl(
    ref.watch(announcementRemoteDataSourceProvider),
  );
});

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return ModerationRepositoryImpl(
    ref.watch(moderationRemoteDataSourceProvider),
  );
});
