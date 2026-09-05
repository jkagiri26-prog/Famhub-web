import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/marketplace/infrastructure/data_sources/marketplace_remote_data_source.dart';

void main() {
  group('uploadFailureReason', () {
    test('confirms a successful upload', () {
      expect(
        MarketplaceRemoteDataSource.uploadFailureReason({
          'success': true,
          'file_type': 'image',
          'path': 'images/listings/x/y.webp',
          'url': 'https://signed/url',
        }),
        isNull,
      );
    });

    test('surfaces backend error text when success is false', () {
      expect(
        MarketplaceRemoteDataSource.uploadFailureReason({
          'success': false,
          'error': 'unsupported format',
        }),
        'unsupported format',
      );
    });

    test('falls back to a default reason for empty payloads', () {
      expect(MarketplaceRemoteDataSource.uploadFailureReason(null), isNotNull);
      expect(MarketplaceRemoteDataSource.uploadFailureReason('oops'), isNotNull);
    });
  });

  group('deleteFailureReason', () {
    test('confirms a successful delete', () {
      expect(
        MarketplaceRemoteDataSource.deleteFailureReason({'success': true}),
        isNull,
      );
    });

    test('surfaces backend error text', () {
      expect(
        MarketplaceRemoteDataSource.deleteFailureReason({
          'success': false,
          'error': 'not owner',
        }),
        'not owner',
      );
    });
  });

  group('mediaFileEntries', () {
    test('parses a bare list of signed files', () {
      final entries = MarketplaceRemoteDataSource.mediaFileEntries([
        {'id': 'file-1', 'url': 'https://cdn.example/a.webp'},
        {'id': 'file-2', 'url': 'https://cdn.example/b.webp'},
      ]);

      expect(entries.length, 2);
      expect(entries[0]['id'], 'file-1');
      expect(entries[0]['url'], 'https://cdn.example/a.webp');
      expect(entries[1]['id'], 'file-2');
    });

    test('accepts an envelope payload', () {
      final entries = MarketplaceRemoteDataSource.mediaFileEntries({
        'success': true,
        'data': [
          {'id': 'file-1', 'signed_url': 'https://cdn.example/a.webp'},
        ],
      });

      expect(entries.single['id'], 'file-1');
      expect(entries.single['url'], 'https://cdn.example/a.webp');
    });

    test('drops non-http references (storage paths, ids, malformed)', () {
      final entries = MarketplaceRemoteDataSource.mediaFileEntries([
        {'id': 'file-1', 'url': 'images/listings/private/a.webp'},
        {'id': 'file-2', 'url': 'not-a-url'},
        {'id': 'file-3'},
      ]);

      expect(entries, isEmpty);
    });

    test('returns empty when payload is neither a list nor an envelope', () {
      expect(MarketplaceRemoteDataSource.mediaFileEntries(null), isEmpty);
      expect(MarketplaceRemoteDataSource.mediaFileEntries('raw'), isEmpty);
      expect(MarketplaceRemoteDataSource.mediaFileEntries({'media': 'x'}),
          isEmpty);
    });
  });
}
