/// ============================================================
/// AGRI CONNECT — COMMUNITY ENTITY
/// ============================================================
/// Source: docs/Backend schemas/agri_connect.md (`communities`)
///
/// `member_count` is database-maintained — never written by the client.
/// ============================================================
library;

import '../enums/community_enums.dart';

class Community {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final CommunityType type;
  final CommunityVisibility visibility;
  final String? entityId;
  final String? locationId;
  final String createdBy;
  final String? profileImageFileId;
  final bool isActive;
  final bool isVerified;
  final int memberCount;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Community({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.type,
    this.visibility = CommunityVisibility.public,
    this.entityId,
    this.locationId,
    required this.createdBy,
    this.profileImageFileId,
    this.isActive = true,
    this.isVerified = false,
    this.memberCount = 0,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory Community.fromJson(Map<String, dynamic> json) {
    return Community(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      type: CommunityType.fromValue(json['community_type']?.toString()),
      visibility: CommunityVisibility.fromValue(json['visibility']?.toString()),
      entityId: json['entity_id']?.toString(),
      locationId: json['location_id']?.toString(),
      createdBy: json['created_by']?.toString() ?? '',
      profileImageFileId: json['profile_image_file_id']?.toString(),
      isActive: json['is_active'] == true,
      isVerified: json['is_verified'] == true,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  bool get isPublic => visibility == CommunityVisibility.public;

  bool get requiresMembership =>
      visibility == CommunityVisibility.private ||
      visibility == CommunityVisibility.restricted;
}
