/// ============================================================
/// ADMIN LOCATION — READ MODEL
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/domain/models/ = domain models
///
/// The narrow admin-management projection returned by the canonical
/// `users.admin_list_locations` RPC. No geometry/GPS/population/soil or
/// other unrelated location metadata.
/// ============================================================
library;

class AdminLocation {
  final String id;
  final String name;
  final String? levelId;
  final String? levelName;
  final String? parentId;
  final String? parentName;
  final String? countryId;
  final String? countryName;
  final int? code;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminLocation({
    required this.id,
    required this.name,
    this.levelId,
    this.levelName,
    this.parentId,
    this.parentName,
    this.countryId,
    this.countryName,
    this.code,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminLocation.fromMap(Map<String, dynamic> map) {
    return AdminLocation(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      levelId: map['level_id']?.toString(),
      levelName: map['level_name']?.toString(),
      parentId: map['parent_id']?.toString(),
      parentName: map['parent_name']?.toString(),
      countryId: map['country_id']?.toString(),
      countryName: map['country_name']?.toString(),
      code: (map['code'] as num?)?.toInt(),
      isActive: map['is_active'] != false,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }
}

class AdminLocationsPage {
  final List<AdminLocation> items;
  final int totalCount;

  const AdminLocationsPage({required this.items, required this.totalCount});

  factory AdminLocationsPage.empty() =>
      const AdminLocationsPage(items: [], totalCount: 0);

  bool get isEmpty => items.isEmpty;
}

/// Reference data for the admin location forms/filters (canonical
/// `core.countries` / `core.geography_levels`, read-only).
class AdminCountry {
  final String id;
  final String name;
  final String? isoAlpha2;

  const AdminCountry({required this.id, required this.name, this.isoAlpha2});

  factory AdminCountry.fromMap(Map<String, dynamic> map) => AdminCountry(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        isoAlpha2: map['iso_alpha2']?.toString(),
      );
}

class AdminGeographyLevel {
  final String id;
  final String name;
  final int order;
  final String? countryId;

  const AdminGeographyLevel({
    required this.id,
    required this.name,
    required this.order,
    this.countryId,
  });

  factory AdminGeographyLevel.fromMap(Map<String, dynamic> map) =>
      AdminGeographyLevel(
        id: map['id']?.toString() ?? '',
        name: map['level_name']?.toString() ?? '',
        order: (map['level_order'] as num?)?.toInt() ?? 0,
        countryId: map['country_id']?.toString(),
      );
}
