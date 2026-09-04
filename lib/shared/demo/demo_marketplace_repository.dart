/// ============================================================
/// DEMO MARKETPLACE REPOSITORY — Guest mode sample data
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/demo/ = reusable demo data repositories
///
/// ✅ Responsibilities:
///   - Implement MarketplaceRepository interface
///   - Provide realistic sample listings for demo mode
///   - Never access Supabase
/// ============================================================
library;

import 'package:famhub_app/features/marketplace/domain/entities/listing.dart';
import 'package:famhub_app/features/marketplace/domain/entities/stock_item.dart';
import 'package:famhub_app/features/marketplace/domain/enums/listing_status.dart';
import 'package:famhub_app/features/marketplace/domain/repositories/marketplace_repository.dart';

/// Demo implementation of MarketplaceRepository.
/// Returns hardcoded sample data for the marketplace module.
class DemoMarketplaceRepository implements MarketplaceRepository {
  static final DateTime _baseDate = DateTime(2024, 10, 15);

  static final List<Listing> _sampleListings = [
    Listing(
      id: 'demo-listing-001',
      title: 'Fresh Snow Peas — Grade A',
      description: 'Premium snow peas freshly harvested. 45kg available.',
      pricePerUnit: 250.0,
      currency: 'KES',
      images: [],
      entityId: 'demo-farm-001',
      variantId: 'snow-peas',
      stockId: 'demo-stock-001',
      unitId: 'kg',
      status: ListingStatus.active,
      createdAt: _baseDate,
      updatedAt: _baseDate,
      sellerName: 'Green Valley Farm',
      locationName: 'Nairobi, Kenya',
      availableQuantity: 45.0,
      unitName: 'kg',
    ),
    Listing(
      id: 'demo-listing-002',
      title: 'Organic Tomatoes — Anna F1',
      description: 'Drip-irrigated, vine-ripened tomatoes. 120kg ready.',
      pricePerUnit: 180.0,
      currency: 'KES',
      images: [],
      entityId: 'demo-farm-001',
      variantId: 'tomatoes',
      stockId: 'demo-stock-002',
      unitId: 'kg',
      status: ListingStatus.active,
      createdAt: _baseDate.subtract(const Duration(days: 1)),
      updatedAt: _baseDate.subtract(const Duration(days: 1)),
      sellerName: 'Green Valley Farm',
      locationName: 'Nairobi, Kenya',
      availableQuantity: 120.0,
      unitName: 'kg',
    ),
    Listing(
      id: 'demo-listing-003',
      title: 'Free-Range Eggs — Kuroiler',
      description: 'Farm-fresh eggs from free-range Kuroiler chickens. 240 eggs available.',
      pricePerUnit: 35.0,
      currency: 'KES',
      images: [],
      entityId: 'demo-farm-001',
      variantId: 'eggs',
      stockId: 'demo-stock-003',
      unitId: 'piece',
      status: ListingStatus.active,
      createdAt: _baseDate.subtract(const Duration(days: 2)),
      updatedAt: _baseDate.subtract(const Duration(days: 2)),
      sellerName: 'Green Valley Farm',
      locationName: 'Nairobi, Kenya',
      availableQuantity: 240.0,
      unitName: 'piece',
    ),
    Listing(
      id: 'demo-listing-004',
      title: 'DAP Fertilizer — 50kg Bags',
      description: 'High-quality DAP fertilizer for crop nutrition. 20 bags available.',
      pricePerUnit: 3200.0,
      currency: 'KES',
      images: [],
      entityId: 'demo-supplier-001',
      variantId: 'dap-fertilizer',
      stockId: 'demo-stock-004',
      unitId: 'bag',
      status: ListingStatus.active,
      createdAt: _baseDate.subtract(const Duration(days: 3)),
      updatedAt: _baseDate.subtract(const Duration(days: 3)),
      sellerName: 'Agro Inputs Ltd',
      locationName: 'Nakuru, Kenya',
      availableQuantity: 20.0,
      unitName: 'bag',
    ),
    Listing(
      id: 'demo-listing-005',
      title: 'Saanen Goats — Breeding Stock',
      description: 'Pure Saanen goats, vaccinated and dewormed. 5 available.',
      pricePerUnit: 15000.0,
      currency: 'KES',
      images: [],
      entityId: 'demo-farm-001',
      variantId: 'goats',
      stockId: 'demo-stock-005',
      unitId: 'head',
      status: ListingStatus.active,
      createdAt: _baseDate.subtract(const Duration(days: 5)),
      updatedAt: _baseDate.subtract(const Duration(days: 5)),
      sellerName: 'Green Valley Farm',
      locationName: 'Nairobi, Kenya',
      availableQuantity: 5.0,
      unitName: 'head',
    ),
  ];

  @override
  Future<List<Listing>> fetchListings({
    String? category,
    String? searchQuery,
    String? sellerId,
    List<ListingStatus>? statusFilter,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    var filtered = List<Listing>.from(_sampleListings);

    if (category != null && category.isNotEmpty) {
      filtered = filtered.where((l) =>
        (l.description ?? '').toLowerCase().contains(category.toLowerCase())
      ).toList();
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((l) =>
        l.title.toLowerCase().contains(query) ||
        (l.description ?? '').toLowerCase().contains(query)
      ).toList();
    }

    if (sellerId != null) {
      filtered = filtered.where((l) => l.entityId == sellerId).toList();
    }

    if (statusFilter != null && statusFilter.isNotEmpty) {
      filtered = filtered.where((l) => statusFilter.contains(l.status)).toList();
    }

    return filtered;
  }

  @override
  Future<Listing?> fetchListingById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return _sampleListings.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Listing> createListing(Map<String, dynamic> payload) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final now = DateTime.now();
    return Listing(
      id: 'demo-listing-${now.millisecondsSinceEpoch}',
      title: payload['title'] as String? ?? 'New Listing',
      description: payload['description'] as String?,
      pricePerUnit: (payload['price_per_unit'] as num?)?.toDouble() ?? 0,
      currency: payload['currency'] as String? ?? 'KES',
      images: [],
      entityId: payload['entity_id'] as String? ?? 'demo-farm-001',
      variantId: payload['variant_id'] as String? ?? 'demo-variant',
      stockId: payload['stock_id'] as String? ?? 'demo-stock',
      unitId: payload['unit_id'] as String?,
      status: ListingStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<Listing> updateListing(String id, Map<String, dynamic> payload) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final existing = await fetchListingById(id);
    return existing?.copyWith(
      title: payload['title'] as String?,
      description: payload['description'] as String?,
      pricePerUnit: (payload['price_per_unit'] as num?)?.toDouble(),
    ) ?? Listing(
      id: id,
      title: payload['title'] as String? ?? 'Updated Listing',
      description: payload['description'] as String?,
      pricePerUnit: 0,
      currency: 'KES',
      images: [],
      entityId: 'demo-farm-001',
      variantId: 'demo-variant',
      stockId: 'demo-stock',
      status: ListingStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> archiveListing(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<Listing> publishListing(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final existing = await fetchListingById(id);
    return existing?.copyWith(status: ListingStatus.active) ?? Listing(
      id: id,
      title: 'Published Listing',
      pricePerUnit: 0,
      currency: 'KES',
      images: [],
      entityId: 'demo-farm-001',
      variantId: 'demo-variant',
      stockId: 'demo-stock',
      status: ListingStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> updateInventory({
    required String listingId,
    double? availableQuantity,
    double? reservedQuantity,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<Map<String, dynamic>> getSellerStats(String sellerId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return {
      'totalListings': 5,
      'activeListings': 5,
      'totalSales': 89000.0,
      'rating': 4.5,
    };
  }

  // ──────────────────────────────────────────────────────────
  // MANAGED-STOCK PUBLISHING (PHASE 1)
  // ──────────────────────────────────────────────────────────

  static final List<StockItem> _sampleStock = [
    const StockItem(
      id: 'demo-stock-001',
      entityId: 'demo-farm-001',
      variantId: 'snow-peas',
      productName: 'Snow Peas',
      unitId: 'kg',
      unitName: 'kg',
      locationId: 'demo-loc-nairobi',
      locationName: 'Nairobi, Kenya',
      quantity: 60,
      reservedQuantity: 15,
    ),
    const StockItem(
      id: 'demo-stock-002',
      entityId: 'demo-farm-001',
      variantId: 'tomatoes',
      productName: 'Tomatoes',
      unitId: 'kg',
      unitName: 'kg',
      locationId: 'demo-loc-nairobi',
      locationName: 'Nairobi, Kenya',
      quantity: 160,
      reservedQuantity: 40,
    ),
    const StockItem(
      id: 'demo-stock-003',
      entityId: 'demo-farm-001',
      variantId: 'eggs',
      productName: 'Free-Range Eggs',
      unitId: 'piece',
      unitName: 'piece',
      locationId: 'demo-loc-nairobi',
      locationName: 'Nairobi, Kenya',
      quantity: 300,
      reservedQuantity: 60,
    ),
    const StockItem(
      id: 'demo-stock-005',
      entityId: 'demo-farm-001',
      variantId: 'goats',
      productName: 'Saanen Goats',
      unitId: 'head',
      unitName: 'head',
      locationId: 'demo-loc-nairobi',
      locationName: 'Nairobi, Kenya',
      quantity: 8,
      reservedQuantity: 3,
    ),
  ];

  @override
  Future<List<StockItem>> fetchEligibleStock({String? searchQuery}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    var stock = _sampleStock.where((s) => s.isEligible).toList();
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      stock = stock
          .where((s) =>
              s.displayName.toLowerCase().contains(q) ||
              s.displayUnit.toLowerCase().contains(q) ||
              s.displayLocation.toLowerCase().contains(q))
          .toList();
    }
    return stock;
  }

  @override
  Future<StockItem?> fetchStockById(String stockId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    for (final stock in _sampleStock) {
      if (stock.id == stockId) return stock;
    }
    return null;
  }

  @override
  Future<Listing> publishListingFromStock({
    required String stockId,
    required double pricePerUnit,
    String? title,
    String? description,
    List<String> images = const [],
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final stock = await fetchStockById(stockId);
    final now = DateTime.now();
    return Listing(
      id: 'demo-listing-${now.millisecondsSinceEpoch}',
      title: (title != null && title.trim().isNotEmpty)
          ? title.trim()
          : stock?.displayName ?? 'Published listing',
      description: description,
      pricePerUnit: pricePerUnit,
      currency: 'KES',
      images: List<String>.from(images),
      entityId: stock?.entityId ?? 'demo-farm-001',
      variantId: stock?.variantId ?? 'demo-variant',
      stockId: stockId,
      unitId: stock?.unitId,
      locationId: stock?.locationId,
      unitName: stock?.unitName,
      locationName: stock?.locationName,
      status: ListingStatus.active,
      createdAt: now,
      updatedAt: now,
    );
  }
}
