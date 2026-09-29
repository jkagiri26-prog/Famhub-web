/// ============================================================
/// AGRI CONNECT — MODERATION PROVIDERS
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/content_report.dart';
import '../../domain/enums/safety_enums.dart';
import '../../domain/repositories/moderation_repository.dart';
import 'agri_connect_providers.dart';

final reviewableReportsProvider = FutureProvider<List<ContentReport>>((
  ref,
) async {
  return ref.watch(moderationRepositoryProvider).fetchReviewableReports();
});

final blockedProfileIdsProvider = FutureProvider<List<String>>((ref) async {
  final profileId = ref.watch(agriConnectProfileIdProvider);
  if (profileId == null) return const [];
  return ref
      .watch(moderationRepositoryProvider)
      .fetchBlockedProfileIds(profileId);
});

/// Mutation controller for reports, blocks and moderation actions.
class ModerationController extends Notifier<void> {
  ModerationRepository get _repo => ref.read(moderationRepositoryProvider);

  @override
  void build() {}

  Future<ContentReport> submitReport({
    required ReportTargetType targetType,
    required String targetId,
    required String reason,
    String? description,
  }) async {
    final profileId = ref.read(agriConnectProfileIdProvider);
    if (profileId == null) {
      throw Exception('You must be signed in to report content.');
    }
    final report = await _repo.submitReport(
      reporterProfileId: profileId,
      targetType: targetType,
      targetId: targetId,
      reason: reason,
      description: description,
    );
    return report;
  }

  Future<void> reviewReport({
    required String reportId,
    required ReportStatus status,
    String? resolution,
  }) async {
    await _repo.reviewReport(
      reportId: reportId,
      status: status,
      resolution: resolution,
    );
    ref.invalidate(reviewableReportsProvider);
  }

  Future<void> blockUser(String blockedProfileId) async {
    final profileId = ref.read(agriConnectProfileIdProvider);
    if (profileId == null) {
      throw Exception('You must be signed in to block users.');
    }
    await _repo.blockUser(
      blockerProfileId: profileId,
      blockedProfileId: blockedProfileId,
    );
    ref.invalidate(blockedProfileIdsProvider);
  }

  Future<void> unblockUser(String blockedProfileId) async {
    final profileId = ref.read(agriConnectProfileIdProvider);
    if (profileId == null) return;
    await _repo.unblockUser(
      blockerProfileId: profileId,
      blockedProfileId: blockedProfileId,
    );
    ref.invalidate(blockedProfileIdsProvider);
  }

  Future<void> recordModerationAction({
    String? communityId,
    required String targetType,
    required String targetId,
    required ModerationActionType actionType,
    String? reason,
  }) async {
    final profileId = ref.read(agriConnectProfileIdProvider);
    if (profileId == null) {
      throw Exception('You must be signed in to moderate.');
    }
    await _repo.recordModerationAction(
      moderatorProfileId: profileId,
      communityId: communityId,
      targetType: targetType,
      targetId: targetId,
      actionType: actionType,
      reason: reason,
    );
  }
}

final moderationControllerProvider =
    NotifierProvider<ModerationController, void>(ModerationController.new);
