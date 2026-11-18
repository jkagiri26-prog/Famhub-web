import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final featureAccess = File(
    'lib/core/feature_flags/application/providers/feature_access_provider.dart',
  ).readAsStringSync();
  final decisionEngine = File(
    'lib/core/access/access_decision_engine.dart',
  ).readAsStringSync();
  final resolverRepository = File(
    'lib/core/subscription/infrastructure/repositories/subscription_entitlements_repository.dart',
  ).readAsStringSync();
  final centre = File(
    'lib/features/subscription_billing/presentation/pages/subscription_centre_page.dart',
  ).readAsStringSync();

  group('Shared entitlement integration', () {
    test('paid modules consume canonical capabilities', () {
      expect(featureAccess, contains('subscriptionEntitlementsProvider'));
      expect(featureAccess, contains('entitlements.allowsModule(featureKey)'));
      expect(featureAccess, contains('requiresPaidEntitlement'));
      expect(featureAccess, contains('module.requiresSubscription'));
      expect(featureAccess, contains('module.premiumOnly'));
    });

    test('unverified capabilities fail closed for paid modules', () {
      expect(
        featureAccess,
        contains('entitlements == null || !entitlements.allowsModule'),
      );
      expect(featureAccess, contains('return false'));
    });

    test('roles and free access are not replaced by subscription checks', () {
      expect(decisionEngine, contains('bool checkTier = true'));
      expect(featureAccess, contains('role: appContext.role'));
      expect(featureAccess, contains('checkTier: !requiresPaidEntitlement'));
      expect(featureAccess, contains('else {'));
      expect(
        featureAccess,
        contains('subscriptionAccess.hasAccess(featureKey)'),
      );
    });

    test('Flutter uses the backend resolver and no hardcoded plans', () {
      expect(
        resolverRepository,
        contains('resolve_my_subscription_entitlements'),
      );
      expect(resolverRepository, isNot(contains('annual')));
      expect(resolverRepository, isNot(contains('features_json')));
      expect(resolverRepository, isNot(contains('service_role')));
      expect(resolverRepository, isNot(contains('p_amount')));
    });

    test('confirmed activation refreshes shared entitlements', () {
      expect(centre, contains('subscriptionEntitlementsProvider'));
      expect(
        centre,
        contains('ref.invalidate(subscriptionEntitlementsProvider)'),
      );
      expect(centre, isNot(contains('confirm_annual_subscription')));
    });
  });
}
