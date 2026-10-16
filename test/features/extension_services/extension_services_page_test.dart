import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/extension_services/presentation/pages/extension_services_page.dart';

Future<void> _pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1100, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: ExtensionServicesPage()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ExtensionServicesPage', () {
    testWidgets('renders the module landing without an assistant panel',
        (tester) async {
      await _pumpPage(tester);

      expect(find.text('Extension Services'), findsOneWidget);
      expect(
        find.text('Practical advice for your crops and livestock'),
        findsOneWidget,
      );

      // The assistant lives behind the shell's global AI tab, not here.
      expect(find.byType(TextField), findsNothing);
      expect(find.text('FAMHUB AI'), findsNothing);
      expect(find.text('Farming adviser'), findsNothing);
      expect(
        find.text('Ask a question about your crops or livestock.'),
        findsNothing,
      );
      expect(find.byTooltip('Send'), findsNothing);
    });

    testWidgets('lists the advisory areas the module covers', (tester) async {
      await _pumpPage(tester);

      expect(find.text('THIS CAN HELP WITH'), findsOneWidget);
      expect(find.text('Crop Advisory'), findsOneWidget);
      expect(find.text('Livestock Support'), findsOneWidget);
    });

    testWidgets('does not render fictional experts or service cards',
        (tester) async {
      await _pumpPage(tester);

      expect(find.textContaining('Dr. Jane Kamau'), findsNothing);
      expect(find.textContaining('Officer Samuel Owen'), findsNothing);
      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.byType(NetworkImage), findsNothing);
    });

    testWidgets('does not present a referral as available', (tester) async {
      await _pumpPage(tester);

      expect(find.text('WHEN YOU NEED A PERSON'), findsOneWidget);
      expect(
        find.textContaining('does not currently hold a directory'),
        findsOneWidget,
      );
      expect(find.textContaining('Book'), findsNothing);
      expect(find.textContaining('Book appointment'), findsNothing);
      expect(find.byIcon(Icons.calendar_month), findsNothing);
    });
  });
}
