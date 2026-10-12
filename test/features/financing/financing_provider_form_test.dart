import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/financing/domain/financing_slug.dart';
import 'package:famhub_app/features/financing/domain/repositories/financing_catalogue_repository.dart';
import 'package:famhub_app/features/financing/presentation/pages/financing_management_page.dart';

import 'financing_test_harness.dart';

/// Regression coverage for the two production defects:
///   1. the provider slug was never generated (the backend does not derive it
///      — `financing._validate_slug` raises 22023 when the slug is empty), and
///   2. the form closed and reported "Provider saved." even when the save
///      failed, because `Navigator.pop()` ran before the awaited call.
void main() {
  Finder addProvider() => find.widgetWithText(FilledButton, 'Add provider');
  Finder saveProvider() => find.widgetWithText(FilledButton, 'Save provider');
  Finder cancel() => find.widgetWithText(OutlinedButton, 'Cancel');
  Finder nameField() => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'e.g. Equity Bank',
      );
  Finder slugField() => find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.helperText == 'lowercase letters, numbers and hyphens',
      );

  Future<FakeFinancingCatalogueRepository> openForm(
    WidgetTester tester,
  ) async {
    final repo = FakeFinancingCatalogueRepository();
    await pumpTestApp(
      tester,
      const FinancingManagementPage(),
      overrides: defaultOverrides(repository: repo),
    );
    await tester.tap(addProvider());
    await tester.pumpAndSettle();
    expect(cancel(), findsOneWidget, reason: 'the provider form should open');
    expect(slugField(), findsOneWidget);
    return repo;
  }

  Future<void> pressSave(WidgetTester tester) async {
    final button = saveProvider();
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('derives the slug from the name before anything is submitted',
      (tester) async {
    final repo = await openForm(tester);

    await tester.enterText(nameField(), 'Equity Bank');
    await tester.pump();

    expect(
      tester.widget<TextField>(slugField()).controller!.text,
      'equity-bank',
      reason: 'the form must derive the slug the backend refuses to derive',
    );

    await pressSave(tester);

    expect(repo.saveProviderCalls, hasLength(1));
    expect(repo.saveProviderCalls.single.name, 'Equity Bank');
    expect(repo.saveProviderCalls.single.slug, 'equity-bank');
    expect(cancel(), findsNothing, reason: 'a successful save closes the form');
    expect(find.text('Provider saved.'), findsOneWidget);
  });

  testWidgets('a manually typed slug is submitted instead of the derived one',
      (tester) async {
    final repo = await openForm(tester);

    await tester.enterText(nameField(), 'Equity Bank');
    await tester.enterText(slugField(), 'equity-bank-ke');
    await tester.pump();

    await pressSave(tester);

    expect(repo.saveProviderCalls.single.slug, 'equity-bank-ke');
  });

  testWidgets(
      'an invalid slug is rejected inline and the form stays open with the '
      'values the operator typed', (tester) async {
    final repo = await openForm(tester);

    await tester.enterText(nameField(), 'Equity Bank');
    await tester.enterText(slugField(), 'Equity Bank');
    await pressSave(tester);

    expect(find.text(financingSlugFormatError), findsOneWidget);
    expect(cancel(), findsOneWidget, reason: 'the form must not close');
    expect(repo.saveProviderCalls, isEmpty,
        reason: 'nothing may be submitted with an invalid slug');
    expect(
      tester.widget<TextField>(nameField()).controller!.text,
      'Equity Bank',
    );
    expect(
      tester.widget<TextField>(slugField()).controller!.text,
      'Equity Bank',
    );
  });

  testWidgets(
      'a failed save keeps the form open and surfaces the backend error '
      'instead of reporting success', (tester) async {
    final repo = await openForm(tester);
    repo.onSaveProvider = (call) async {
      throw const FinancingActionException(
        'That slug is already used by another provider or product. '
        'Pick a different one.',
        code: '23505',
      );
    };

    await tester.enterText(nameField(), 'Equity Bank');
    await pressSave(tester);

    expect(cancel(), findsOneWidget, reason: 'the form must not close');
    expect(find.textContaining('already used by another provider'), findsOneWidget);
    expect(find.text('Provider saved.'), findsNothing,
        reason: 'a failed save must never claim success');
    expect(
      tester.widget<TextField>(nameField()).controller!.text,
      'Equity Bank',
      reason: 'the values must survive the failure so the operator can retry',
    );
    expect(repo.saveProviderCalls, hasLength(1));
  });

  testWidgets('the operator can retry after a failed save', (tester) async {
    final repo = await openForm(tester);
    var attempts = 0;
    repo.onSaveProvider = (call) async {
      attempts += 1;
      if (attempts == 1) {
        throw const FinancingActionException(
          'That slug is already used by another provider or product. '
          'Pick a different one.',
          code: '23505',
        );
      }
      return 'provider-1';
    };

    await tester.enterText(nameField(), 'Equity Bank');
    await pressSave(tester);
    expect(cancel(), findsOneWidget);
    expect(attempts, 1);

    await pressSave(tester);

    expect(attempts, 2);
    expect(cancel(), findsNothing, reason: 'the retry succeeded and closed');
    expect(find.text('Provider saved.'), findsOneWidget);
  });
}
