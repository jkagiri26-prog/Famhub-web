import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/marketplace/domain/utils/seller_identity.dart';
import 'package:famhub_app/features/marketplace/infrastructure/data_sources/marketplace_remote_data_source.dart';
import 'package:famhub_app/features/marketplace/infrastructure/services/listing_mapper.dart';

void main() {
  group('public seller identity', () {
    test('entity seller displays entity name and first name only', () {
      expect(
        sellerIdentityDisplayName(
          entityName: 'JK Agrovet',
          firstName: 'James',
          isProfileOwned: false,
        ),
        'JK Agrovet · James',
      );
    });

    test('individual/profile-owned seller displays first name only', () {
      expect(
        sellerIdentityDisplayName(
          entityName: 'James Kamau',
          firstName: 'James',
          isProfileOwned: true,
        ),
        'James',
      );
    });

    test('profile-owned seller never falls back to a full entity name', () {
      expect(
        sellerIdentityDisplayName(
          entityName: 'James Kamau',
          firstName: null,
          isProfileOwned: true,
        ),
        '',
      );
    });

    test(
      'entity label is not manufactured when the entity name is missing',
      () {
        expect(
          sellerIdentityDisplayName(
            entityName: null,
            firstName: 'James',
            isProfileOwned: false,
          ),
          'James',
        );
      },
    );

    test('canonical entity names display consistently across entity types', () {
      const cases = {
        'Eden Farm': 'farm',
        'JK Agrovet': 'agrovet',
        'Acme Trading': 'trading_company',
        'Green Coop': 'cooperative',
        'Agri Services': 'service_provider',
      };
      for (final entry in cases.entries) {
        expect(
          sellerIdentityDisplayName(
            entityName: entry.key,
            firstName: 'James',
            isProfileOwned: false,
          ),
          '${entry.key} · James',
          reason: entry.value,
        );
      }
    });

    test('full profile name is not used as the public seller identity', () {
      final display = sellerIdentityDisplayName(
        entityName: 'JK Agrovet',
        firstName: 'James',
        isProfileOwned: false,
      );

      expect(display, isNot(contains('Kamau')));
      expect(display, 'JK Agrovet · James');
    });
  });

  group('listing public presentation mapping', () {
    Map<String, dynamic> baseJson() => {
      'id': 'listing-1',
      'title': 'Improved Kienyeji',
      'entity_id': 'entity-1',
      'variant_id': 'variant-1',
      'unit_id': 'unit-bird',
      'unit_name': 'bird',
      'location_id': 'location-mahiga',
      'location_name': 'KENYA · NYERI · OTHAYA · MAHIGA',
      'seller_name': 'JK Agrovet · James',
      'seller_entity_name': 'JK Agrovet',
      'seller_first_name': 'James',
      'seller_is_profile_owned': false,
    };

    test(
      'listing location remains the listing location, not seller location',
      () {
        final first = ListingMapper.fromJson({
          ...baseJson(),
          'location_id': 'location-mahiga',
          'location_name': 'KENYA · NYERI · OTHAYA · MAHIGA',
        });
        final second = ListingMapper.fromJson({
          ...baseJson(),
          'id': 'listing-2',
          'location_id': 'location-nakuru',
          'location_name': 'KENYA · NAKURU · NJORO · KIAMBU',
        });

        expect(first.locationId, 'location-mahiga');
        expect(first.locationName, 'KENYA · NYERI · OTHAYA · MAHIGA');
        expect(second.locationId, 'location-nakuru');
        expect(second.locationName, 'KENYA · NAKURU · NJORO · KIAMBU');
        expect(first.locationName, isNot(second.locationName));
      },
    );

    test('standalone listing availability comes from quantity_offered', () {
      final listing = ListingMapper.fromJson({
        ...baseJson(),
        'stock_id': null,
        'quantity_offered': 25,
      });

      expect(listing.isStandalone, isTrue);
      expect(listing.quantityOffered, 25);
      expect(listing.availableQuantity, 25);
    });

    test('stock-backed availability remains stock-derived', () {
      final listing = ListingMapper.fromJson({
        ...baseJson(),
        'stock_id': 'stock-1',
        'quantity_offered': 25,
        'available_quantity': 7,
        'stock': {'reserved_quantity': 2},
      });

      expect(listing.isStockBacked, isTrue);
      expect(listing.availableQuantity, 7);
      expect(listing.reservedQuantity, 2);
      expect(listing.availableQuantity, isNot(listing.quantityOffered));
    });

    test('public mapping exposes no phone or email contact fields', () {
      final listing = ListingMapper.fromJson({
        ...baseJson(),
        'contact_phone': '+254700000000',
        'contact_email': 'seller@example.com',
        'phone': '+254700000000',
        'email': 'seller@example.com',
        'supplier_name': 'James Kamau',
        'seller_name': 'JK Agrovet · James',
      });

      expect(listing.sellerName, 'JK Agrovet · James');
      expect(listing.sellerName, isNot(contains('@')));
      expect(listing.sellerName, isNot(contains('+254')));
      expect(listing.sellerName, isNot(contains('Kamau')));
    });
  });

  group('public seller identity RPC contract', () {
    test('uses the dedicated public listing seller RPC', () {
      expect(
        MarketplaceRemoteDataSource.publicListingSellerRpc,
        'get_public_listing_sellers',
      );
      expect(MarketplaceRemoteDataSource.publicListingSellerMaxIds, 200);
    });

    test('maps entity seller to entity name plus first name only', () {
      final identity =
          MarketplaceRemoteDataSource.publicSellerIdentityFromRpcRow({
            'listing_id': 'listing-1',
            'seller_entity_id': 'entity-1',
            'seller_entity_name': 'JK Agrovet',
            'seller_public_first_name': 'James',
            'seller_kind': 'entity',
            'phone': '+254700000000',
            'email': 'private@example.com',
            'last_name': 'Kamau',
          });

      expect(identity['seller_display_name'], 'JK Agrovet · James');
      expect(identity['seller_first_name'], 'James');
      expect(identity['seller_entity_name'], 'JK Agrovet');
      expect(identity['seller_is_profile_owned'], false);
      expect(identity['seller_display_name'], isNot(contains('Kamau')));
      expect(identity['seller_display_name'], isNot(contains('@')));
      expect(identity['seller_display_name'], isNot(contains('+254')));
    });

    test('entity without an authorized manager does not invent a name', () {
      final identity =
          MarketplaceRemoteDataSource.publicSellerIdentityFromRpcRow({
            'listing_id': 'listing-3',
            'seller_entity_id': 'entity-3',
            'seller_entity_name': 'Coop Without Manager',
            'seller_public_first_name': null,
            'seller_kind': 'entity',
            'owner_id': 'private-owner-id',
            'last_name': 'Private',
          });

      expect(identity['seller_display_name'], 'Coop Without Manager');
      expect(identity['seller_first_name'], isNull);
      expect(identity['seller_display_name'], isNot(contains('Private')));
    });

    test('maps individual seller to first name only', () {
      final identity =
          MarketplaceRemoteDataSource.publicSellerIdentityFromRpcRow({
            'listing_id': 'listing-2',
            'seller_entity_id': 'entity-2',
            'seller_entity_name': null,
            'seller_public_first_name': 'Alice',
            'seller_kind': 'individual',
            'last_name': 'Wanjiku',
          });

      expect(identity['seller_display_name'], 'Alice');
      expect(identity['seller_first_name'], 'Alice');
      expect(identity['seller_entity_name'], isNull);
      expect(identity['seller_is_profile_owned'], true);
      expect(identity['seller_display_name'], isNot(contains('Wanjiku')));
    });
  });
}
