/// ============================================================
/// FINANCE — READ-ONLY PROVIDERS
/// ============================================================
///
/// Async reads for the first Finance integration phase:
///   - obligation balances
///   - settlement history by obligation
///   - verified payment collections
///   - payment-attempt status by attempt id
///
/// Authorization remains entirely server-side: these providers only use the
/// authenticated Supabase session, the security_invoker Finance views, and
/// the authenticated status RPC. Guest sessions resolve to empty/null
/// results rather than issuing unauthorized requests.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/features/finance/application/providers/finance_repository_provider.dart';
import 'package:famhub_app/features/finance/domain/models/finance_obligation_balance.dart';
import 'package:famhub_app/features/finance/domain/models/finance_payment.dart';
import 'package:famhub_app/features/finance/domain/models/finance_payment_attempt.dart';
import 'package:famhub_app/features/finance/domain/models/finance_settlement.dart';

/// All obligation balances visible to the authenticated caller.
final financeObligationBalancesProvider =
    FutureProvider<List<FinanceObligationBalance>>((ref) async {
      final context = ref.watch(contextProvider);
      if (context.isGuest) return const [];

      return ref.watch(financeRepositoryProvider).fetchObligationBalances();
    });

/// Settlement history for one obligation.
final financeSettlementHistoryProvider =
    FutureProvider.family<List<FinanceSettlement>, String>((
      ref,
      obligationId,
    ) async {
      if (obligationId.isEmpty) return const [];

      final context = ref.watch(contextProvider);
      if (context.isGuest) return const [];

      return ref
          .watch(financeRepositoryProvider)
          .fetchSettlementHistory(obligationId);
    });

/// Verified payment collections visible to the authenticated caller.
final financeVerifiedPaymentCollectionsProvider =
    FutureProvider<List<FinancePayment>>((ref) async {
      final context = ref.watch(contextProvider);
      if (context.isGuest) return const [];

      return ref
          .watch(financeRepositoryProvider)
          .fetchVerifiedPaymentCollections();
    });

/// Safe status for one payment attempt.
///
/// Null means the status function returned no row: unknown attempt, not the
/// caller's attempt, or no active payer-entity membership.
final financePaymentAttemptStatusProvider =
    FutureProvider.family<FinancePaymentAttempt?, String>((
      ref,
      paymentAttemptId,
    ) async {
      if (paymentAttemptId.isEmpty) return null;

      final context = ref.watch(contextProvider);
      if (context.isGuest) return null;

      return ref
          .watch(financeRepositoryProvider)
          .fetchPaymentAttemptStatus(paymentAttemptId);
    });
