/// ============================================================
/// BUSINESS HUB REPOSITORY — IMPLEMENTATION
/// ============================================================
///
/// Supabase-backed implementation of [BusinessHubRepository].
/// Delegates all reads to [BusinessHubRemoteDataSource].
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import '../../domain/entities/business_entity.dart';
import '../../domain/entities/business_listing.dart';
import '../../domain/entities/business_profile.dart';
import '../../domain/entities/business_transaction.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/sales_order.dart';
import '../../domain/entities/sales_order_line.dart';
import '../../domain/repositories/business_hub_repository.dart';
import 'package:famhub_app/features/marketplace/domain/repositories/marketplace_repository.dart';
import '../data_sources/business_hub_remote_data_source.dart';

class BusinessHubRepositoryImpl implements BusinessHubRepository {
  final BusinessHubRemoteDataSource _dataSource;
  final MarketplaceRepository _marketplace;

  BusinessHubRepositoryImpl({
    BusinessHubRemoteDataSource? dataSource,
    required MarketplaceRepository marketplace,
  })  : _dataSource = dataSource ?? BusinessHubRemoteDataSource(),
        _marketplace = marketplace;

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

  @override
  Future<List<PurchaseOrder>> fetchPurchaseOrders(String entityId) async {
    // Resolve the business's people scope: owner + active members.
    final creatorIds = <String>{};
    final ownerId = await _dataSource.fetchEntityOwnerId(entityId);
    if (ownerId != null && ownerId.isNotEmpty) creatorIds.add(ownerId);
    creatorIds
        .addAll(await _dataSource.fetchEntityMemberProfileIds(entityId));

    if (creatorIds.isEmpty) return const [];

    final rawRows =
        await _dataSource.fetchPurchaseOrdersByCreators(creatorIds);
    return _buildPurchaseOrders(rawRows);
  }

  /// Enrich supplier display names (commerce.business_profiles) and build
  /// [PurchaseOrder] entities. Best-effort enrichment — never fails the
  /// procurement load.
  Future<List<PurchaseOrder>> _buildPurchaseOrders(
    List<Map<String, dynamic>> rawRows,
  ) async {
    if (rawRows.isEmpty) return const [];

    final supplierIds = <String>{};
    for (final raw in rawRows) {
      final supplierId = raw['supplier_id']?.toString();
      if (supplierId != null && supplierId.isNotEmpty) {
        supplierIds.add(supplierId);
      }
    }

    Map<String, String> supplierNames = const {};
    try {
      supplierNames =
          await _dataSource.fetchBusinessProfileNamesByIds(supplierIds);
    } catch (_) {}

    return rawRows.map((raw) {
      final supplierId = raw['supplier_id']?.toString();
      return PurchaseOrder(
        id: raw['id']?.toString() ?? '',
        supplierId: supplierId,
        supplierName: supplierId != null && supplierNames.containsKey(supplierId)
            ? supplierNames[supplierId]
            : null,
        createdBy: raw['created_by']?.toString(),
        status: raw['status']?.toString() ?? 'pending',
        totalAmount: (raw['total_amount'] as num?)?.toDouble() ?? 0,
        currency: raw['currency']?.toString() ?? 'KES',
        notes: raw['notes']?.toString(),
        createdAt: _parseDateTime(raw['created_at']),
      );
    }).toList();
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  // ════════════════════════════════════════════════════════════════
  // SALES (commerce.orders / commerce.order_items)
  // ════════════════════════════════════════════════════════════════

  @override
  Future<List<SalesOrder>> fetchSalesOrders(String entityId) async {
    // The seller business of record for an entity is its own
    // `commerce.business_profiles`. Orders are scoped to those profiles.
    final profileIds = await _dataSource.fetchEntityBusinessProfileIds(
      entityId,
    );
    if (profileIds.isEmpty) return const [];

    final rawRows = await _dataSource.fetchOrdersBySuppliers(profileIds);
    return _buildSalesOrders(rawRows);
  }

  /// Enrich buyer display names (users.profiles) and build
  /// [SalesOrder] entities. Best-effort enrichment — never fails the
  /// sales load.
  Future<List<SalesOrder>> _buildSalesOrders(
    List<Map<String, dynamic>> rawRows,
  ) async {
    if (rawRows.isEmpty) return const [];

    final buyerIds = <String>{};
    for (final raw in rawRows) {
      final buyerId = raw['buyer_id']?.toString();
      if (buyerId != null && buyerId.isNotEmpty) buyerIds.add(buyerId);
    }

    Map<String, String> buyerNames = const {};
    try {
      buyerNames = await _dataSource.fetchUserProfileNamesByIds(buyerIds);
    } catch (_) {}

    return rawRows.map((raw) {
      final buyerId = raw['buyer_id']?.toString() ?? '';
      return SalesOrder(
        id: raw['id']?.toString() ?? '',
        buyerId: buyerId,
        buyerName: buyerNames.containsKey(buyerId)
            ? buyerNames[buyerId]
            : null,
        listingId: raw['listing_id']?.toString(),
        supplierId: raw['supplier_id']?.toString(),
        quantity: (raw['quantity'] as num?)?.toDouble() ?? 0,
        totalAmount: (raw['total_amount'] as num?)?.toDouble() ?? 0,
        status: raw['status']?.toString() ?? 'pending',
        paymentStatus: raw['payment_status']?.toString() ?? 'pending',
        paymentMode: raw['payment_mode']?.toString(),
        orderDate: _parseDateTime(raw['order_date']),
        deliveryDate: _parseDateTime(raw['delivery_date']),
      );
    }).toList();
  }

  @override
  Future<List<SalesOrderLine>> fetchOrderItems(String orderId) async {
    final rawRows =
        await _dataSource.fetchOrderItemsByOrderIds({orderId});
    return _buildOrderLines(rawRows);
  }

  /// Enrich variant/unit display names and build [SalesOrderLine]
  /// entities. Uses verified FKs only (`variant_id`, `unit_id`).
  Future<List<SalesOrderLine>> _buildOrderLines(
    List<Map<String, dynamic>> rawRows,
  ) async {
    if (rawRows.isEmpty) return const [];

    final variantIds = <String>{};
    final unitIds = <String>{};
    for (final raw in rawRows) {
      final variantId = raw['variant_id']?.toString();
      final unitId = raw['unit_id']?.toString();
      if (variantId != null && variantId.isNotEmpty) variantIds.add(variantId);
      if (unitId != null && unitId.isNotEmpty) unitIds.add(unitId);
    }

    Map<String, String> variants = const {};
    Map<String, String> units = const {};
    try {
      variants = await _dataSource.fetchVariantsByIds(variantIds);
    } catch (_) {}
    try {
      units = await _dataSource.fetchUnitsByIds(unitIds);
    } catch (_) {}

    return rawRows.map((raw) {
      final variantId = raw['variant_id']?.toString();
      final unitId = raw['unit_id']?.toString();
      return SalesOrderLine(
        id: raw['id']?.toString() ?? '',
        orderId: raw['order_id']?.toString() ?? '',
        listingId: raw['listing_id']?.toString(),
        variantId: variantId,
        variantName:
            variantId != null && variants.containsKey(variantId)
                ? variants[variantId]
                : null,
        unitId: unitId,
        unitName: unitId != null && units.containsKey(unitId)
            ? units[unitId]
            : null,
        unitText: raw['unit']?.toString(),
        quantity: (raw['quantity'] as num?)?.toDouble() ?? 0,
        pricePerUnit: (raw['price_per_unit'] as num?)?.toDouble() ?? 0,
        totalAmount: (raw['total_amount'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  // ════════════════════════════════════════════════════════════════
  // LISTINGS (marketplace.listings — composition over Marketplace)
  // ════════════════════════════════════════════════════════════════

  @override
  Future<List<BusinessListing>> fetchListings(String entityId) async {
    // Reuse the Marketplace repository read path, scoped by the verified
    // seller relationship: marketplace.listings.entity_id = the active
    // business entity.
    final listings = await _marketplace.fetchListings(sellerId: entityId);

    // Enrich canonical variant display names (core.item_variants).
    final variantIds = <String>{};
    for (final listing in listings) {
      final variantId = listing.variantId;
      if (variantId.isNotEmpty) variantIds.add(variantId);
    }

    Map<String, String> variantNames = const {};
    if (variantIds.isNotEmpty) {
      try {
        variantNames = await _dataSource.fetchVariantsByIds(variantIds);
      } catch (_) {
        // Best-effort enrichment — listings still render without it.
      }
    }

    return listings
        .map((listing) => BusinessListing.fromMarketplace(
              listing,
              variantName:
                  variantNames.containsKey(listing.variantId)
                      ? variantNames[listing.variantId]
                      : null,
            ))
        .toList();
  }

  // ════════════════════════════════════════════════════════════════
  // PAYMENTS (commerce.transactions)
  // ════════════════════════════════════════════════════════════════

  @override
  Future<List<BusinessTransaction>> fetchTransactions(String entityId) async {
    // The business of record is the entity's own `commerce.business_profiles`
    // (verified `supplier_id` FK relationship on transactions).
    final profileIds = await _dataSource.fetchEntityBusinessProfileIds(
      entityId,
    );
    if (profileIds.isEmpty) return const [];

    final rawRows = await _dataSource.fetchTransactionsBySuppliers(profileIds);

    return rawRows.map((raw) {
      return BusinessTransaction(
        id: raw['id']?.toString() ?? '',
        orderId: raw['order_id']?.toString() ?? '',
        supplierId: raw['supplier_id']?.toString() ?? '',
        amount: (raw['amount'] as num?)?.toDouble() ?? 0,
        currency: raw['currency']?.toString() ?? 'KES',
        paymentMethod: raw['payment_method']?.toString() ?? 'mpesa',
        paymentStatus: raw['payment_status']?.toString() ?? 'pending',
        transactionRef: raw['transaction_id']?.toString(),
        transactionDate: _parseDateTime(raw['transaction_date']),
        recordedBy: raw['recorded_by']?.toString(),
      );
    }).toList();
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
