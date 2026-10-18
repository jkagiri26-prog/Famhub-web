import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/shell/application/assistant/assistant_capability.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context.dart';
import 'package:famhub_app/features/marketplace/application/ai/marketplace_capability.dart';
import 'package:famhub_app/features/marketplace/domain/entities/listing.dart';
import 'package:famhub_app/features/marketplace/domain/enums/listing_status.dart';

const AssistantContext _context = AssistantContext(
  route: '/marketplace',
  moduleId: 'marketplace',
  moduleName: 'Marketplace',
  workspaceType: 'trader',
);

Listing _listing({
  required String id,
  required String title,
  double price = 120,
  double quantity = 40,
  String? location,
  String? seller,
  DateTime? createdAt,
  ListingStatus status = ListingStatus.active,
}) {
  return Listing(
    id: id,
    title: title,
    pricePerUnit: price,
    images: const <String>['https://cdn.example/img.png'],
    entityId: 'ent_secret',
    variantId: 'var_secret',
    stockId: 'stk_secret',
    unitName: 'bag',
    locationName: location,
    contactVisibility: 'locked',
    status: status,
    createdAt: createdAt ?? DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 1),
    sellerName: seller,
    availableQuantity: quantity,
  );
}

MarketplaceCapability _capability(
  Future<List<Listing>> Function({String? searchQuery}) loadListings,
) {
  return MarketplaceCapability(
    readInputs: () => MarketplaceCapabilityInputs(loadListings: loadListings),
  );
}

void main() {
  group('question matching', () {
    test('claims the marketplace regression sequence', () {
      expect(
        isMarketplaceListingsQuestion('What is in FAMHUB Marketplace?'),
        isTrue,
      );
      expect(
        isMarketplaceListingsQuestion(
          'Do we have any maize? [active subject: marketplace]',
        ),
        isTrue,
      );
      expect(
        isMarketplaceListingsQuestion('I mean in marketplace.'),
        isTrue,
      );
      expect(isMarketplaceListingsQuestion('Tell me about this listing.'), isTrue);
      expect(
        isMarketplaceListingsQuestion('How many listings are available?'),
        isTrue,
      );
    });

    test('does not claim advice, pricing, publishing or other modules', () {
      expect(
        isMarketplaceListingsQuestion('What is the best price for maize?'),
        isFalse,
      );
      expect(
        isMarketplaceListingsQuestion('How do I publish a listing?'),
        isFalse,
      );
      expect(
        isMarketplaceListingsQuestion('What does maize fetch at the market?'),
        isFalse,
      );
      expect(isMarketplaceListingsQuestion('My goat is lame.'), isFalse);
      expect(
        isMarketplaceListingsQuestion("What's the weather forecast?"),
        isFalse,
      );
      expect(
        isMarketplaceListingsQuestion(
          'Do we have any maize? [active subject: farm]',
        ),
        isFalse,
      );
    });
  });

  group('marketplaceSearchTerm', () {
    test('keeps only meaningful words the farmer typed', () {
      expect(marketplaceSearchTerm('Do we have any maize?'), 'maize');
      expect(
        marketplaceSearchTerm('Do we have fresh green maize?'),
        'fresh green',
      );
    });

    test('returns null for an unfiltered overview', () {
      expect(marketplaceSearchTerm('What is in FAMHUB Marketplace?'), isNull);
      expect(marketplaceSearchTerm('I mean in marketplace.'), isNull);
      expect(marketplaceSearchTerm('Show me the listings.'), isNull);
    });
  });

  group('evidence', () {
    test('is redacted: no ids, images, descriptions or contact fields', () {
      final Map<String, dynamic> evidence = buildMarketplaceEvidence(
        listings: <Listing>[
          _listing(id: 'lst_secret_1', title: 'Fresh Maize'),
        ],
      );
      final String json = evidence.toString();

      expect(evidence['capability'], kMarketplaceCapabilityId);
      expect(evidence['_note'], kMarketplaceEvidenceNote);
      expect(json, isNot(contains('lst_secret_1')));
      expect(json, isNot(contains('ent_secret')));
      expect(json, isNot(contains('var_secret')));
      expect(json, isNot(contains('stk_secret')));
      expect(json, isNot(contains('cdn.example')));
      expect(json, isNot(contains('contactVisibility')));
      final Map<String, dynamic> row =
          (evidence['listings'] as List).single as Map<String, dynamic>;
      expect(row.keys, isNot(contains('id')));
      expect(row['title'], 'Fresh Maize');
      expect(row['status'], 'active');
    });

    test('caps entries and reports the true returned count', () {
      final List<Listing> listings = List<Listing>.generate(
        12,
        (int i) => _listing(id: 'lst$i', title: 'Listing $i'),
      );

      final Map<String, dynamic> evidence = buildMarketplaceEvidence(
        listings: listings,
      );

      expect(evidence['listings'], hasLength(kMaxMarketplaceEvidenceEntries));
      expect(evidence['listings_count'], 12);
      expect(evidence['listings_truncated'], isTrue);
    });

    test('carries the search term when there was one', () {
      final Map<String, dynamic> evidence = buildMarketplaceEvidence(
        listings: <Listing>[_listing(id: 'l1', title: 'Fresh Maize')],
        searchedFor: 'maize',
      );

      expect(evidence['searched_for'], 'maize');
    });
  });

  group('run', () {
    test('an overview question returns every listing it was given', () async {
      final List<Listing> listings = <Listing>[
        _listing(
          id: 'l1',
          title: 'Fresh Maize',
          createdAt: DateTime(2026, 5, 2),
        ),
        _listing(
          id: 'l2',
          title: 'Beans',
          createdAt: DateTime(2026, 5, 1),
        ),
      ];
      String? seen;
      final MarketplaceCapability capability = _capability(
        ({String? searchQuery}) async {
          seen = searchQuery;
          return listings;
        },
      );

      final AssistantCapabilityOutcome outcome = await capability.run(
        question: 'What is in FAMHUB Marketplace?',
        assistantContext: _context,
      );

      expect(seen, isNull);
      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      expect(outcome.evidence!.containsKey('searched_for'), isFalse);
      expect(
        (outcome.evidence!['listings'] as List)
            .map((dynamic r) => (r as Map<String, dynamic>)['title'])
            .toList(),
        <String>['Fresh Maize', 'Beans'],
      );
    });

    test('a follow-up search runs the term the farmer implied', () async {
      final List<String> seenTerms = <String>[];
      final MarketplaceCapability capability = _capability(
        ({String? searchQuery}) async {
          seenTerms.add(searchQuery ?? '');
          return <Listing>[_listing(id: 'l1', title: 'Fresh Maize')];
        },
      );

      final AssistantCapabilityOutcome outcome = await capability.run(
        question: 'Do we have any maize?',
        assistantContext: _context,
      );

      expect(seenTerms, <String>['maize']);
      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      expect(outcome.evidence!['searched_for'], 'maize');
      expect((outcome.evidence!['listings'] as List), hasLength(1));
    });

    test('an empty search is an honest outcome, never an invention', () async {
      final MarketplaceCapability capability = _capability(
        ({String? searchQuery}) async => const <Listing>[],
      );

      final AssistantCapabilityOutcome outcome = await capability.run(
        question: 'Do we have any maize?',
        assistantContext: _context,
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'marketplace_no_listings');
      expect(outcome.text, contains('No marketplace listings match "maize"'));
      expect(outcome.text, contains('not proof'));
      expect(outcome.evidence, isNull);
    });

    test('an empty overview is reported honestly', () async {
      final MarketplaceCapability capability = _capability(
        ({String? searchQuery}) async => const <Listing>[],
      );

      final AssistantCapabilityOutcome outcome = await capability.run(
        question: 'What is in FAMHUB Marketplace?',
        assistantContext: _context,
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'marketplace_no_listings');
      expect(outcome.text, contains('no marketplace listings on file'));
      expect(outcome.text, contains('cannot see beyond it'));
    });

    test('a repository failure stays generic', () async {
      final MarketplaceCapability capability = _capability(
        ({String? searchQuery}) async =>
            throw Exception('SELECT * FROM marketplace.listings failed'),
      );

      final AssistantCapabilityOutcome outcome = await capability.run(
        question: 'I mean in marketplace.',
        assistantContext: _context,
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'marketplace_unavailable');
      expect(outcome.text, contains('temporarily unavailable'));
      expect(outcome.text, isNot(contains('SELECT')));
      expect(outcome.text, isNot(contains('Exception')));
      expect(outcome.text, isNot(contains('marketplace.listings')));
    });
  });
}
