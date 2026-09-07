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
import 'package:famhub_app/features/business_hub/domain/entities/business_profile.dart';
import 'package:famhub_app/features/business_hub/domain/entities/inventory_item.dart';
import 'package:famhub_app/features/business_hub/domain/enums/business_entity_type.dart';
import 'package:famhub_app/features/business_hub/domain/repositories/business_hub_repository.dart';

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
}
