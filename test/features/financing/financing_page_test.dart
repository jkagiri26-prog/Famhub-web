import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/financing/presentation/pages/financing_page.dart';

import 'financing_test_harness.dart';

void main() {
  testWidgets(
    'My Finance quick link is reachable inside the page scroll view',
    (tester) async {
      await pumpTestApp(
        tester,
        const FinancingPage(),
        overrides: defaultOverrides(
          repository: FakeFinancingCatalogueRepository(),
        ),
      );

      final link = find.text('My Finance');
      expect(link, findsOneWidget);
      expect(
        find.ancestor(of: link, matching: find.byType(SingleChildScrollView)),
        findsOneWidget,
      );

      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      expect(link, findsOneWidget);
    },
  );
}
