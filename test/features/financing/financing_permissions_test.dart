import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/financing/config/permissions.dart';

void main() {
  group('Financing permission contract', () {
    test('permission keys use finance.* backend codes', () {
      expect(FinancingPermissions.manageProviders, 'finance.manage_providers');
      expect(FinancingPermissions.verifyProviders, 'finance.verify_providers');
      expect(FinancingPermissions.manageProducts, 'finance.manage_products');
      expect(FinancingPermissions.reviewProducts, 'finance.review_products');
      expect(FinancingPermissions.publishProducts, 'finance.publish_products');
    });

    test('registry contains the five Phase 1 catalog permissions', () {
      expect(FinancingPermissions.all, hasLength(5));
      expect(
        FinancingPermissions.all,
        containsAll(<String>[
          'finance.manage_providers',
          'finance.verify_providers',
          'finance.manage_products',
          'finance.review_products',
          'finance.publish_products',
        ]),
      );
    });

    test('provider and product lifecycles use separate permission keys', () {
      expect(
        FinancingPermissions.all.where((code) => code.contains('provider')),
        hasLength(2),
      );
      expect(
        FinancingPermissions.all.where((code) => code.contains('product')),
        hasLength(3),
      );
    });

    test('registry is unique and every code is module-scoped finance.*', () {
      expect(FinancingPermissions.all.toSet(), hasLength(5));
      for (final code in FinancingPermissions.all) {
        expect(code, startsWith('finance.'));
        expect(code.split('.').length, 2);
        expect(RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(code.split('.').first), isTrue);
        expect(RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(code.split('.').last), isTrue);
      }
    });
  });
}
