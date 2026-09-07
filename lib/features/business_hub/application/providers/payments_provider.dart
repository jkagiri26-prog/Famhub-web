/// ============================================================
/// BUSINESS HUB — PAYMENTS PROVIDERS
/// ============================================================
///
/// Loads the active business's payment transactions from the canonical,
/// currency-aware `commerce.transactions` (scoped via the business's
/// seller profiles — the verified `supplier_id` relationship).
///
/// - `transactionsByBusinessProvider(entityId)` — family fetch.
/// - `activeBusinessTransactionsProvider` — reactive read that follows
///   `activeBusinessProvider` and refreshes on business switch.
///
/// Ownership stays server-side under RLS; no client `user_id` is sent.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/business_hub/domain/entities/business_transaction.dart';
import 'active_business_provider.dart';
import 'business_hub_repository_provider.dart';

/// Family provider: transactions for a specific business entity.
final transactionsByBusinessProvider =
    FutureProvider.family<List<BusinessTransaction>, String>(
        (ref, entityId) async {
  final repo = ref.watch(businessHubRepositoryProvider);
  return repo.fetchTransactions(entityId);
});

/// Reactive transactions for the ACTIVE business (follows the selected
/// business context). Empty list while no business is active.
final activeBusinessTransactionsProvider =
    Provider<AsyncValue<List<BusinessTransaction>>>((ref) {
  final active = ref.watch(activeBusinessProvider);
  if (active == null) return const AsyncValue.data([]);
  return ref.watch(transactionsByBusinessProvider(active.id));
});
