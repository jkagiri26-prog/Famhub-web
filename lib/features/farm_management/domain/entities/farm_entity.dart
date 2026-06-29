/// Minimal farm entity used by the farm selector and dashboard context.
///
/// Schema source (Supabase / Postgres):
///   farm.farms:
///     - id (uuid)
///     - farm_name (text)
///     - description (text)
///     - size (numeric)
///     - is_active (boolean)
///     - is_verified (boolean)
class FarmEntity {
  final String id;
  final String farmName;
  final String? description;
  final double? size;
  final bool isActive;
  final bool isVerified;

  const FarmEntity({
    required this.id,
    required this.farmName,
    this.description,
    this.size,
    required this.isActive,
    required this.isVerified,
  });
}

