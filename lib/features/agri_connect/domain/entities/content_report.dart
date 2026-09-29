/// ============================================================
/// AGRI CONNECT — CONTENT REPORT ENTITY
/// ============================================================
/// Source: docs/Backend schemas/agri_connect.md (`content_reports`)
///
/// Report identity/scope is protected by an immutable-report trigger;
/// moderators may only update moderation fields (status/review/resolution).
/// ============================================================
library;

import '../enums/safety_enums.dart';

class ContentReport {
  final String id;
  final String reporterProfileId;
  final ReportTargetType targetType;
  final String targetId;
  final String reason;
  final String? description;
  final ReportStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? resolution;
  final DateTime createdAt;

  const ContentReport({
    required this.id,
    required this.reporterProfileId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.description,
    this.status = ReportStatus.pending,
    this.reviewedBy,
    this.reviewedAt,
    this.resolution,
    required this.createdAt,
  });

  factory ContentReport.fromJson(Map<String, dynamic> json) {
    return ContentReport(
      id: json['id']?.toString() ?? '',
      reporterProfileId: json['reporter_profile_id']?.toString() ?? '',
      targetType: ReportTargetType.fromValue(json['target_type']?.toString()),
      targetId: json['target_id']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      description: json['description']?.toString(),
      status: ReportStatus.fromValue(json['status']?.toString()),
      reviewedBy: json['reviewed_by']?.toString(),
      reviewedAt: _parse(json['reviewed_at']),
      resolution: json['resolution']?.toString(),
      createdAt:
          _parse(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _parse(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());
}
