import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/marketplace/domain/utils/seller_identity.dart';
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
}
