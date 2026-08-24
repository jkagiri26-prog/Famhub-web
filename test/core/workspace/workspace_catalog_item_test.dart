import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/workspace/domain/workspace_catalog_item.dart';

void main() {
  group('WorkspaceCatalogItem.fromRow', () {
    test('parses a standard system.workspaces row', () {
      final item = WorkspaceCatalogItem.fromRow({
        'id': 'ws-1',
        'name': 'Trader',
        'description': 'Trade agricultural produce',
        'category': 'Trader / Retailer',
        'icon': 'sell',
      });

      expect(item.id, 'ws-1');
      expect(item.name, 'Trader');
      expect(item.description, 'Trade agricultural produce');
      expect(item.category, 'Trader / Retailer');
      expect(item.iconKey, 'sell');
    });

    test('falls back defensively when columns vary', () {
      final item = WorkspaceCatalogItem.fromRow({
        'id': 'ws-2',
        'title': 'Aggregator',
        'subtitle': 'Aggregate produce',
        'workspace_type': 'Aggregator / Suppliers',
        'icon_key': 'store',
      });

      expect(item.id, 'ws-2');
      expect(item.name, 'Aggregator');
      expect(item.description, 'Aggregate produce');
      expect(item.category, 'Aggregator / Suppliers');
      expect(item.iconKey, 'store');
    });

    test('no hardcoded catalog — any future workspace renders', () {
      final item = WorkspaceCatalogItem.fromRow({
        'id': 'ws-future',
        'name': 'Labour Service',
      });

      expect(item.name, 'Labour Service');
      expect(item.category, isNull);
      expect(item.description, isNull);
      expect(item.iconKey, isNull);
    });
  });
}
