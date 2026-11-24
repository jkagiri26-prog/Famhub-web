import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/context_engine/controllers/context_controller.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/utils/farm_listing_origin.dart';
import 'package:famhub_app/features/marketplace/application/providers/marketplace_provider.dart';
import 'package:famhub_app/features/marketplace/domain/entities/listing.dart';
import 'package:famhub_app/features/marketplace/domain/enums/listing_status.dart';
import 'package:famhub_app/features/marketplace/domain/repositories/marketplace_repository.dart';

FarmEntity _farm({
  String? entityId = 'farm-core-entity',
  String? wardId = 'ward-mahiga',
  String? subCountyId = 'sub-county-othaya',
  String? countyId = 'county-nyeri',
}) {
  return FarmEntity(
    id: 'farm-record-id',
    entityId: entityId,
    farmName: 'Gold Farm',
    wardId: wardId,
    subCountyId: subCountyId,
    countyId: countyId,
    isActive: true,
    isVerified: true,
  );
}

Listing _listing({
  String id = 'listing-1',
  String entityId = 'farm-core-entity',
  String? locationId = 'ward-mahiga',
}) {
  return Listing(
    id: id,
    title: 'Maize',
    pricePerUnit: 100,
    currency: 'KES',
    images: const [],
    entityId: entityId,
    variantId: 'variant-1',
    unitId: 'unit-1',
    locationId: locationId,
    status: ListingStatus.active,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

class _FixedContextController extends ContextController {
  _FixedContextController(this.context);

  final EntityContext context;

  @override
  EntityContext build() => context;
}

class _FakeMarketplaceRepository implements MarketplaceRepository {
  final List<Map<String, dynamic>> createdPayloads = [];

  @override
  Future<List<Listing>> fetchListings({
    String? category,
    String? searchQuery,
    String? sellerId,
    List<ListingStatus>? statusFilter,
  }) async {
    return const [];
  }

  @override
  Future<Listing> createListing(Map<String, dynamic> payload) async {
    createdPayloads.add(Map<String, dynamic>.from(payload));
    return _listing(
      id: 'new-listing',
      entityId: payload['entity_id']?.toString() ?? '',
      locationId: payload['location_id']?.toString(),
    );
  }

  @override
  Future<Listing> setListingStatus({
    required String listingId,
    required ListingStatus status,
  }) async {
    return _listing(id: listingId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('${invocation.memberName} is not used');
  }
}

({ProviderContainer container, _FakeMarketplaceRepository repository})
_fixture() {
  final repository = _FakeMarketplaceRepository();
  final container = ProviderContainer(
    overrides: [
      marketplaceRepositoryProvider.overrideWithValue(repository),
      contextProvider.overrideWith(
        () => _FixedContextController(
          const EntityContext(
            entityId: 'personal-active-entity',
            roleId: 'role-1',
            isGuest: false,
            isLoading: false,
          ),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, repository: repository);
}

Future<void> _initialize(ProviderContainer container) async {
  await container.read(marketplaceProvider.future);
}

void main() {
  group('farm listing origin', () {
    test('uses the farm core entity, never the farm record id', () {
      final farm = _farm();

      expect(farmListingSellerEntityId(farm), 'farm-core-entity');
      expect(farmListingSellerEntityId(farm), isNot(farm.id));
    });

    test('uses ward, then sub-county, then county from the same farm', () {
      expect(farmListingLocationId(_farm()), 'ward-mahiga');
      expect(farmListingLocationId(_farm(wardId: null)), 'sub-county-othaya');
      expect(
        farmListingLocationId(_farm(wardId: null, subCountyId: null)),
        'county-nyeri',
      );
    });

    test('missing farm entity remains missing for fail-safe handling', () {
      expect(farmListingSellerEntityId(_farm(entityId: null)), isNull);
    });
  });

  group('standalone listing seller entity', () {
    test(
      'submits the explicitly selected farm entity, not active context',
      () async {
        final fixture = _fixture();
        await _initialize(fixture.container);

        await fixture.container
            .read(marketplaceProvider.notifier)
            .publishStandaloneListing(
              title: 'Maize',
              pricePerUnit: 100,
              variantId: 'variant-1',
              unitId: 'unit-1',
              quantityOffered: 10,
              locationId: 'ward-mahiga',
              sellerEntityId: 'farm-core-entity',
            );

        final payload = fixture.repository.createdPayloads.single;
        expect(payload['entity_id'], 'farm-core-entity');
        expect(payload['entity_id'], isNot('personal-active-entity'));
        expect(payload['entity_id'], isNot('farm-record-id'));
        expect(payload['location_id'], 'ward-mahiga');
        expect(payload['stock_id'], isNull);
      },
    );

    test(
      'generic listing can explicitly use the active personal entity',
      () async {
        final fixture = _fixture();
        await _initialize(fixture.container);

        await fixture.container
            .read(marketplaceProvider.notifier)
            .publishStandaloneListing(
              title: 'Personal Sale',
              pricePerUnit: 100,
              variantId: 'variant-1',
              unitId: 'unit-1',
              quantityOffered: 1,
              locationId: 'manual-location',
              sellerEntityId: 'personal-active-entity',
            );

        expect(
          fixture.repository.createdPayloads.single['entity_id'],
          'personal-active-entity',
        );
      },
    );

    test('missing seller entity prevents repository submission', () async {
      final fixture = _fixture();
      await _initialize(fixture.container);

      await expectLater(
        fixture.container
            .read(marketplaceProvider.notifier)
            .publishStandaloneListing(
              title: 'Missing Entity',
              pricePerUnit: 100,
              variantId: 'variant-1',
              unitId: 'unit-1',
              quantityOffered: 1,
              locationId: 'ward-mahiga',
              sellerEntityId: '   ',
            ),
        throwsException,
      );
      expect(fixture.repository.createdPayloads, isEmpty);
    });
  });
}
