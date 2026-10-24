import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/farm_management/domain/utils/activity_type_scope.dart';

void main() {
  group('activityTypeScope', () {
    test('catalog rows with livestock categories map to livestock', () {
      const rows = <({String name, String? category})>[
        (name: 'feeding', category: 'livestock_management'),
        (name: 'vaccination', category: 'livestock_health'),
        (name: 'Milking', category: 'Dairy'),
      ];
      for (final row in rows) {
        expect(
          activityTypeScope(name: row.name, category: row.category),
          ActivityTypeScope.livestock,
          reason: '${row.name} (${row.category}) should be livestock-only',
        );
      }
    });

    test('catalog rows with crop categories map to crop', () {
      const rows = <({String name, String? category})>[
        (name: 'Fertilizer Application', category: 'Crop'),
        (name: 'Irrigation', category: 'Crop'),
        (name: 'spraying', category: 'crop_protection'),
        (name: 'watering', category: 'irrigation'),
        (name: 'pest_control', category: 'protection'),
        (name: 'weeding', category: 'maintenance'),
        (name: 'Planting', category: 'Crop'),
      ];
      for (final row in rows) {
        expect(
          activityTypeScope(name: row.name, category: row.category),
          ActivityTypeScope.crop,
          reason: '${row.name} (${row.category}) should be crop-only',
        );
      }
    });

    test('harvesting is crop-scoped even though category is "harvest"', () {
      expect(
        activityTypeScope(name: 'harvesting', category: 'harvest'),
        ActivityTypeScope.crop,
      );
    });

    test('catch-all and unknown-category rows map to both', () {
      const rows = <({String name, String? category})>[
        (name: 'General', category: 'general'),
        (name: 'Other', category: 'general'),
        (name: 'Inspection', category: 'general'),
        (name: 'Transport', category: 'general'),
        (name: 'Maintenance', category: 'general'),
        (name: 'Mystery Type', category: null),
      ];
      for (final row in rows) {
        expect(
          activityTypeScope(name: row.name, category: row.category),
          ActivityTypeScope.both,
          reason: '${row.name} (${row.category}) should be offered for both',
        );
      }
    });

    test('preset template fallback rows resolve without a live catalog', () {
      expect(
        activityTypeScope(name: 'Maize Planting', category: 'crops'),
        ActivityTypeScope.crop,
      );
      expect(
        activityTypeScope(name: 'Poultry Feeding', category: 'livestock'),
        ActivityTypeScope.livestock,
      );
      expect(
        activityTypeScope(name: 'Fish Feeding', category: 'livestock'),
        ActivityTypeScope.livestock,
      );
    });
  });

  group('activityTypeAppliesTo', () {
    test('both-scope types apply to every asset type', () {
      expect(
        activityTypeAppliesTo(
            name: 'Other', category: 'general', assetType: kAssetTypeCrop),
        isTrue,
      );
      expect(
        activityTypeAppliesTo(
            name: 'Other',
            category: 'general',
            assetType: kAssetTypeLivestock),
        isTrue,
      );
    });

    test('crop-only types are hidden from livestock selection', () {
      expect(
        activityTypeAppliesTo(
            name: 'Planting', category: 'Crop', assetType: kAssetTypeCrop),
        isTrue,
      );
      expect(
        activityTypeAppliesTo(
            name: 'Planting',
            category: 'Crop',
            assetType: kAssetTypeLivestock),
        isFalse,
      );
    });

    test('livestock-only types are hidden from crop selection', () {
      expect(
        activityTypeAppliesTo(
            name: 'Milking',
            category: 'Dairy',
            assetType: kAssetTypeLivestock),
        isTrue,
      );
      expect(
        activityTypeAppliesTo(
            name: 'Milking', category: 'Dairy', assetType: kAssetTypeCrop),
        isFalse,
      );
    });
  });
}
