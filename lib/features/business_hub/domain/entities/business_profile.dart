/// ============================================================
/// BUSINESS PROFILE (DOMAIN)
/// ============================================================
///
/// Pure domain entity for a marketplace/business seller profile.
/// Aligned with `commerce.business_profiles` backend schema.
///
/// Persisted fields (subset surfaced by Business Hub):
///   id, entity_id, entity_type, supplier_name, contact_person, phone,
///   email, verification_status, rating, is_active, created_at, updated_at
///
/// Not every `core.entities` row has a `commerce.business_profiles`
/// record (profiles are created during seller/business onboarding).
///
/// Schema source: docs/Backend schemas/commerce schema.md
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

class BusinessProfile {
  final String id;
  final String entityId;

  /// Raw `entity_type`: individual | company | agrovet | cooperative |
  /// trader.
  final String? entityType;
  final String? supplierName;
  final String? contactPerson;
  final String? phone;
  final String? email;

  /// Raw `verification_status`: pending | verified | rejected |
  /// suspended.
  final String verificationStatus;
  final double? rating;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BusinessProfile({
    required this.id,
    required this.entityId,
    this.entityType,
    this.supplierName,
    this.contactPerson,
    this.phone,
    this.email,
    this.verificationStatus = 'pending',
    this.rating,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  bool get isVerified => verificationStatus == 'verified';

  String get displayName {
    final name = supplierName?.trim();
    return (name != null && name.isNotEmpty) ? name : 'Business Profile';
  }

  factory BusinessProfile.fromRow(Map<String, dynamic> row) {
    return BusinessProfile(
      id: row['id']?.toString() ?? '',
      entityId: row['entity_id']?.toString() ?? '',
      entityType: row['entity_type']?.toString(),
      supplierName: row['supplier_name']?.toString(),
      contactPerson: row['contact_person']?.toString(),
      phone: row['phone']?.toString(),
      email: row['email']?.toString(),
      verificationStatus:
          row['verification_status']?.toString() ?? 'pending',
      rating: (row['rating'] as num?)?.toDouble(),
      isActive: row['is_active'] is bool ? row['is_active'] as bool : true,
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
