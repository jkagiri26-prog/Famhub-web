/// ============================================================
/// BUSINESS HUB REPOSITORY — IMPLEMENTATION
/// ============================================================
///
/// Supabase-backed implementation of [BusinessHubRepository].
/// Delegates all reads to [BusinessHubRemoteDataSource].
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import '../../domain/entities/business_entity.dart';
import '../../domain/entities/business_profile.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/repositories/business_hub_repository.dart';
import '../data_sources/business_hub_remote_data_source.dart';

class BusinessHubRepositoryImpl implements BusinessHubRepository {
  final BusinessHubRemoteDataSource _dataSource;

  BusinessHubRepositoryImpl({BusinessHubRemoteDataSource? dataSource})
      : _dataSource = dataSource ?? BusinessHubRemoteDataSource();

  @override
  Future<List<BusinessEntity>> fetchMyBusinesses() async {
    final rows = await _dataSource.fetchMyEntities();
    return rows.map(BusinessEntity.fromRow).toList();
  }

  @override
  Future<BusinessProfile?> fetchBusinessProfile(String entityId) async {
    final row = await _dataSource.fetchBusinessProfile(entityId);
    if (row == null) return null;
    return BusinessProfile.fromRow(row);
  }

  @override
  Future<List<InventoryItem>> fetchInventory(String entityId) async {
    final rawRows = await _dataSource.fetchInventoryRows(entityId);
    return _buildInventoryItems(rawRows);
  }

  /// Resolve display names for stock rows via batched lookups (no
  /// cross-schema PostgREST embeds) and build [InventoryItem] entities.
  Future<List<InventoryItem>> _buildInventoryItems(
    List<Map<String, dynamic>> rawRows,
  ) async {
    if (rawRows.isEmpty) return const [];

    final variantIds = <String>{};
    final productIds = <String>{};
    final unitIds = <String>{};
    final locationIds = <String>{};

    for (final raw in rawRows) {
      final variantId = raw['variant_id']?.toString();
      final productId = raw['product_id']?.toString();
      final unitId = raw['unit_id']?.toString();
      final locationId = raw['location_id']?.toString();
      if (variantId != null && variantId.isNotEmpty) variantIds.add(variantId);
      if (productId != null && productId.isNotEmpty) {
        productIds.add(productId);
      }
      if (unitId != null && unitId.isNotEmpty) unitIds.add(unitId);
      if (locationId != null && locationId.isNotEmpty) {
        locationIds.add(locationId);
      }
    }

    // Independent best-effort lookups — never fail the inventory load.
    Map<String, String> variants = const {};
    Map<String, String> items = const {};
    Map<String, String> units = const {};
    Map<String, String> locations = const {};
    try {
      variants = await _dataSource.fetchVariantsByIds(variantIds);
    } catch (_) {}
    try {
      items = await _dataSource.fetchItemsByIds(productIds);
    } catch (_) {}
    try {
      units = await _dataSource.fetchUnitsByIds(unitIds);
    } catch (_) {}
    try {
      locations = await _dataSource.fetchLocationsByIds(locationIds);
    } catch (_) {}

    final result = <InventoryItem>[];
    for (final raw in rawRows) {
      final variantId = raw['variant_id']?.toString();
      final productId = raw['product_id']?.toString();
      final unitId = raw['unit_id']?.toString();
      final locationId = raw['location_id']?.toString();

      // Prefer the product (item) name and fall back to the variant name
      // when the product reference is not linked.
      final productName =
          (productId != null && items.containsKey(productId))
              ? items[productId]
              : (variantId != null && variants.containsKey(variantId))
                  ? variants[variantId]
                  : null;

      result.add(InventoryItem(
        id: raw['id']?.toString() ?? '',
        entityId: raw['entity_id']?.toString() ?? '',
        businessProfileId: raw['business_profile_id']?.toString(),
        variantId: variantId,
        productId: productId,
        displayName: productName,
        unitId: unitId,
        unitName: unitId != null && units.containsKey(unitId)
            ? units[unitId]
            : null,
        locationId: locationId,
        locationName: locationId != null && locations.containsKey(locationId)
            ? locations[locationId]
            : null,
        quantity: (raw['quantity'] as num?)?.toDouble() ?? 0,
        reservedQuantity:
            (raw['reserved_quantity'] as num?)?.toDouble() ?? 0,
        status: raw['status']?.toString() ?? 'active',
      ));
    }
    return result;
  }
}
