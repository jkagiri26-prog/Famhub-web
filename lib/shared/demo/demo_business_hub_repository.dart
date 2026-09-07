/// ============================================================
/// DEMO BUSINESS HUB REPOSITORY (GUEST / UNAUTHENTICATED)
/// ============================================================
///
/// Returns static sample business data so guests can preview the
/// Business Hub without a backend session. Never used when the user is
/// authenticated.
///
/// No guest/demo logic exists in any widget — the session-aware
/// repository provider swaps this in.
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import 'package:famhub_app/features/business_hub/domain/entities/business_entity.dart';
import 'package:famhub_app/features/business_hub/domain/entities/business_listing.dart';
import 'package:famhub_app/features/business_hub/domain/entities/business_profile.dart';
import 'package:famhub_app/features/business_hub/domain/entities/business_transaction.dart';
import 'package:famhub_app/features/business_hub/domain/entities/inventory_item.dart';
import 'package:famhub_app/features/business_hub/domain/entities/purchase_order.dart';
import 'package:famhub_app/features/business_hub/domain/entities/sales_order.dart';
import 'package:famhub_app/features/business_hub/domain/entities/sales_order_line.dart';
import 'package:famhub_app/features/business_hub/domain/enums/business_entity_type.dart';
import 'package:famhub_app/features/business_hub/domain/repositories/business_hub_repository.dart';
import 'package:famhub_app/features/marketplace/domain/enums/listing_status.dart';

class DemoBusinessHubRepository implements BusinessHubRepository {
  static const List<BusinessEntity> _demoBusinesses = [
    BusinessEntity(
      id: 'demo-entity-1',
      name: 'Kagiri Fresh Traders',
      slug: 'kagiri-fresh-traders',
      entityType: BusinessEntityType.tradingCompany,
      verificationStatus: 'verified',
      legalOwnerType: 'individual',
    ),
    BusinessEntity(
      id: 'demo-entity-2',
      name: 'Kiboko Agrovet',
      slug: 'kiboko-agrovet',
      entityType: BusinessEntityType.agrovet,
      verificationStatus: 'pending',
      legalOwnerType: 'business',
    ),
  ];

  @override
  Future<List<BusinessEntity>> fetchMyBusinesses() async {
    return _demoBusinesses;
  }

  @override
  Future<BusinessProfile?> fetchBusinessProfile(String entityId) async {
    if (entityId != 'demo-entity-1') return null;
    return const BusinessProfile(
      id: 'demo-profile-1',
      entityId: 'demo-entity-1',
      entityType: 'trader',
      supplierName: 'Kagiri Fresh Traders',
      contactPerson: 'Jane Kagiri',
      verificationStatus: 'verified',
      rating: 4.6,
    );
  }

  @override
  Future<List<InventoryItem>> fetchInventory(String entityId) async {
    if (entityId != 'demo-entity-1') return const [];
    return const [
      InventoryItem(
        id: 'demo-stock-1',
        entityId: 'demo-entity-1',
        variantId: 'demo-variant-1',
        productId: 'demo-item-1',
        displayName: 'Tomato',
        unitId: 'demo-unit-1',
        unitName: 'kg',
        locationId: 'demo-loc-1',
        locationName: 'Nairobi Wholesale',
        quantity: 240,
        reservedQuantity: 40,
        status: 'active',
      ),
      InventoryItem(
        id: 'demo-stock-2',
        entityId: 'demo-entity-1',
        variantId: 'demo-variant-2',
        productId: 'demo-item-2',
        displayName: 'Maize (White)',
        unitId: 'demo-unit-2',
        unitName: 'bag',
        locationId: 'demo-loc-2',
        locationName: 'Eldoret Depot',
        quantity: 120,
        reservedQuantity: 0,
        status: 'active',
      ),
      InventoryItem(
        id: 'demo-stock-3',
        entityId: 'demo-entity-1',
        variantId: 'demo-variant-3',
        productId: 'demo-item-3',
        displayName: 'Dairy Meal',
        unitId: 'demo-unit-3',
        unitName: 'kg',
        locationId: null,
        locationName: null,
        quantity: 0,
        reservedQuantity: 0,
        status: 'depleted',
      ),
    ];
  }

  @override
  Future<List<PurchaseOrder>> fetchPurchaseOrders(String entityId) async {
    if (entityId != 'demo-entity-1') return const [];
    return [
      PurchaseOrder(
        id: 'demo-po-1',
        supplierId: 'demo-profile-2',
        supplierName: 'Green Valley Farm Supplies',
        createdBy: 'demo-profile-1',
        status: 'pending',
        totalAmount: 184500,
        currency: 'KES',
        notes: 'Weekly produce restock',
        createdAt: _demoTime(2026, 3, 2),
      ),
      PurchaseOrder(
        id: 'demo-po-2',
        supplierId: 'demo-profile-3',
        supplierName: 'Central Agro Ltd',
        createdBy: 'demo-profile-1',
        status: 'received',
        totalAmount: 96000,
        currency: 'KES',
        createdAt: _demoTime(2026, 2, 20),
      ),
      PurchaseOrder(
        id: 'demo-po-3',
        supplierId: null,
        supplierName: null,
        createdBy: 'demo-profile-1',
        status: 'cancelled',
        totalAmount: 0,
        currency: 'KES',
        createdAt: _demoTime(2026, 1, 30),
      ),
    ];
  }

  @override
  Future<List<SalesOrder>> fetchSalesOrders(String entityId) async {
    if (entityId != 'demo-entity-1') return const [];
    return [
      SalesOrder(
        id: 'demo-order-1',
        buyerId: 'demo-buyer-1',
        buyerName: 'Savanna Hotel',
        listingId: 'demo-listing-1',
        supplierId: 'demo-profile-1',
        quantity: 120,
        totalAmount: 78000,
        status: 'confirmed',
        paymentStatus: 'pending',
        paymentMode: 'direct_supplier',
        orderDate: _demoTime(2026, 3, 4),
      ),
      SalesOrder(
        id: 'demo-order-2',
        buyerId: 'demo-buyer-2',
        buyerName: 'Naivas Fresh Desk',
        listingId: 'demo-listing-2',
        supplierId: 'demo-profile-1',
        quantity: 60,
        totalAmount: 36000,
        status: 'delivered',
        paymentStatus: 'completed',
        paymentMode: 'platform',
        orderDate: _demoTime(2026, 2, 27),
        deliveryDate: _demoTime(2026, 2, 28),
      ),
      SalesOrder(
        id: 'demo-order-3',
        buyerId: 'demo-buyer-3',
        buyerName: 'Kimathi Café',
        listingId: 'demo-listing-3',
        supplierId: 'demo-profile-1',
        quantity: 10,
        totalAmount: 12500,
        status: 'cancelled',
        paymentStatus: 'refunded',
        paymentMode: 'escrow',
        orderDate: _demoTime(2026, 2, 10),
      ),
    ];
  }

  @override
  Future<List<SalesOrderLine>> fetchOrderItems(String orderId) async {
    if (orderId != 'demo-order-1') return const [];
    return [
      const SalesOrderLine(
        id: 'demo-line-1',
        orderId: 'demo-order-1',
        listingId: 'demo-listing-1',
        variantId: 'demo-variant-1',
        variantName: 'Tomato',
        unitId: 'demo-unit-1',
        unitName: 'kg',
        quantity: 120,
        pricePerUnit: 650,
        totalAmount: 78000,
      ),
    ];
  }

  @override
  Future<List<BusinessListing>> fetchListings(String entityId) async {
    if (entityId != 'demo-entity-1') return const [];
    return [
      const BusinessListing(
        id: 'demo-listing-1',
        title: 'Fresh Tomatoes — Nairobi',
        entityId: 'demo-entity-1',
        variantId: 'demo-variant-1',
        variantName: 'Tomato',
        unitId: 'demo-unit-1',
        unitName: 'kg',
        locationName: 'Nairobi Wholesale',
        pricePerUnit: 650,
        currency: 'KES',
        availableQuantity: 200,
        status: ListingStatus.active,
        isPromoted: true,
      ),
      const BusinessListing(
        id: 'demo-listing-2',
        title: 'White Maize (Bags)',
        entityId: 'demo-entity-1',
        variantId: 'demo-variant-2',
        variantName: 'Maize (White)',
        unitName: 'bag',
        locationName: 'Eldoret Depot',
        pricePerUnit: 4800,
        currency: 'KES',
        availableQuantity: 120,
        status: ListingStatus.active,
      ),
      const BusinessListing(
        id: 'demo-listing-3',
        title: 'Dairy Meal',
        entityId: 'demo-entity-1',
        variantId: 'demo-variant-3',
        variantName: 'Dairy Meal',
        unitName: 'kg',
        pricePerUnit: 2500,
        currency: 'KES',
        availableQuantity: 0,
        status: ListingStatus.paused,
      ),
    ];
  }

  @override
  Future<List<BusinessTransaction>> fetchTransactions(String entityId) async {
    if (entityId != 'demo-entity-1') return const [];
    return [
      BusinessTransaction(
        id: 'demo-txn-1',
        orderId: 'demo-order-2',
        supplierId: 'demo-profile-1',
        amount: 36000,
        currency: 'KES',
        paymentMethod: 'mpesa',
        paymentStatus: 'completed',
        transactionRef: 'SJC2X9M4PQ',
        transactionDate: _demoTimeRef(2026, 2, 28, 14, 20),
        recordedBy: 'system',
      ),
      BusinessTransaction(
        id: 'demo-txn-2',
        orderId: 'demo-order-1',
        supplierId: 'demo-profile-1',
        amount: 78000,
        currency: 'KES',
        paymentMethod: 'bank',
        paymentStatus: 'pending',
        transactionRef: 'BANK-8821-AA',
        transactionDate: _demoTimeRef(2026, 3, 4, 9, 5),
        recordedBy: 'buyer',
      ),
      BusinessTransaction(
        id: 'demo-txn-3',
        orderId: 'demo-order-3',
        supplierId: 'demo-profile-1',
        amount: 12500,
        currency: 'KES',
        paymentMethod: 'mpesa',
        paymentStatus: 'refunded',
        transactionRef: 'RFD-44ZQ-77',
        transactionDate: _demoTimeRef(2026, 2, 12, 16, 40),
        recordedBy: 'system',
      ),
    ];
  }
}

DateTime _demoTime(int year, int month, int day) =>
    DateTime(year, month, day);

DateTime _demoTimeRef(int year, int month, int day, int hour, int minute) =>
    DateTime(year, month, day, hour, minute);
