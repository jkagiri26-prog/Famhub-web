import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/marketplace/domain/models/listing_publication.dart';
import 'package:famhub_app/features/marketplace/infrastructure/data_sources/marketplace_remote_data_source.dart';
import 'package:famhub_app/features/marketplace/infrastructure/repositories/marketplace_repository_impl.dart';

SelectedListingImage _image(String fileName) {
  return SelectedListingImage(
    bytes: Uint8List.fromList([1, 2, 3]),
    fileName: fileName,
  );
}

Map<String, dynamic> _listingRow({String id = 'abc', String stockId = 'stock-1'}) {
  return {
    'id': id,
    'title': 'Fresh Tomatoes',
    'description': 'Test listing',
    'price_per_unit': 150,
    'currency': 'KES',
    'images': <dynamic>[],
    'entity_id': 'entity-1',
    'variant_id': 'variant-1',
    'stock_id': stockId,
    'unit_id': 'unit-1',
    'location_id': 'loc-1',
    'contact_visibility': 'locked',
    'is_promoted': false,
    'status': 'active',
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-01T00:00:00Z',
  };
}

class _FakeMarketplaceDataSource extends MarketplaceRemoteDataSource {
  _FakeMarketplaceDataSource()
      : super(client: SupabaseClient('https://localhost', 'anon-key'));

  bool publishReturnsNull = false;
  bool throwOnSecondUpload = false;
  List<Map<String, dynamic>> fetchListingsResult = [];
  Map<String, dynamic>? lastPublishParams;
  final List<({String fileName, String listingId})> uploadCalls = [];

  @override
  Future<Map<String, dynamic>?> publishListingFromStock({
    required String stockId,
    required double pricePerUnit,
    String? title,
    String? description,
    required List<String> images,
  }) async {
    lastPublishParams = {
      'stockId': stockId,
      'pricePerUnit': pricePerUnit,
      'title': title,
      'description': description,
      'images': List<String>.from(images),
    };
    if (publishReturnsNull) return null;
    return _listingRow(stockId: stockId);
  }

  @override
  Future<void> uploadListingMedia({
    required Uint8List bytes,
    required String fileName,
    required String listingId,
  }) async {
    uploadCalls.add((fileName: fileName, listingId: listingId));
    if (throwOnSecondUpload && uploadCalls.length == 2) {
      throw Exception('Photo upload failed: the file is too large');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchListings({
    String? category,
    String? searchQuery,
    String? sellerId,
    String? statusFilter,
  }) async {
    return fetchListingsResult;
  }

  @override
  Future<List<String>> fetchListingMediaUrls(String listingId) async {
    return ['https://cdn.example/$listingId/a.webp'];
  }
}

void main() {
  late _FakeMarketplaceDataSource dataSource;
  late MarketplaceRepositoryImpl repository;

  setUp(() {
    dataSource = _FakeMarketplaceDataSource();
    repository = MarketplaceRepositoryImpl(dataSource);
  });

  test('publishes with an empty images array then uploads against the id', () async {
    final report = await repository.publishListingFromStockWithImages(
      stockId: 'stock-1',
      pricePerUnit: 150,
      title: 'Fresh Tomatoes',
      images: [_image('a.webp'), _image('b.webp')],
    );

    expect(dataSource.lastPublishParams!['images'], isEmpty);
    expect(report.listing.id, 'abc');
    expect(report.uploadedCount, 2);
    expect(report.failedCount, 0);
    expect(report.allImagesUploaded, isTrue);
    expect(dataSource.uploadCalls.map((c) => c.listingId).toList(),
        ['abc', 'abc']);
  });

  test('publishes without images and never uploads', () async {
    final report = await repository.publishListingFromStockWithImages(
      stockId: 'stock-1',
      pricePerUnit: 150,
    );

    expect(dataSource.uploadCalls, isEmpty);
    expect(report.uploadedCount, 0);
    expect(report.failedCount, 0);
    expect(report.listing.id, 'abc');
  });

  test('keeps successful uploads and reports the failed photo', () async {
    dataSource.throwOnSecondUpload = true;

    final report = await repository.publishListingFromStockWithImages(
      stockId: 'stock-1',
      pricePerUnit: 150,
      images: [_image('a.webp'), _image('bad.webp')],
    );

    expect(report.uploadedCount, 1);
    expect(report.failedCount, 1);
    expect(report.allImagesUploaded, isFalse);
    expect(report.failures.single, contains('Photo 2'));
    expect(dataSource.uploadCalls.length, 2);
  });

  test('recovers the listing id when the RPC returns no row', () async {
    dataSource.publishReturnsNull = true;
    dataSource.fetchListingsResult = [
      _listingRow(id: 'recovered-id', stockId: 'stock-1'),
    ];

    final report = await repository.publishListingFromStockWithImages(
      stockId: 'stock-1',
      pricePerUnit: 150,
      images: [_image('a.webp')],
    );

    expect(report.listing.id, 'recovered-id');
    expect(report.uploadedCount, 1);
    expect(report.failedCount, 0);
    expect(dataSource.uploadCalls.single.listingId, 'recovered-id');
  });

  test('reports unresolvable id without uploading', () async {
    dataSource.publishReturnsNull = true;

    final report = await repository.publishListingFromStockWithImages(
      stockId: 'stock-1',
      pricePerUnit: 150,
      images: [_image('a.webp')],
    );

    expect(report.failedCount, 1);
    expect(report.uploadedCount, 0);
    expect(dataSource.uploadCalls, isEmpty);
  });
}
