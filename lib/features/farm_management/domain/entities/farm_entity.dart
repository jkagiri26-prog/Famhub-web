/// Minimal farm entity used by the farm selector and dashboard context.
///
/// Schema source (Supabase / Postgres):
///   farm_management.farms:
///     - id (uuid)
///     - farm_name (text)
///     - description (text)
///     - size (numeric)
///     - county_id (uuid NOT NULL) → core.locations
///     - sub_county_id (uuid NOT NULL) → core.locations
///     - ward_id (uuid NOT NULL) → core.locations
///     - is_active (boolean)
///     - is_verified (boolean)
///
/// 🗺️ LOCATION SOURCE:
///   countyId / subCountyId / wardId are the FARM's location — the user
///   selects them from core.locations in the farm creation form (via the
///   geography hierarchy). They are independent of the user's profile
///   location. Farm creation never invents or fabricates location IDs.
class FarmEntity {
  /// `farm_management.farms.id`
  final String id;

  /// Canonical owning entity: `core.entities.id`.
  ///
  /// Returned by the `commerce.create_farm_with_auto_entity` RPC. It is
  /// the CORE entity id — NOT the farm id, NOT an auth/profile/workspace
  /// id. Null when the owning entity is not known (e.g. farms loaded from
  /// a row that has no entity linkage available).
  final String? entityId;

  final String farmName;
  final String? description;
  final double? size;
  final String? countyId;
  final String? subCountyId;
  final String? wardId;
  final bool isActive;
  final bool isVerified;

  const FarmEntity({
    required this.id,
    this.entityId,
    required this.farmName,
    this.description,
    this.size,
    this.countyId,
    this.subCountyId,
    this.wardId,
    required this.isActive,
    required this.isVerified,
  });

  FarmEntity copyWith({
    String? id,
    String? entityId,
    String? farmName,
    String? description,
    double? size,
    String? countyId,
    String? subCountyId,
    String? wardId,
    bool? isActive,
    bool? isVerified,
    bool clearEntityId = false,
  }) {
    return FarmEntity(
      id: id ?? this.id,
      entityId: clearEntityId ? null : entityId ?? this.entityId,
      farmName: farmName ?? this.farmName,
      description: description ?? this.description,
      size: size ?? this.size,
      countyId: countyId ?? this.countyId,
      subCountyId: subCountyId ?? this.subCountyId,
      wardId: wardId ?? this.wardId,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}

