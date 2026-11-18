import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/marketplace/application/providers/marketplace_provider.dart';
import 'package:famhub_app/features/marketplace/domain/entities/listing.dart';
import 'package:famhub_app/features/marketplace/domain/enums/listing_status.dart';
import 'package:famhub_app/features/marketplace/domain/models/contact_unlock_payment.dart';
import 'package:famhub_app/features/marketplace/presentation/widgets/contact_unlock_section.dart';
import 'package:famhub_app/shared/demo/demo_marketplace_repository.dart';

Listing _listing({ListingStatus status = ListingStatus.active}) {
  return Listing(
    id: 'listing-1',
    title: 'Fresh Tomatoes',
    pricePerUnit: 150,
    currency: 'KES',
    images: const [],
    entityId: 'seller-1',
    variantId: 'variant-1',
    status: status,
    contactVisibility: 'locked',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

class _FakeContactUnlockRepository extends DemoMarketplaceRepository {
  ContactUnlockStatus? status;
  List<ContactUnlockStatus?>? statusSequence;
  SellerContact? contact;
  Object? statusError;
  Object? requestError;
  int statusFetchCount = 0;
  int requestCount = 0;
  Completer<ContactUnlockPayment>? requestGate;

  @override
  Future<ContactUnlockStatus?> fetchContactUnlockStatus(String listingId) async {
    final error = statusError;
    if (error != null) throw error;
    final sequence = statusSequence;
    if (sequence != null && sequence.isNotEmpty) {
      final index = statusFetchCount.clamp(0, sequence.length - 1);
      statusFetchCount++;
      return sequence[index];
    }
    statusFetchCount++;
    return status;
  }

  @override
  Future<SellerContact> fetchSellerContactForUnlock(String listingId) async {
    final value = contact;
    if (value == null) throw Exception('Contact not available');
    return value;
  }

  @override
  Future<ContactUnlockPayment> requestContactUnlockPayment({
    required String listingId,
    required String phone,
    required String idempotencyKey,
  }) async {
    requestCount++;
    if (requestError != null) throw requestError!;
    final gate = requestGate;
    if (gate != null) return gate.future;
    return const ContactUnlockPayment(
      obligationId: 'obligation-1',
      paymentAttemptId: 'attempt-1',
      amount: 150,
      currency: 'KES',
      unlockStatus: 'payment_pending',
    );
  }
}

Future<void> _pumpSection(
  WidgetTester tester,
  _FakeContactUnlockRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        marketplaceRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: Scaffold(body: ContactUnlockSection(listing: _listing())),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('shows unlock action when no payment has started', (tester) async {
    final repository = _FakeContactUnlockRepository();
    await _pumpSection(tester, repository);

    expect(find.text('Unlock seller contact'), findsOneWidget);
    expect(find.text('Unlock contact'), findsOneWidget);
    expect(find.text('Payment pending'), findsNothing);
  });

  testWidgets('shows unavailable state for an inactive listing', (tester) async {
    final repository = _FakeContactUnlockRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketplaceRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ContactUnlockSection(
              listing: _listing(status: ListingStatus.inactive),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Contact unlock unavailable'), findsOneWidget);
  });

  testWidgets('shows retry when unlock status fails to load', (tester) async {
    final repository = _FakeContactUnlockRepository()
      ..statusError = Exception('network');
    await _pumpSection(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Could not load unlock status.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows pending state and refresh action', (tester) async {
    final repository = _FakeContactUnlockRepository()
      ..status = const ContactUnlockStatus(
        obligationId: 'obligation-1',
        paymentAttemptId: 'attempt-1',
        amount: 150,
        currency: 'KES',
        paymentStatus: 'pending',
        unlocked: false,
        attemptStatus: 'pending',
      );

    await _pumpSection(tester, repository);

    expect(find.text('Payment pending'), findsOneWidget);
    expect(find.text('Refresh status'), findsOneWidget);
    expect(find.text('Unlock contact'), findsNothing);
  });

  testWidgets('reveals seller contact only for confirmed unlock', (tester) async {
    final repository = _FakeContactUnlockRepository()
      ..status = const ContactUnlockStatus(
        obligationId: 'obligation-1',
        paymentAttemptId: 'attempt-1',
        amount: 150,
        currency: 'KES',
        paymentStatus: 'completed',
        unlocked: true,
        attemptStatus: 'succeeded',
      )
      ..contact = const SellerContact(
        sellerEntityId: 'seller-1',
        contactPerson: 'Jane Seller',
        email: 'jane@example.com',
        phone: '254712345678',
        businessName: 'Jane Farms',
        physicalAddress: 'Nairobi',
      );

    await _pumpSection(tester, repository);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Seller contact unlocked'), findsOneWidget);
    expect(find.text('254712345678'), findsOneWidget);
    expect(find.text('jane@example.com'), findsOneWidget);
  });

  testWidgets('shows retry after a failed payment', (tester) async {
    final repository = _FakeContactUnlockRepository()
      ..status = const ContactUnlockStatus(
        obligationId: 'obligation-1',
        paymentAttemptId: 'attempt-1',
        amount: 150,
        currency: 'KES',
        paymentStatus: 'failed',
        unlocked: false,
        attemptStatus: 'failed',
      );

    await _pumpSection(tester, repository);

    expect(find.text('Payment was not completed'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('polls while pending and stops on completion', (tester) async {
    final repository = _FakeContactUnlockRepository()
      ..statusSequence = [
        const ContactUnlockStatus(
          obligationId: 'obligation-1',
          paymentAttemptId: 'attempt-1',
          amount: 150,
          currency: 'KES',
          paymentStatus: 'pending',
          unlocked: false,
          attemptStatus: 'pending',
        ),
        const ContactUnlockStatus(
          obligationId: 'obligation-1',
          paymentAttemptId: 'attempt-1',
          amount: 150,
          currency: 'KES',
          paymentStatus: 'completed',
          unlocked: true,
          attemptStatus: 'succeeded',
        ),
      ]
      ..contact = const SellerContact(
        sellerEntityId: 'seller-1',
        contactPerson: 'Jane Seller',
        email: 'jane@example.com',
        phone: '254712345678',
        businessName: 'Jane Farms',
        physicalAddress: 'Nairobi',
      );

    await _pumpSection(tester, repository);
    expect(find.text('Payment pending'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Seller contact unlocked'), findsOneWidget);
    expect(repository.statusFetchCount, greaterThanOrEqualTo(2));
  });

  testWidgets('stops polling after a failed payment', (tester) async {
    final repository = _FakeContactUnlockRepository()
      ..statusSequence = [
        const ContactUnlockStatus(
          obligationId: 'obligation-1',
          paymentAttemptId: 'attempt-1',
          amount: 150,
          currency: 'KES',
          paymentStatus: 'pending',
          unlocked: false,
          attemptStatus: 'pending',
        ),
        const ContactUnlockStatus(
          obligationId: 'obligation-1',
          paymentAttemptId: 'attempt-1',
          amount: 150,
          currency: 'KES',
          paymentStatus: 'failed',
          unlocked: false,
          attemptStatus: 'failed',
        ),
      ];

    await _pumpSection(tester, repository);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Payment was not completed'), findsOneWidget);

    final fetchesAfterFailure = repository.statusFetchCount;
    await tester.pump(const Duration(seconds: 6));
    expect(repository.statusFetchCount, fetchesAfterFailure);
  });

  testWidgets('shows retryable provider-unavailable state', (tester) async {
    final repository = _FakeContactUnlockRepository()
      ..requestError = const ContactUnlockProviderUnavailable();
    await _pumpSection(tester, repository);

    await tester.tap(find.text('Unlock contact'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0712345678');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('M-Pesa temporarily unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Payment pending'), findsNothing);
  });

  testWidgets('disables repeated payment requests while submitting', (
    tester,
  ) async {
    final repository = _FakeContactUnlockRepository()
      ..requestGate = Completer<ContactUnlockPayment>();
    await _pumpSection(tester, repository);

    await tester.tap(find.text('Unlock contact'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '0712345678');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.requestCount, 1);
    expect(find.text('Starting…'), findsOneWidget);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    repository.requestGate!.complete(
      const ContactUnlockPayment(
        obligationId: 'obligation-1',
        paymentAttemptId: 'attempt-1',
        amount: 150,
        currency: 'KES',
        unlockStatus: 'payment_pending',
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  });
}
