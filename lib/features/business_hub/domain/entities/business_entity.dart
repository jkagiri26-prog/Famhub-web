/// ============================================================
/// BUSINESS ENTITY (DOMAIN)
/// ============================================================
///
/// Pure domain entity for a commercial/business record.
/// Aligned with `core.entities` backend schema.
///
/// Persisted fields (stored in DB):
///   id, name, slug, entity_type, owner_id, is_active, metadata,
///   created_at, updated_at, verification_status, legal_owner_type,
///   primary_contact_profile_id
///
/// Ownership (`owner_id`, `core.auth_user_id()`) and RLS scoping are
/// resolved server-side — the client never submits ownership claims.
///
/// Schema source: docs/Backend schemas/core schema.md
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import '../enums/business_entity_type.dart';

class BusinessEntity {
  final String id;
  final String name;
  final String? slug;
  final BusinessEntityType entityType;

  /// Raw `verification_status`: pending | verified | rejected | suspended.
  final String verificationStatus;

  /// Raw `legal_owner_type`: individual | business | cooperative |
  /// organization.
  final String? legalOwnerType;
  final bool isActive;
  final String? primaryContactProfileId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BusinessEntity({
    required this.id,
    required this.name,
    this.slug,
    this.entityType = BusinessEntityType.other,
    this.verificationStatus = 'pending',
    this.legalOwnerType,
    this.isActive = true,
    this.primaryContactProfileId,
    this.createdAt,
    this.updatedAt,
  });

  /// Whether this entity has passed verification.
  bool get isVerified => verificationStatus == 'verified';

  factory BusinessEntity.fromRow(Map<String, dynamic> row) {
    return BusinessEntity(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      slug: row['slug']?.toString(),
      entityType: BusinessEntityType.fromDb(row['entity_type']?.toString()),
      verificationStatus:
          row['verification_status']?.toString() ?? 'pending',
      legalOwnerType: row['legal_owner_type']?.toString(),
      isActive: row['is_active'] is bool ? row['is_active'] as bool : true,
      primaryContactProfileId:
          row['primary_contact_profile_id']?.toString(),
      createdAt: _parseDateTime(row['created_at']),
      updatedAt: _parseDateTime(row['updated_at']),
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
