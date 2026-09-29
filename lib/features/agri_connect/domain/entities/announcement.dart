/// ============================================================
/// AGRI CONNECT — ANNOUNCEMENT ENTITY
/// ============================================================
/// Source: docs/Backend schemas/agri_connect.md (`announcements`)
/// ============================================================
library;

import '../enums/announcement_enums.dart';

class Announcement {
  final String id;
  final String title;
  final String body;
  final AnnouncementType type;
  final String? communityId;
  final String? entityId;
  final String publishedBy;
  final bool isPublished;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final bool isPinned;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.communityId,
    this.entityId,
    required this.publishedBy,
    this.isPublished = false,
    this.publishedAt,
    this.expiresAt,
    this.isPinned = false,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isExpired {
    final e = expiresAt;
    return e != null && e.isBefore(DateTime.now());
  }

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: AnnouncementType.fromValue(json['announcement_type']?.toString()),
      communityId: json['community_id']?.toString(),
      entityId: json['entity_id']?.toString(),
      publishedBy: json['published_by']?.toString() ?? '',
      isPublished: json['is_published'] == true,
      publishedAt: _parse(json['published_at']),
      expiresAt: _parse(json['expires_at']),
      isPinned: json['is_pinned'] == true,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt:
          _parse(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _parse(json['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _parse(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());
}
