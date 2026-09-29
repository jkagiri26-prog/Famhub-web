/// ============================================================
/// AGRI CONNECT — MODERATION REPOSITORY IMPLEMENTATION
/// ============================================================
library;

import 'package:famhub_app/features/agri_connect/domain/entities/content_report.dart';
import 'package:famhub_app/features/agri_connect/domain/entities/moderation_action.dart';
import 'package:famhub_app/features/agri_connect/domain/enums/safety_enums.dart';
import 'package:famhub_app/features/agri_connect/domain/repositories/moderation_repository.dart';
import 'package:famhub_app/features/agri_connect/infrastructure/data_sources/moderation_remote_data_source.dart';

class ModerationRepositoryImpl implements ModerationRepository {
  final ModerationRemoteDataSource _dataSource;

  ModerationRepositoryImpl(this._dataSource);

  @override
  Future<ContentReport> submitReport({
    required String reporterProfileId,
    required ReportTargetType targetType,
    required String targetId,
    required String reason,
    String? description,
  }) async {
    final row = await _dataSource.insertReport({
      'reporter_profile_id': reporterProfileId,
      'target_type': targetType.name,
      'target_id': targetId,
      'reason': reason,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    });
    return ContentReport.fromJson(row);
  }

  @override
  Future<List<ContentReport>> fetchReviewableReports({
    String? communityId,
  }) async {
    final rows = await _dataSource.fetchReports();
    return rows.map(ContentReport.fromJson).toList();
  }

  @override
  Future<void> reviewReport({
    required String reportId,
    required ReportStatus status,
    String? resolution,
  }) async {
    await _dataSource.reviewReport(
      reportId: reportId,
      status: status.name,
      resolution: resolution,
    );
  }

  @override
  Future<void> blockUser({
    required String blockerProfileId,
    required String blockedProfileId,
  }) async {
    await _dataSource.insertBlock(
      blockerProfileId: blockerProfileId,
      blockedProfileId: blockedProfileId,
    );
  }

  @override
  Future<void> unblockUser({
    required String blockerProfileId,
    required String blockedProfileId,
  }) async {
    await _dataSource.deleteBlock(
      blockerProfileId: blockerProfileId,
      blockedProfileId: blockedProfileId,
    );
  }

  @override
  Future<List<String>> fetchBlockedProfileIds(String blockerProfileId) async {
    return _dataSource.fetchBlockedProfileIds(blockerProfileId);
  }

  @override
  Future<ModerationAction> recordModerationAction({
    required String moderatorProfileId,
    String? communityId,
    required String targetType,
    required String targetId,
    required ModerationActionType actionType,
    String? reason,
  }) async {
    final row = await _dataSource.insertModerationAction({
      'moderator_profile_id': moderatorProfileId,
      if (communityId != null && communityId.isNotEmpty)
        'community_id': communityId,
      'target_type': targetType,
      'target_id': targetId,
      'action_type': actionType.name,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    return ModerationAction.fromJson(row);
  }
}
