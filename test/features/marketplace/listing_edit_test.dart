import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/marketplace/application/providers/marketplace_provider.dart';
import 'package:famhub_app/features/marketplace/domain/entities/listing.dart';
import 'package:famhub_app/features/marketplace/domain/entities/stock_item.dart';
import 'package:famhub_app/features/marketplace/domain/enums/listing_status.dart';
import 'package:famhub_app/features/marketplace/domain/models/listing_edit_changes.dart';
import 'package:famhub_app/features/marketplace/domain/models/listing_image_file.dart';
import 'package:famhub_app/features/marketplace/domain/models/listing_publication.dart';
import 'package:famhub_app/features/marketplace/domain/repositories/marketplace_repository.dart';
import 'package:famhub_app/features/marketplace/infrastructure/data_sources/marketplace_remote_data_source.dart';
import 'package:famhub_app/features/marketplace/infrastructure/repositories/marketplace_repository_impl.dart';
import 'package:famhub_app/features/marketplace/infrastructure/services/listing_edit_error_mapper.dart';
import 'package:famhub_app/features/marketplace/presentation/pages/listing_edit_page.dart';

Listing _listing({
  String id = 'list-1',
  String title = 'Fresh Tomatoes',
  String? description = 'Ripe and ready',
  double price = 150,
  String currency = 'KES',
  ListingStatus status = ListingStatus.active,
  List<String> images = const ['media-id-1'],
}) {
  return Listing(
    id: id,
    title: title,
    description: description,
    pricePerUnit: price,
    currency: currency,
    images: images,
    entityId: 'entity-1',
    variantId: 'variant-1',
    stockId: 'stock-1',
    unitId: 'unit-1',
    locationId: 'loc-1',
    status: status,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

Map<String, dynamic> _listingRow({
  String id = 'list-1',
  String? title,
  String? description,
  double? price,
  String status = 'active',
}) {
  return {
    'id': id,
    'title': title ?? 'Fresh Tomatoes',
    'description': description ?? 'Ripe and ready',
    'price_per_unit': price ?? 150,
    'currency': 'KES',
    'images': <dynamic>[],
    'entity_id': 'entity-1',
    'variant_id': 'variant-1',
    'stock_id': 'stock-1',
    'unit_id': null,
    'location_id': null,
    'contact_visibility': 'locked',
    'is_promoted': false,
    'promoted_until': null,
    'status': status,
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-02T00:00:00Z',
  };
}

class _FakeDataSource extends MarketplaceRemoteDataSource {
  _FakeDataSource()
    : super(client: SupabaseClient('https://localhost', 'anon-key'));

  final List<ListingEditChanges> metadataCalls = [];
  final List<String> statusCalls = [];
  int fetchListingByIdCount = 0;
  int fetchListingsCount = 0;
  Map<String, dynamic>? row;
  Object? throwOnMetadata;
  Object? throwOnStatus;
  bool statusReturnNull = false;
  Completer<void>? holdMetadata;

  @override
  Future<Map<String, dynamic>?> updateListingDetails({
    required String listingId,
    required ListingEditChanges changes,
  }) async {
    metadataCalls.add(changes);
    if (holdMetadata != null) await holdMetadata!.future;
    if (throwOnMetadata != null) throw throwOnMetadata!;
    final result = Map<String, dynamic>.from(row ?? _listingRow(id: listingId));
    if (changes.title != null) result['title'] = changes.title;
    if (changes.descriptionChanged) {
      result['description'] = changes.description;
    }
    if (changes.pricePerUnit != null) {
      result['price_per_unit'] = changes.pricePerUnit;
    }
    if (changes.currency != null) result['currency'] = changes.currency;
    return result;
  }

  @override
  Future<Map<String, dynamic>?> setListingStatus({
    required String listingId,
    required String status,
  }) async {
    statusCalls.add(status);
    if (throwOnStatus != null) throw throwOnStatus!;
    if (statusReturnNull) return null;
    final result = Map<String, dynamic>.from(row ?? _listingRow(id: listingId));
    result['status'] = status;
    return result;
  }

  @override
  Future<Map<String, dynamic>?> fetchListingById(String id) async {
    fetchListingByIdCount++;
    return row ?? _listingRow(id: id);
  }

  final List<String> uploadedFileNames = [];
  final List<String> deletedFileIds = [];
  int mediaEntriesFetchCount = 0;
  List<Map<String, String>>? mediaEntriesResult;

  @override
  Future<void> uploadListingMedia({
    required Uint8List bytes,
    required String fileName,
    required String listingId,
  }) async {
    uploadedFileNames.add(fileName);
  }

  @override
  Future<void> deleteListingMedia(String fileId) async {
    deletedFileIds.add(fileId);
  }

  @override
  Future<List<Map<String, String>>> fetchListingMediaEntries(
    String listingId,
  ) async {
    mediaEntriesFetchCount++;
    return mediaEntriesResult ?? const [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchListings({
    String? category,
    String? searchQuery,
    String? sellerId,
    String? statusFilter,
  }) async {
    fetchListingsCount++;
    return <Map<String, dynamic>>[];
  }

  @override
  Future<Map<String, String>> fetchUnitsByIds(Set<String> unitIds) async {
    return const {};
  }

  @override
  Future<Map<String, String>> fetchLocationsByIds(
    Set<String> locationIds,
  ) async {
    return const {};
  }

  @override
  Future<Map<String, String>> fetchVariantsByIds(Set<String> variantIds) async {
    return const {};
  }

  @override
  Future<Map<String, dynamic>?> fetchSellerProfile(String entityId) async {
    return null;
  }
}

class _FakeMarketplaceRepository implements MarketplaceRepository {
  Listing? listing;
  int fetchDetailCount = 0;
  final List<ListingEditChanges> metadataCalls = [];
  Completer<void>? holdMetadata;
  Object? throwOnMetadata;

  @override
  Future<List<Listing>> fetchListings({
    String? category,
    String? searchQuery,
    String? sellerId,
    List<ListingStatus>? statusFilter,
  }) async {
    final current = listing;
    return current == null ? const [] : [current];
  }

  @override
  Future<Listing?> fetchListingById(String id) async {
    fetchDetailCount++;
    return listing;
  }

  @override
  Future<Listing> updateListingDetails({
    required String listingId,
    required ListingEditChanges changes,
  }) async {
    metadataCalls.add(changes);
    if (holdMetadata != null) await holdMetadata!.future;
    if (throwOnMetadata != null) throw throwOnMetadata!;
    final current = listing;
    if (current == null) {
      throw Exception('Listing no longer available.');
    }
    listing = current.copyWith(
      title: changes.title ?? current.title,
      description: changes.descriptionChanged
          ? changes.description
          : current.description,
      pricePerUnit: changes.pricePerUnit ?? current.pricePerUnit,
      currency: changes.currency ?? current.currency,
      updatedAt: DateTime.now(),
    );
    return listing!;
  }

  @override
  Future<Listing> setListingStatus({
    required String listingId,
    required ListingStatus status,
  }) async {
    final current = listing;
    if (current == null) {
      throw Exception('Listing no longer available.');
    }
    listing = current.copyWith(status: status, updatedAt: DateTime.now());
    return listing!;
  }

  @override
  Future<Listing> createListing(Map<String, dynamic> payload) {
    throw UnimplementedError();
  }

  @override
  Future<Listing> updateListing(String id, Map<String, dynamic> payload) {
    throw UnimplementedError();
  }

  @override
  Future<void> archiveListing(String id) {
    throw UnimplementedError();
  }

  @override
  Future<Listing> publishListing(String id) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateInventory({
    required String listingId,
    double? availableQuantity,
    double? reservedQuantity,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> getSellerStats(String sellerId) {
    throw UnimplementedError();
  }

  @override
  Future<List<StockItem>> fetchEligibleStock({String? searchQuery}) {
    throw UnimplementedError();
  }

  @override
  Future<StockItem?> fetchStockById(String stockId) {
    throw UnimplementedError();
  }

  @override
  Future<Listing> publishListingFromStock({
    required String stockId,
    required double pricePerUnit,
    String? title,
    String? description,
    required List<String> images,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ListingPublicationReport> publishListingFromStockWithImages({
    required String stockId,
    required double pricePerUnit,
    String? title,
    String? description,
    List<SelectedListingImage> images = const [],
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> uploadListingImage({
    required Uint8List bytes,
    required String fileName,
    required String listingId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> fetchListingImageUrls(String listingId) {
    throw UnimplementedError();
  }

  @override
  Future<List<ListingImageFile>> fetchListingImageFiles(
    String listingId,
  ) async {
    if (failImageFiles) throw Exception('media_get_by_context: 404');
    return const [];
  }

  bool failImageFiles = false;

  @override
  Future<void> deleteListingImage(String fileId) {
    throw UnimplementedError();
  }
}

void main() {
  group('ListingEditChanges.diff + payload whitelist', () {
    final original = _listing();

    test('TEST 1: only changed editable fields are produced', () {
      final changes = ListingEditChanges.diff(
        original: original,
        title: 'New Title',
        description: 'New description',
        pricePerUnit: 900,
        currency: 'KES',
      );
      final payload = editableListingChangesPayload(changes);

      expect(payload.keys, containsAll(['title', 'description']));
      expect(payload.keys, contains('price_per_unit'));
      expect(payload['title'], 'New Title');
      expect(payload['description'], 'New description');
      expect(payload['price_per_unit'], 900);
      // Currency unchanged (KES) must NOT be sent.
      expect(payload.containsKey('currency'), isFalse);
    });

    test('TEST 2: images are never part of the update payload', () {
      final withImages = _listing(images: const ['img-a', 'img-b']);
      final changes = ListingEditChanges.diff(
        original: withImages,
        title: 'Renamed',
        description: withImages.description,
        pricePerUnit: withImages.pricePerUnit,
        currency: withImages.currency,
      );
      final payload = editableListingChangesPayload(changes);
      expect(payload.containsKey('images'), isFalse);
      expect(changes.title, 'Renamed');
    });

    test('TEST 3: status is never part of the update payload', () {
      final changes = ListingEditChanges.diff(
        original: original,
        title: 'Renamed',
        description: original.description,
        pricePerUnit: original.pricePerUnit,
        currency: original.currency,
      );
      final payload = editableListingChangesPayload(changes);
      expect(payload.containsKey('status'), isFalse);
    });

    test('TEST 4: entity/provenance fields are never part of the payload', () {
      final changes = ListingEditChanges.diff(
        original: original,
        title: 'Renamed',
        description: original.description,
        pricePerUnit: original.pricePerUnit,
        currency: original.currency,
      );
      final payload = editableListingChangesPayload(changes);
      for (final key in const [
        'id',
        'entity_id',
        'stock_id',
        'variant_id',
        'unit_id',
        'location_id',
        'created_at',
        'updated_at',
      ]) {
        expect(payload.containsKey(key), isFalse, reason: '$key leaked');
      }
    });

    test('TEST 5: promotion fields are never part of the payload', () {
      final changes = ListingEditChanges.diff(
        original: original,
        title: 'Renamed',
        description: original.description,
        pricePerUnit: original.pricePerUnit,
        currency: original.currency,
      );
      final payload = editableListingChangesPayload(changes);
      expect(payload.containsKey('is_promoted'), isFalse);
      expect(payload.containsKey('promoted_until'), isFalse);
    });

    test('TEST 7: price is serialized as numeric data, never a string', () {
      final changes = ListingEditChanges.diff(
        original: original,
        title: original.title,
        description: original.description,
        pricePerUnit: 1275.5,
        currency: 'KES',
      );
      final payload = editableListingChangesPayload(changes);
      expect(payload['price_per_unit'], 1275.5);
      expect(payload['price_per_unit'], isA<num>());
      expect(payload['price_per_unit'].toString().contains('KSh'), isFalse);
    });

    test('TEST 8: description can be cleared (serialized as null)', () {
      final changes = ListingEditChanges.diff(
        original: original,
        title: original.title,
        description: '',
        pricePerUnit: original.pricePerUnit,
        currency: original.currency,
      );
      expect(changes.isEmpty, isFalse);
      expect(changes.descriptionChanged, isTrue);
      final payload = editableListingChangesPayload(changes);
      expect(payload.containsKey('description'), isTrue);
      expect(payload['description'], isNull);
    });

    test('no-op edit produces an empty change set', () {
      final changes = ListingEditChanges.diff(
        original: original,
        title: '  ${original.title}  ',
        description: original.description,
        pricePerUnit: original.pricePerUnit,
        currency: original.currency,
      );
      expect(changes.isEmpty, isTrue);
    });
  });

  group('Repository canonical mutation contract', () {
    late _FakeDataSource dataSource;
    late MarketplaceRepositoryImpl repository;

    setUp(() {
      dataSource = _FakeDataSource();
      repository = MarketplaceRepositoryImpl(dataSource);
    });

    test('TEST 6: no RPC is attempted when there are no changes', () async {
      const changes = ListingEditChanges(
        title: null,
        pricePerUnit: null,
        currency: null,
        descriptionChanged: false,
      );
      expect(changes.isEmpty, isTrue);

      expect(
        () => repository.updateListingDetails(
          listingId: 'list-1',
          changes: changes,
        ),
        throwsArgumentError,
      );
      expect(dataSource.metadataCalls, isEmpty);
    });

    test('TEST 9: successful update returns the mapped Listing', () async {
      final updated = await repository.updateListingDetails(
        listingId: 'list-1',
        changes: ListingEditChanges.diff(
          original: _listing(),
          title: 'Updated Tomatoes',
          description: 'Fresh from the farm',
          pricePerUnit: 200,
          currency: 'KES',
        ),
      );
      expect(updated.id, 'list-1');
      expect(updated.title, 'Updated Tomatoes');
      expect(updated.pricePerUnit, 200);
      expect(updated.description, 'Fresh from the farm');
      expect(dataSource.metadataCalls, hasLength(1));
    });

    test('TEST 12: activation calls set_listing_status (active)', () async {
      dataSource.row = _listingRow(id: 'list-1', status: 'active');
      final updated = await repository.setListingStatus(
        listingId: 'list-1',
        status: ListingStatus.active,
      );
      expect(dataSource.statusCalls, ['active']);
      expect(updated.status, ListingStatus.active);
      // Canonical RPC names are wired to set_listing_status, not the legacy
      // service-role activate_listing operation.
      expect(
        MarketplaceRemoteDataSource.setListingStatusRpc,
        'set_listing_status',
      );
      expect(
        MarketplaceRemoteDataSource.setListingStatusRpc,
        isNot('activate_listing'),
      );
      expect(MarketplaceRemoteDataSource.updateListingRpc, 'update_listing');
    });

    test('TEST 13: deactivation calls set_listing_status (inactive)', () async {
      dataSource.row = _listingRow(id: 'list-1', status: 'inactive');
      final updated = await repository.setListingStatus(
        listingId: 'list-1',
        status: ListingStatus.inactive,
      );
      expect(dataSource.statusCalls, ['inactive']);
      expect(updated.status, ListingStatus.inactive);
    });

    test('TEST 14: arbitrary statuses cannot be sent to the backend', () async {
      expect(
        () => repository.setListingStatus(
          listingId: 'list-1',
          status: ListingStatus.archived,
        ),
        throwsArgumentError,
      );
      expect(dataSource.statusCalls, isEmpty);
    });

    test(
      'unmapped status change reloads listing from canonical source',
      () async {
        dataSource.row = _listingRow(id: 'list-1', status: 'inactive');
        dataSource.statusReturnNull = true;
        final updated = await repository.setListingStatus(
          listingId: 'list-1',
          status: ListingStatus.inactive,
        );
        expect(dataSource.fetchListingByIdCount, 1);
        expect(updated.status, ListingStatus.inactive);
      },
    );
  });

  group('User-friendly error mapping', () {
    test('TEST 10: backend unauthorized maps to permission message', () {
      const error = PostgrestException(
        message: 'permission denied for function marketplace.update_listing',
        code: '42501',
      );
      expect(
        describeListingSaveError(error),
        "You don't have permission to edit this listing.",
      );
    });

    test('unauthenticated maps to sign-in message', () {
      const error = PostgrestException(
        message: 'new row violates row-level security policy',
        code: '42501',
        details: 'jwt expired',
      );
      expect(
        describeListingSaveError(error),
        'Please sign in to edit this listing.',
      );
    });

    test('TEST 11: backend validation error maps to a friendly message', () {
      const invalidPrice = PostgrestException(
        message: 'new row violates check constraint listing_price_check',
        code: '23514',
      );
      expect(
        describeListingSaveError(invalidPrice),
        'Enter a valid price greater than zero.',
      );

      const otherValidation = PostgrestException(
        message: 'new row for relation "listings" violates check constraint',
        code: '23514',
      );
      expect(
        describeListingSaveError(otherValidation),
        'Some listing details are invalid. Review the fields and try again.',
      );
    });

    test('activation with no stock maps to the no-available-stock message', () {
      const error = PostgrestException(
        message:
            'listing cannot be activated because the stock_registry '
            'record has no available quantity',
      );
      expect(
        describeListingStatusError(error, activating: true),
        'This listing cannot be activated because there is no available '
        'stock.',
      );
    });
  });

  group('Controller invalidation after status change (TEST 15)', () {
    test('status change refreshes listing details + feed', () async {
      final dataSource = _FakeDataSource();
      final repository = MarketplaceRepositoryImpl(dataSource);
      final container = ProviderContainer(
        overrides: [
          marketplaceRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(marketplaceProvider.future);
      await container.read(listingDetailsProvider('list-1').future);
      expect(dataSource.fetchListingByIdCount, 1);

      final updated = await container
          .read(marketplaceProvider.notifier)
          .setListingStatus(
            listingId: 'list-1',
            status: ListingStatus.inactive,
          );

      expect(updated.status, ListingStatus.inactive);
      expect(dataSource.statusCalls, ['inactive']);

      final detail = await container.read(
        listingDetailsProvider('list-1').future,
      );
      expect(detail, isNotNull);
      expect(dataSource.fetchListingByIdCount, 2);

      final feed = await container.read(marketplaceProvider.future);
      expect(feed, isEmpty);
      expect(dataSource.fetchListingsCount, 2);
    });
  });

  group('Listing photos plumbing', () {
    late _FakeDataSource dataSource;
    late MarketplaceRepositoryImpl repository;

    setUp(() {
      dataSource = _FakeDataSource();
      repository = MarketplaceRepositoryImpl(dataSource);
    });

    test(
      'fetchListingImageFiles maps entries and drops incomplete ones',
      () async {
        dataSource.mediaEntriesResult = [
          {'id': 'file-1', 'url': 'https://cdn.example/a.webp'},
          {'url': 'https://cdn.example/no-id.webp'},
          {'id': 'file-2'},
        ];

        final files = await repository.fetchListingImageFiles('list-1');

        expect(files, hasLength(1));
        expect(files.single.id, 'file-1');
        expect(files.single.url, 'https://cdn.example/a.webp');
      },
    );

    test('photo upload invalidates the media providers', () async {
      dataSource.mediaEntriesResult = [
        {'id': 'file-1', 'url': 'https://cdn.example/a.webp'},
      ];
      final container = ProviderContainer(
        overrides: [
          marketplaceRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(marketplaceProvider.future);
      await container.read(listingMediaFilesProvider('list-1').future);
      expect(dataSource.mediaEntriesFetchCount, 1);

      await container
          .read(marketplaceProvider.notifier)
          .uploadListingPhoto(
            listingId: 'list-1',
            bytes: Uint8List.fromList([1, 2, 3]),
            fileName: 'listing_image_1.webp',
          );

      expect(dataSource.uploadedFileNames, ['listing_image_1.webp']);
      await container.read(listingMediaFilesProvider('list-1').future);
      expect(dataSource.mediaEntriesFetchCount, 2);
    });

    test('photo delete invalidates the media providers', () async {
      dataSource.mediaEntriesResult = [
        {'id': 'file-1', 'url': 'https://cdn.example/a.webp'},
      ];
      final container = ProviderContainer(
        overrides: [
          marketplaceRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(marketplaceProvider.future);
      await container.read(listingMediaFilesProvider('list-1').future);

      await container
          .read(marketplaceProvider.notifier)
          .deleteListingPhoto(listingId: 'list-1', fileId: 'file-1');

      expect(dataSource.deletedFileIds, ['file-1']);
      await container.read(listingMediaFilesProvider('list-1').future);
      expect(dataSource.mediaEntriesFetchCount, 2);
    });
  });

  group('Listing Edit form (TEST 16)', () {
    Future<void> pumpEditor(
      WidgetTester tester,
      _FakeMarketplaceRepository repository,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketplaceRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const ListingEditPage(listingId: 'list-1'),
                      ),
                    ),
                    child: const Text('Open Editor'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Editor'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Listing'), findsOneWidget);
    }

    testWidgets('repeated Save taps do not submit twice', (tester) async {
      final repository = _FakeMarketplaceRepository();
      repository.listing = _listing(id: 'list-1');
      repository.holdMetadata = Completer<void>();

      await pumpEditor(tester, repository);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Updated Tomato Title',
      );
      await tester.pump();

      final saveFinder = find.byKey(const Key('listing_edit_save_button'));
      expect(saveFinder, findsOneWidget);
      await tester.ensureVisible(saveFinder);
      await tester.pump();

      await tester.tap(saveFinder);
      await tester.pump();

      // Second tap while the first request is still in flight must be a no-op.
      await tester.tap(saveFinder, warnIfMissed: false);
      await tester.pump();
      expect(repository.metadataCalls, hasLength(1));

      repository.holdMetadata!.complete();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(repository.metadataCalls, hasLength(1));
    });

    testWidgets('Save is disabled when no field has changed', (tester) async {
      final repository = _FakeMarketplaceRepository();
      repository.listing = _listing(id: 'list-1');

      await pumpEditor(tester, repository);

      final saveFinder = find.byKey(const Key('listing_edit_save_button'));
      expect(saveFinder, findsOneWidget);
      final elevated = tester.widget<ElevatedButton>(saveFinder);
      expect(elevated.onPressed, isNull);
      expect(repository.metadataCalls, isEmpty);
    });

    testWidgets('photos stay addable when existing photos cannot be loaded', (
      tester,
    ) async {
      final repository = _FakeMarketplaceRepository();
      repository.listing = _listing(id: 'list-1');
      repository.failImageFiles = true;

      await pumpEditor(tester, repository);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Could not load existing photos.'), findsOneWidget);
      expect(find.text('Add 3 photos'), findsOneWidget);
    });
  });
}
