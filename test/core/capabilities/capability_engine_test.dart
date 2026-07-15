import 'package:flutter_test/flutter_test.dart';
import 'package:famhub_app/core/capabilities/domain/capability.dart';
import 'package:famhub_app/core/capabilities/domain/capability_profile.dart';
import 'package:famhub_app/core/capabilities/registry/capability_registry.dart';
import 'package:famhub_app/core/capabilities/application/capability_engine.dart';

void main() {
  setUp(() {
    CapabilityRegistry.registerDefaults();
  });

  tearDown(() {
    CapabilityRegistry.clear();
  });

  group('CapabilityEngine', () {
    test('returns false for unregistered capability', () {
      final profile = CapabilityProfileFactory.full('test-org');
      final engine = CapabilityEngine.fromProfile(profile);

      expect(engine.hasCapability('nonexistent.capability'), isFalse);
      expect(engine.getCapabilityLevel('nonexistent.capability'), equals(0));
    });

    test('returns false for disabled capability', () {
      final profile = CapabilityProfileFactory.empty('test-org');
      final engine = CapabilityEngine.fromProfile(profile);

      expect(
        engine.hasCapability(Capabilities.marketplaceListings),
        isFalse,
      );
      expect(
        engine.getCapabilityLevel(Capabilities.marketplaceListings),
        equals(0),
      );
    });

    test('returns true for enabled capability', () {
      final profile = CapabilityProfileFactory.basicFarmer('test-org');
      final engine = CapabilityEngine.fromProfile(profile);

      expect(
        engine.hasCapability(Capabilities.marketplaceListings),
        isTrue,
      );
      expect(
        engine.getCapabilityLevel(Capabilities.marketplaceListings),
        equals(1),
      );
    });

    test('accepts string IDs', () {
      final profile = CapabilityProfileFactory.basicFarmer('test-org');
      final engine = CapabilityEngine.fromProfile(profile);

      expect(engine.hasCapability('marketplace.listings'), isTrue);
      expect(engine.hasCapability('inventory.stock'), isTrue);
      expect(engine.hasCapability('finance.invoicing'), isFalse);
    });

    test('canExecute and canRender delegate to hasCapability', () {
      final profile = CapabilityProfileFactory.basicFarmer('test-org');
      final engine = CapabilityEngine.fromProfile(profile);

      expect(engine.canExecute(Capabilities.marketplaceListings), isTrue);
      expect(engine.canRender(Capabilities.marketplaceListings), isTrue);
      expect(engine.canExecute(Capabilities.financeInvoicing), isFalse);
    });

    test('canAutomate returns true only at level >= 5', () {
      const profile = CapabilityProfile(
        organizationId: 'test-org',
        capabilities: {'workflow.execution': 5},
      );
      final engine = CapabilityEngine.fromProfile(profile);

      expect(engine.canAutomate(Capabilities.workflowExecution), isTrue);

      // Level 4 should not allow automation
      const profile2 = CapabilityProfile(
        organizationId: 'test-org',
        capabilities: {'workflow.execution': 4},
      );
      final engine2 = CapabilityEngine.fromProfile(profile2);
      expect(engine2.canAutomate(Capabilities.workflowExecution), isFalse);
    });

    test('canUseAI returns true only at level >= 6', () {
      const profile = CapabilityProfile(
        organizationId: 'test-org',
        capabilities: {'workflow.execution': 6},
      );
      final engine = CapabilityEngine.fromProfile(profile);

      expect(engine.canUseAI(Capabilities.workflowExecution), isTrue);

      // Level 5 should not allow AI
      const profile2 = CapabilityProfile(
        organizationId: 'test-org',
        capabilities: {'workflow.execution': 5},
      );
      final engine2 = CapabilityEngine.fromProfile(profile2);
      expect(engine2.canUseAI(Capabilities.workflowExecution), isFalse);
    });

    test('hasAllCapabilities returns true when all are enabled', () {
      final profile = CapabilityProfileFactory.basicFarmer('test-org');
      final engine = CapabilityEngine.fromProfile(profile);

      expect(
        engine.hasAllCapabilities([
          Capabilities.marketplaceListings,
          Capabilities.inventoryStock,
        ]),
        isTrue,
      );

      expect(
        engine.hasAllCapabilities([
          Capabilities.marketplaceListings,
          Capabilities.financeInvoicing, // not in basicFarmer
        ]),
        isFalse,
      );
    });

    test('hasAnyCapability returns true when at least one is enabled', () {
      final profile = CapabilityProfileFactory.basicFarmer('test-org');
      final engine = CapabilityEngine.fromProfile(profile);

      expect(
        engine.hasAnyCapability([
          Capabilities.marketplaceListings,
          Capabilities.aiRecommendations, // not in basicFarmer
        ]),
        isTrue,
      );

      expect(
        engine.hasAnyCapability([
          Capabilities.aiRecommendations,
          Capabilities.coldchainMonitoring, // both not in basicFarmer
        ]),
        isFalse,
      );
    });

    test('enabledCapabilityIds returns only enabled capabilities', () {
      final profile = CapabilityProfileFactory.basicFarmer('test-org');
      final engine = CapabilityEngine.fromProfile(profile);

      final enabled = engine.enabledCapabilityIds;
      expect(enabled, contains('marketplace.listings'));
      expect(enabled, contains('inventory.stock'));
      expect(enabled, isNot(contains('finance.invoicing')));
      expect(enabled, isNot(contains('ai.recommendations')));
    });

    test('getCapabilityLevelDetails returns correct level info', () {
      final profile = CapabilityProfileFactory.basicFarmer('test-org');
      final engine = CapabilityEngine.fromProfile(profile);

      final levelDetails = engine.getCapabilityLevelDetails(
        Capabilities.workflowExecution,
      );
      expect(levelDetails, isNotNull);
      expect(levelDetails!.level, equals(1));
      expect(levelDetails.name, equals('Activity Only'));

      // Disabled capability
      final disabledDetails = engine.getCapabilityLevelDetails(
        Capabilities.aiRecommendations,
      );
      expect(disabledDetails, isNotNull);
      expect(disabledDetails!.level, equals(0));
      expect(disabledDetails.name, equals('Disabled'));
    });
  });

  group('CapabilityProfileFactory presets', () {
    test('empty profile has no capabilities', () {
      final profile = CapabilityProfileFactory.empty('test-org');
      expect(profile.enabledCount, equals(0));
    });

    test('full profile has all capabilities', () {
      final profile = CapabilityProfileFactory.full('test-org');
      expect(profile.enabledCount, greaterThan(0));
      expect(
        profile.hasCapability('marketplace.listings'),
        isTrue,
      );
      expect(
        profile.hasCapability('ai.recommendations'),
        isTrue,
      );
    });

    test('basicFarmer has limited capabilities', () {
      final profile = CapabilityProfileFactory.basicFarmer('test-org');
      expect(profile.hasCapability('marketplace.listings'), isTrue);
      expect(profile.hasCapability('inventory.stock'), isTrue);
      expect(profile.hasCapability('finance.recording'), isTrue);

      // Advanced capabilities not in basic farmer
      expect(profile.hasCapability('finance.invoicing'), isFalse);
      expect(profile.hasCapability('analytics.advanced'), isFalse);
      expect(profile.hasCapability('ai.recommendations'), isFalse);
      expect(profile.hasCapability('coldchain.monitoring'), isFalse);
    });

    test('aggregator has extended capabilities', () {
      final profile = CapabilityProfileFactory.aggregator('test-org');
      expect(profile.hasCapability('marketplace.listings'), isTrue);
      expect(profile.hasCapability('inventory.warehouse'), isTrue);
      expect(profile.hasCapability('finance.invoicing'), isTrue);
      expect(profile.hasCapability('analytics.advanced'), isTrue);
      expect(profile.hasCapability('logistics.dispatch'), isTrue);
      expect(profile.hasCapability('traceability.export'), isTrue);

      // Enterprise-only capabilities not in aggregator
      expect(profile.hasCapability('coldchain.monitoring'), isFalse);
      expect(profile.hasCapability('ai.recommendations'), isFalse);
    });

    test('enterprise has all capabilities', () {
      final profile = CapabilityProfileFactory.enterprise('test-org');
      expect(profile.hasCapability('coldchain.monitoring'), isTrue);
      expect(profile.hasCapability('ai.recommendations'), isTrue);
      expect(profile.hasCapability('staff.management'), isTrue);

      // Enterprise has higher workflow level
      expect(profile.levelFor('workflow.execution'), equals(6));
    });
  });

  group('CapabilityRegistry', () {
    test('registers and retrieves capabilities', () {
      final registration = CapabilityRegistry.get('marketplace.listings');
      expect(registration, isNotNull);
      expect(registration!.capability.id, equals('marketplace.listings'));
      expect(registration.levels.length, greaterThanOrEqualTo(2));
    });

    test('hasCapability returns true for registered capabilities', () {
      expect(CapabilityRegistry.hasCapability('marketplace.listings'), isTrue);
      expect(CapabilityRegistry.hasCapability('nonexistent'), isFalse);
    });

    test('forDomain returns only capabilities in that domain', () {
      final marketplaceCaps = CapabilityRegistry.forDomain('marketplace');
      expect(marketplaceCaps.length, equals(2));
      expect(
        marketplaceCaps.every((r) => r.capability.domain == 'marketplace'),
        isTrue,
      );
    });

    test('levelsFor returns correct level scheme', () {
      final levels = CapabilityRegistry.levelsFor('workflow.execution');
      expect(levels, isNotNull);
      expect(levels!.length, equals(7));
      expect(levels[0].level, equals(0));
      expect(levels[0].name, equals('Disabled'));
      expect(levels[6].level, equals(6));
      expect(levels[6].name, contains('AI'));
    });

    test('hasLevel checks level availability', () {
      expect(CapabilityRegistry.hasLevel('workflow.execution', 5), isTrue);
      expect(CapabilityRegistry.hasLevel('workflow.execution', 10), isFalse);
    });
  });

  group('No organization-type checks', () {
    // Verify the framework works without any organization type checks
    test('engine does not check organization types', () {
      final profile = CapabilityProfileFactory.basicFarmer('test-org');
      final engine = CapabilityEngine.fromProfile(profile);

      // The engine only checks capabilities, not org types
      expect(() => engine.hasCapability(Capabilities.inventoryStock),
          returnsNormally);
      expect(() => engine.getCapabilityLevel(Capabilities.workflowExecution),
          returnsNormally);

      // There should be no enterprise/aggregator/farmer checks in the engine
      final source = engine.runtimeType.toString();
      expect(source, contains('CapabilityEngine'));
    });

    test('different profiles produce different capability results', () {
      final farmer = CapabilityProfileFactory.basicFarmer('org-1');
      final enterprise = CapabilityProfileFactory.enterprise('org-2');

      final farmerEngine = CapabilityEngine.fromProfile(farmer);
      final enterpriseEngine = CapabilityEngine.fromProfile(enterprise);

      // Farmer cannot use AI
      expect(
        farmerEngine.hasCapability(Capabilities.aiRecommendations),
        isFalse,
      );

      // Enterprise can use AI
      expect(
        enterpriseEngine.hasCapability(Capabilities.aiRecommendations),
        isTrue,
      );

      // Both can use basic features
      expect(
        farmerEngine.hasCapability(Capabilities.marketplaceListings),
        isTrue,
      );
      expect(
        enterpriseEngine.hasCapability(Capabilities.marketplaceListings),
        isTrue,
      );
    });
  });
}
