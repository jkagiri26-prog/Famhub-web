import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/finance/domain/models/finance_obligation_balance.dart';
import 'package:famhub_app/features/finance/domain/models/finance_payment.dart';
import 'package:famhub_app/features/finance/domain/models/finance_payment_attempt.dart';
import 'package:famhub_app/features/finance/domain/models/finance_settlement.dart';

void main() {
  group('FinanceObligationBalance parsing', () {
    test('parses the deployed v_obligation_balances shape', () {
      final balance = FinanceObligationBalance.fromMap({
        'obligation_id': 'obligation-1',
        'payer_entity_id': 'entity-1',
        'payee_entity_id': 'entity-2',
        'commercial_order_id': 'order-1',
        'legacy_order_id': null,
        'obligation_type': 'fee',
        'obligation_status': 'partially_settled',
        'currency': 'KES',
        'obligation_amount': '1500.50',
        'total_settlements': 500,
        'outstanding_balance': 1000.50,
        'settlement_count': 1,
        'due_at': '2026-11-10T00:00:00Z',
        'created_at': '2026-11-09T00:00:00Z',
        'updated_at': '2026-11-09T01:00:00Z',
      });

      expect(balance.obligationId, 'obligation-1');
      expect(balance.payerEntityId, 'entity-1');
      expect(balance.payeeEntityId, 'entity-2');
      expect(balance.commercialOrderId, 'order-1');
      expect(balance.legacyOrderId, isNull);
      expect(balance.obligationType, FinanceObligationType.fee);
      expect(balance.status, FinanceObligationStatus.partiallySettled);
      expect(balance.currency, 'KES');
      expect(balance.obligationAmount, 1500.50);
      expect(balance.totalSettlements, 500);
      expect(balance.outstandingBalance, 1000.50);
      expect(balance.settlementCount, 1);
      expect(balance.dueAt, DateTime.utc(2026, 11, 10));
      expect(balance.isSettled, isFalse);
      expect(balance.hasOutstandingBalance, isTrue);
    });

    test('maps void and unknown statuses safely', () {
      final voided = FinanceObligationBalance.fromMap({
        'obligation_id': 'o-1',
        'payer_entity_id': 'e-1',
        'payee_entity_id': 'e-2',
        'obligation_type': 'other',
        'obligation_status': 'void',
        'currency': 'KES',
        'obligation_amount': 10,
        'total_settlements': 0,
        'outstanding_balance': 10,
        'settlement_count': 0,
        'created_at': '2026-11-09T00:00:00Z',
        'updated_at': '2026-11-09T00:00:00Z',
      });
      expect(voided.status, FinanceObligationStatus.voided);

      final unknown = FinanceObligationBalance.fromMap({
        'obligation_id': 'o-2',
        'payer_entity_id': 'e-1',
        'payee_entity_id': 'e-2',
        'obligation_type': 'future_type',
        'obligation_status': 'future_status',
        'currency': 'KES',
        'obligation_amount': 10,
        'total_settlements': 0,
        'outstanding_balance': 10,
        'settlement_count': 0,
        'created_at': '2026-11-09T00:00:00Z',
        'updated_at': '2026-11-09T00:00:00Z',
      });
      expect(unknown.obligationType, FinanceObligationType.other);
      expect(unknown.status, FinanceObligationStatus.draft);
    });
  });

  group('FinanceSettlement parsing', () {
    test('parses the deployed settlement history shape', () {
      final settlement = FinanceSettlement.fromMap({
        'id': 'settlement-1',
        'obligation_id': 'obligation-1',
        'payment_id': 'payment-1',
        'currency': 'KES',
        'amount': '250.75',
        'settled_at': '2026-11-09T02:00:00Z',
      });

      expect(settlement.id, 'settlement-1');
      expect(settlement.obligationId, 'obligation-1');
      expect(settlement.paymentId, 'payment-1');
      expect(settlement.currency, 'KES');
      expect(settlement.amount, 250.75);
      expect(settlement.settledAt, DateTime.utc(2026, 11, 9, 2));
    });
  });

  group('FinancePayment parsing', () {
    test('parses the deployed verified collections shape', () {
      final payment = FinancePayment.fromMap({
        'payment_id': 'payment-1',
        'provider': 'mpesa',
        'provider_reference': 'SFC123',
        'amount': 500,
        'currency': 'KES',
        'payer_entity_id': 'entity-1',
        'payee_entity_id': 'entity-2',
        'verified_at': '2026-11-09T02:00:00Z',
        'created_at': '2026-11-09T01:00:00Z',
        'collection_record_status': 'verified_payment_record',
        'bank_settlement_status': 'not_established_by_payment_record',
      });

      expect(payment.paymentId, 'payment-1');
      expect(payment.provider, 'mpesa');
      expect(payment.providerReference, 'SFC123');
      expect(payment.amount, 500);
      expect(payment.currency, 'KES');
      expect(payment.payerEntityId, 'entity-1');
      expect(payment.payeeEntityId, 'entity-2');
      expect(payment.verifiedAt, DateTime.utc(2026, 11, 9, 2));
      expect(payment.collectionRecordStatus, 'verified_payment_record');
      expect(payment.bankSettlementStatus, 'not_established_by_payment_record');
      expect(payment.isVerified, isTrue);
    });

    test('allows an unverified timestamp and missing provider reference', () {
      final payment = FinancePayment.fromMap({
        'payment_id': 'payment-2',
        'provider': 'bank',
        'provider_reference': null,
        'amount': 100,
        'currency': 'KES',
        'payer_entity_id': 'entity-1',
        'payee_entity_id': 'entity-2',
        'verified_at': null,
        'created_at': '2026-11-09T01:00:00Z',
      });

      expect(payment.providerReference, isNull);
      expect(payment.verifiedAt, isNull);
      expect(payment.isVerified, isFalse);
      expect(payment.collectionRecordStatus, isNull);
      expect(payment.bankSettlementStatus, isNull);
    });
  });

  group('FinancePaymentAttempt parsing', () {
    test('parses the safe get_payment_attempt_status shape', () {
      final attempt = FinancePaymentAttempt.fromMap({
        'payment_attempt_id': 'attempt-1',
        'obligation_id': 'obligation-1',
        'status': 'failed',
        'amount': 500,
        'currency': 'KES',
        'created_at': '2026-11-09T00:00:00Z',
        'updated_at': '2026-11-09T01:00:00Z',
        'completed_at': '2026-11-09T01:00:00Z',
        'failure_state': 'failed',
      });

      expect(attempt.paymentAttemptId, 'attempt-1');
      expect(attempt.obligationId, 'obligation-1');
      expect(attempt.status, FinancePaymentAttemptStatus.failed);
      expect(attempt.amount, 500);
      expect(attempt.currency, 'KES');
      expect(attempt.completedAt, DateTime.utc(2026, 11, 9, 1));
      expect(attempt.failureState, 'failed');
      expect(attempt.hasFailed, isTrue);
      expect(attempt.isTerminal, isTrue);
    });

    test('treats a non-failed failure_state as safe/null', () {
      final attempt = FinancePaymentAttempt.fromMap({
        'payment_attempt_id': 'attempt-2',
        'obligation_id': 'obligation-1',
        'status': 'processing',
        'amount': 500,
        'currency': 'KES',
        'created_at': '2026-11-09T00:00:00Z',
        'updated_at': '2026-11-09T01:00:00Z',
        'completed_at': null,
        'failure_state': null,
      });

      expect(attempt.status, FinancePaymentAttemptStatus.processing);
      expect(attempt.failureState, isNull);
      expect(attempt.hasFailed, isFalse);
      expect(attempt.isTerminal, isFalse);
    });
  });
}
