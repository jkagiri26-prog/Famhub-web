import 'package:famhub_app/features/agri_connect/infrastructure/data_sources/agri_connect_media.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgriConnectMediaDataSource.parseMediaEntries', () {
    test('keeps a path-only entry (private bucket, no signed url)', () {
      final entries = AgriConnectMediaDataSource.parseMediaEntries({
        'data': [
          {
            'id': '94d33308-6f6d-4fd5-84ea-737d46930eb8',
            'path':
                'images/agri_connect/discussions/'
                'a2528ca1-628a-4557-84a2-0a0f88b252cf/'
                '94d33308-6f6d-4fd5-84ea-737d46930eb8.webp',
          },
        ],
      });
      expect(entries, hasLength(1));
      expect(entries.first['id'], '94d33308-6f6d-4fd5-84ea-737d46930eb8');
      expect(
        entries.first['path'],
        startsWith('images/agri_connect/discussions/'),
      );
      expect(entries.first.containsKey('url'), isFalse);
    });

    test('accepts a bare list with an http url', () {
      final entries = AgriConnectMediaDataSource.parseMediaEntries([
        {'id': 'a', 'url': 'https://cdn.example.com/x.webp'},
      ]);
      expect(entries, hasLength(1));
      expect(entries.first['url'], 'https://cdn.example.com/x.webp');
      expect(entries.first['id'], 'a');
    });

    test('treats a non-http url value as the storage path', () {
      final entries = AgriConnectMediaDataSource.parseMediaEntries({
        'files': [
          {'url': 'images/agri_connect/discussions/a/b.webp'},
        ],
      });
      expect(entries, hasLength(1));
      expect(entries.first['path'], 'images/agri_connect/discussions/a/b.webp');
      expect(entries.first.containsKey('url'), isFalse);
    });

    test('unwraps a nested data -> files envelope', () {
      final entries = AgriConnectMediaDataSource.parseMediaEntries({
        'data': {
          'files': [
            {'file_id': 'f1', 'signed_url': 'https://cdn.example.com/f1.webp'},
          ],
        },
      });
      expect(entries, hasLength(1));
      expect(entries.first['id'], 'f1');
      expect(entries.first['url'], 'https://cdn.example.com/f1.webp');
    });

    test('keeps id-only entries for attachment linking', () {
      final entries = AgriConnectMediaDataSource.parseMediaEntries([
        {'file_id': 'only-id'},
      ]);
      expect(entries, hasLength(1));
      expect(entries.first['id'], 'only-id');
    });

    test('returns empty for success-only and empty payloads', () {
      expect(
        AgriConnectMediaDataSource.parseMediaEntries({'success': true}),
        isEmpty,
      );
      expect(
        AgriConnectMediaDataSource.parseMediaEntries(<dynamic>[]),
        isEmpty,
      );
      expect(AgriConnectMediaDataSource.parseMediaEntries(null), isEmpty);
    });
  });

  group('AgriConnectMediaDataSource.collectMediaItems', () {
    test('finds items one level nested under data', () {
      final items = AgriConnectMediaDataSource.collectMediaItems({
        'data': {
          'media': [
            {'id': 'x'},
          ],
        },
      });
      expect(items, hasLength(1));
    });

    test('accepts a single media-object payload', () {
      final items = AgriConnectMediaDataSource.collectMediaItems({
        'path': 'images/a.webp',
      });
      expect(items, hasLength(1));
    });
  });
}
