import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/marketplace/domain/models/contact_unlock_payment.dart';
import 'package:famhub_app/features/marketplace/domain/models/mpesa_phone.dart';
import 'package:famhub_app/features/marketplace/infrastructure/data_sources/marketplace_remote_data_source.dart';
import 'package:famhub_app/features/marketplace/infrastructure/repositories/marketplace_repository_impl.dart';

void main() {
  group('ContactUnlockPayment', () {
    test('parses a pending payment attempt', () {
      final payment = ContactUnlockPayment.fromJson({
        'obligation_id': 'obligation-1',
        'payment_attempt_id': 'attempt-1',
        'amount': 150,
        'currency': 'KES',
        'unlock_status': 'payment_pending',
      });

      expect(payment.obligationId, 'obligation-1');
      expect(payment.paymentAttemptId, 'attempt-1');
      expect(payment.amount, 150);
      expect(payment.currency, 'KES');
      expect(payment.unlockStatus, 'payment_pending');
      expect(payment.isAlreadyUnlocked, isFalse);
      expect(payment.hasPaymentAttempt, isTrue);
    });

    test('parses an already-unlocked result without an attempt', () {
      final payment = ContactUnlockPayment.fromJson({
        'obligation_id': 'obligation-1',
        'payment_attempt_id': null,
        'amount': 150,
        'currency': 'KES',
        'unlock_status': 'already_unlocked',
      });

      expect(payment.isAlreadyUnlocked, isTrue);
      expect(payment.hasPaymentAttempt, isFalse);
    });
  });

  group('normalizeKenyanMpesaPhone', () {
    test('accepts local and international formats', () {
      expect(normalizeKenyanMpesaPhone('0712 345 678'), '254712345678');
      expect(normalizeKenyanMpesaPhone('712345678'), '254712345678');
      expect(normalizeKenyanMpesaPhone('+254 712 345 678'), '254712345678');
      expect(normalizeKenyanMpesaPhone('254-712-345-678'), '254712345678');
    });

    test('rejects invalid numbers', () {
      expect(normalizeKenyanMpesaPhone(''), isNull);
      expect(normalizeKenyanMpesaPhone('0712345'), isNull);
      expect(normalizeKenyanMpesaPhone('0812345678'), isNull);
      expect(normalizeKenyanMpesaPhone('254812345678'), isNull);
    });
  });

  group('SellerContact', () {
    test('parses seller contact details', () {
      final contact = SellerContact.fromJson({
        'seller_entity_id': 'seller-1',
        'contact_person': 'Jane Seller',
        'email': 'jane@example.com',
        'phone': '254712345678',
        'business_name': 'Jane Farms',
        'physical_address': 'Nairobi',
      });

      expect(contact.sellerEntityId, 'seller-1');
      expect(contact.contactPerson, 'Jane Seller');
      expect(contact.email, 'jane@example.com');
      expect(contact.phone, '254712345678');
      expect(contact.businessName, 'Jane Farms');
      expect(contact.physicalAddress, 'Nairobi');
    });
  });

  group('ContactUnlockStatus', () {
    test('parses completed unlock state', () {
      final status = ContactUnlockStatus.fromJson({
        'obligation_id': 'obligation-1',
        'payment_attempt_id': 'attempt-1',
        'amount': 150,
        'currency': 'KES',
        'payment_status': 'completed',
        'unlocked': true,
        'attempt_status': 'succeeded',
      });

      expect(status.isUnlocked, isTrue);
      expect(status.paymentStatus, 'completed');
      expect(status.attemptStatus, 'succeeded');
    });

    test('parses pending unlock state', () {
      final status = ContactUnlockStatus.fromJson({
        'obligation_id': 'obligation-1',
        'payment_attempt_id': 'attempt-1',
        'amount': 150,
        'currency': 'KES',
        'payment_status': 'pending',
        'unlocked': false,
        'attempt_status': 'pending',
      });

      expect(status.isUnlocked, isFalse);
      expect(status.paymentStatus, 'pending');
      expect(status.attemptStatus, 'pending');
    });
  });

  group('contact-unlock repository flow', () {
    test('invokes the Edge Function after the Finance attempt is created', () async {
      final dataSource = _FakeContactUnlockDataSource();
      final repository = MarketplaceRepositoryImpl(dataSource);

      final payment = await repository.requestContactUnlockPayment(
        listingId: 'listing-1',
        phone: '254712345678',
        idempotencyKey: 'idem-1',
      );

      expect(payment.paymentAttemptId, 'attempt-1');
      expect(dataSource.initiationCalls, 1);
      expect(dataSource.lastPhone, '254712345678');
      expect(dataSource.lastAmount, 150);
      expect(dataSource.lastCurrency, 'KES');
    });

    test('skips provider initiation when already unlocked', () async {
      final dataSource = _FakeContactUnlockDataSource(alreadyUnlocked: true);
      final repository = MarketplaceRepositoryImpl(dataSource);

      final payment = await repository.requestContactUnlockPayment(
        listingId: 'listing-1',
        phone: '254712345678',
        idempotencyKey: 'idem-2',
      );

      expect(payment.isAlreadyUnlocked, isTrue);
      expect(dataSource.initiationCalls, 0);
    });

    test('recognizes provider-unconfigured 503 details', () {
      expect(
        MarketplaceRemoteDataSource.isProviderUnconfigured(
          const FunctionException(
            status: 503,
            details: {'error': 'mpesa_provider_not_configured'},
          ),
        ),
        isTrue,
      );
      expect(
        MarketplaceRemoteDataSource.isProviderUnconfigured(
          const FunctionException(status: 503, details: 'other'),
        ),
        isFalse,
      );
    });
  });
}


class _FakeContactUnlockDataSource extends MarketplaceRemoteDataSource {
  _FakeContactUnlockDataSource({this.alreadyUnlocked = false})
    : super(client: SupabaseClient('https://localhost', 'anon-key'));

  final bool alreadyUnlocked;
  int initiationCalls = 0;
  String? lastPhone;
  double? lastAmount;
  String? lastCurrency;

  @override
  Future<Map<String, dynamic>?> requestContactUnlockPayment({
    required String listingId,
    required String phone,
    required String idempotencyKey,
  }) async {
    return {
      'obligation_id': 'obligation-1',
      'payment_attempt_id': alreadyUnlocked ? null : 'attempt-1',
      'amount': 150,
      'currency': 'KES',
      'unlock_status': alreadyUnlocked ? 'already_unlocked' : 'payment_pending',
    };
  }

  @override
  Future<void> initiateContactUnlockMpesa({
    required String paymentAttemptId,
    required String obligationId,
    required String phone,
    required double amount,
    required String currency,
  }) async {
    initiationCalls++;
    lastPhone = phone;
    lastAmount = amount;
    lastCurrency = currency;
  }
}
