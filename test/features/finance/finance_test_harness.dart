import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/core/context_engine/controllers/context_controller.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/features/finance/domain/models/finance_obligation_balance.dart';
import 'package:famhub_app/features/finance/domain/models/finance_payment.dart';
import 'package:famhub_app/features/finance/domain/models/finance_payment_attempt.dart';
import 'package:famhub_app/features/finance/domain/models/finance_settlement.dart';
import 'package:famhub_app/features/finance/domain/repositories/finance_repository.dart';
import 'package:famhub_app/features/finance/infrastructure/data_sources/finance_remote_data_source.dart';

/// ============================================================
/// FINANCE TEST HARNESS
///
/// Hand-written fakes (no mocking package) mirroring the existing
/// Financing/Logistics test conventions.
/// ============================================================

const EntityContext signedInContext = EntityContext(
  userId: 'user-1',
  profileId: 'profile-1',
  entityId: 'entity-1',
  roleId: 'role-1',
  isGuest: false,
  isLoading: false,
);

const EntityContext guestContext = EntityContext(
  isGuest: true,
  isLoading: false,
);

Override contextOverride({EntityContext context = signedInContext}) {
  return contextProvider.overrideWith(() => _FixedContextController(context));
}

class _FixedContextController extends ContextController {
  _FixedContextController(this.context);

  final EntityContext context;

  @override
  EntityContext build() => context;
}

final sampleObligationBalance = FinanceObligationBalance(
  obligationId: 'obligation-1',
  payerEntityId: 'entity-1',
  payeeEntityId: 'entity-2',
  commercialOrderId: null,
  legacyOrderId: null,
  obligationType: FinanceObligationType.fee,
  status: FinanceObligationStatus.open,
  currency: 'KES',
  obligationAmount: 1500,
  totalSettlements: 500,
  outstandingBalance: 1000,
  settlementCount: 1,
  dueAt: DateTime.utc(2026, 11, 10),
  createdAt: DateTime.utc(2026, 11, 9),
  updatedAt: DateTime.utc(2026, 11, 9, 1),
);

final sampleSettlement = FinanceSettlement(
  id: 'settlement-1',
  obligationId: 'obligation-1',
  paymentId: 'payment-1',
  currency: 'KES',
  amount: 500,
  settledAt: DateTime.utc(2026, 11, 9, 2),
);

final samplePayment = FinancePayment(
  paymentId: 'payment-1',
  provider: 'mpesa',
  providerReference: 'SFC123',
  amount: 500,
  currency: 'KES',
  payerEntityId: 'entity-1',
  payeeEntityId: 'entity-2',
  verifiedAt: DateTime.utc(2026, 11, 9, 2),
  createdAt: DateTime.utc(2026, 11, 9, 1),
  collectionRecordStatus: 'verified_payment_record',
  bankSettlementStatus: 'not_established_by_payment_record',
);

final samplePaymentAttempt = FinancePaymentAttempt(
  paymentAttemptId: 'attempt-1',
  obligationId: 'obligation-1',
  status: FinancePaymentAttemptStatus.failed,
  amount: 500,
  currency: 'KES',
  createdAt: DateTime.utc(2026, 11, 9),
  updatedAt: DateTime.utc(2026, 11, 9, 1),
  completedAt: DateTime.utc(2026, 11, 9, 1),
  failureState: 'failed',
);

/// In-memory repository double. Nothing is persisted and no database is used.
class FakeFinanceRepository implements FinanceRepository {
  FakeFinanceRepository({
    List<FinanceObligationBalance>? obligationBalances,
    List<FinanceSettlement>? settlements,
    List<FinancePayment>? payments,
    this.attemptStatus,
  }) : obligationBalances = obligationBalances ?? const [],
       settlements = settlements ?? const [],
       payments = payments ?? const [];

  List<FinanceObligationBalance> obligationBalances;
  List<FinanceSettlement> settlements;
  List<FinancePayment> payments;
  FinancePaymentAttempt? attemptStatus;

  Future<List<FinanceObligationBalance>> Function()? onObligationBalances;
  Future<List<FinanceSettlement>> Function(String obligationId)?
  onSettlementHistory;
  Future<List<FinancePayment>> Function()? onVerifiedPayments;
  Future<FinancePaymentAttempt?> Function(String attemptId)?
  onPaymentAttemptStatus;

  int obligationBalanceCalls = 0;
  int settlementHistoryCalls = 0;
  int verifiedPaymentCalls = 0;
  int paymentAttemptStatusCalls = 0;

  String? lastSettlementObligationId;
  String? lastPaymentAttemptId;

  @override
  Future<List<FinanceObligationBalance>> fetchObligationBalances() {
    obligationBalanceCalls++;
    final handler = onObligationBalances;
    if (handler != null) return handler();
    return Future.value(obligationBalances);
  }

  @override
  Future<List<FinanceSettlement>> fetchSettlementHistory(String obligationId) {
    settlementHistoryCalls++;
    lastSettlementObligationId = obligationId;
    final handler = onSettlementHistory;
    if (handler != null) return handler(obligationId);
    return Future.value(settlements);
  }

  @override
  Future<List<FinancePayment>> fetchVerifiedPaymentCollections() {
    verifiedPaymentCalls++;
    final handler = onVerifiedPayments;
    if (handler != null) return handler();
    return Future.value(payments);
  }

  @override
  Future<FinancePaymentAttempt?> fetchPaymentAttemptStatus(
    String paymentAttemptId,
  ) {
    paymentAttemptStatusCalls++;
    lastPaymentAttemptId = paymentAttemptId;
    final handler = onPaymentAttemptStatus;
    if (handler != null) return handler(paymentAttemptId);
    return Future.value(attemptStatus);
  }
}

/// Data-source double used only for repository error-mapping tests.
///
/// The Supabase client is a local dummy; no method calls it.
class FakeFinanceRemoteDataSource extends FinanceRemoteDataSource {
  FakeFinanceRemoteDataSource()
    : super(client: SupabaseClient('https://localhost', 'local-test-key'));

  List<FinanceObligationBalance> obligationBalances = const [];
  List<FinanceSettlement> settlements = const [];
  List<FinancePayment> payments = const [];
  FinancePaymentAttempt? attemptStatus;

  Future<List<FinanceObligationBalance>> Function()? onObligationBalances;
  Future<List<FinanceSettlement>> Function(String obligationId)?
  onSettlementHistory;
  Future<List<FinancePayment>> Function()? onVerifiedPayments;
  Future<FinancePaymentAttempt?> Function(String attemptId)?
  onPaymentAttemptStatus;

  @override
  Future<List<FinanceObligationBalance>> fetchObligationBalances() {
    final handler = onObligationBalances;
    if (handler != null) return handler();
    return Future.value(obligationBalances);
  }

  @override
  Future<List<FinanceSettlement>> fetchSettlementHistory(String obligationId) {
    final handler = onSettlementHistory;
    if (handler != null) return handler(obligationId);
    return Future.value(settlements);
  }

  @override
  Future<List<FinancePayment>> fetchVerifiedPaymentCollections() {
    final handler = onVerifiedPayments;
    if (handler != null) return handler();
    return Future.value(payments);
  }

  @override
  Future<FinancePaymentAttempt?> fetchPaymentAttemptStatus(
    String paymentAttemptId,
  ) {
    final handler = onPaymentAttemptStatus;
    if (handler != null) return handler(paymentAttemptId);
    return Future.value(attemptStatus);
  }
}
