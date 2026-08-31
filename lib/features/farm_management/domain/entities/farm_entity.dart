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
  final String id;
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
    required this.farmName,
    this.description,
    this.size,
    this.countyId,
    this.subCountyId,
    this.wardId,
    required this.isActive,
    required this.isVerified,
  });
}

