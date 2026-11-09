/// ============================================================
/// FINANCE — ACCOUNT (READ-ONLY)
/// ============================================================
///
/// First Finance user interface. It surfaces:
///   - outstanding obligations and balances
///   - settlement history for a selected obligation
///   - verified payment collections
///   - safe payment-attempt status by attempt id
///
/// Architecture:
///   - No Scaffold / AppBar / Drawer / BottomNavigationBar
///   - ResponsiveWrapper enforced
///   - Reads only the existing Finance providers/repository
///   - RLS and the authenticated status RPC remain the authorization boundary
///   - The active entity is a party-scoping/labelling aid, never an ownership
///     claim; both payer-side and payee-side rows remain visible.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/features/finance/application/providers/finance_read_providers.dart';
import 'package:famhub_app/features/finance/domain/models/finance_obligation_balance.dart';
import 'package:famhub_app/features/finance/domain/models/finance_payment.dart';
import 'package:famhub_app/features/finance/presentation/widgets/finance_attempt_status_panel.dart';
import 'package:famhub_app/features/finance/presentation/widgets/finance_obligation_card.dart';
import 'package:famhub_app/features/finance/presentation/widgets/finance_payment_card.dart';
import 'package:famhub_app/features/finance/presentation/widgets/finance_settlement_sheet.dart';
import 'package:famhub_app/features/workspace_context/presentation/widgets/entity_selector.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/states.dart';

class FinanceAccountPage extends ConsumerWidget {
  const FinanceAccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entityContext = ref.watch(contextProvider);

    if (entityContext.isLoading) {
      return const ResponsiveWrapper(
        child: LoadingStateWidget(message: 'Loading your finance account...'),
      );
    }
    if (entityContext.isGuest) {
      return const ResponsiveWrapper(
        child: PermissionDeniedWidget(
          title: 'Finance locked',
          message: 'Sign in to view obligations, payments and payment status.',
        ),
      );
    }

    final balances = ref.watch(financeObligationBalancesProvider);
    final payments = ref.watch(financeVerifiedPaymentCollectionsProvider);
    final activeEntityId = entityContext.entityId;

    return ResponsiveWrapper(
      child: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModuleHeaderWidget(
              title: 'My Finance',
              subtitle: 'Obligations, payments and payment status',
              trailingIcon: Icons.refresh,
              onTrailingTap: () {
                ref.invalidate(financeObligationBalancesProvider);
                ref.invalidate(financeVerifiedPaymentCollectionsProvider);
              },
            ),
            const EntitySelector(),
            const SizedBox(height: 4),
            _SummaryStrip(
              balances: balances,
              payments: payments,
              activeEntityId: activeEntityId,
            ),
            if (activeEntityId == null || activeEntityId.isEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'No active entity is selected. Showing all records visible '
                'to your account.',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 8),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Obligations'),
                Tab(text: 'Payments'),
                Tab(text: 'Attempt status'),
              ],
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: TabBarView(
                children: [
                  _ObligationsTab(),
                  _PaymentsTab(),
                  FinanceAttemptStatusPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final AsyncValue<List<FinanceObligationBalance>> balances;
  final AsyncValue<List<FinancePayment>> payments;
  final String? activeEntityId;

  const _SummaryStrip({
    required this.balances,
    required this.payments,
    required this.activeEntityId,
  });

  @override
  Widget build(BuildContext context) {
    final visibleBalances = _visibleObligations(
      balances.value ?? const [],
      activeEntityId,
    );
    final visiblePayments = _visiblePayments(
      payments.value ?? const [],
      activeEntityId,
    );

    final openCount = visibleBalances
        .where(
          (balance) =>
              balance.status == FinanceObligationStatus.open ||
              balance.status == FinanceObligationStatus.partiallySettled,
        )
        .length;

    final outstandingByCurrency = <String, double>{};
    for (final balance in visibleBalances) {
      if (balance.outstandingBalance <= 0) continue;
      outstandingByCurrency.update(
        balance.currency,
        (value) => value + balance.outstandingBalance,
        ifAbsent: () => balance.outstandingBalance,
      );
    }
    final outstandingLabel = balances.isLoading
        ? '…'
        : outstandingByCurrency.isEmpty
        ? 'None'
        : outstandingByCurrency.entries
              .map((entry) => '${entry.key} ${entry.value.toStringAsFixed(2)}')
              .join(' · ');

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetricChip(
          label: 'Open obligations',
          value: balances.isLoading ? '…' : '$openCount',
          icon: Icons.assignment_outlined,
        ),
        _MetricChip(
          label: 'Outstanding',
          value: outstandingLabel,
          icon: Icons.account_balance_wallet_outlined,
        ),
        _MetricChip(
          label: 'Verified payments',
          value: payments.isLoading ? '…' : '${visiblePayments.length}',
          icon: Icons.verified_outlined,
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ObligationsTab extends ConsumerWidget {
  const _ObligationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeEntityId = ref.watch(
      contextProvider.select((context) => context.entityId),
    );
    final balances = ref.watch(financeObligationBalancesProvider);

    return balances.when(
      loading: () =>
          const LoadingStateWidget(message: 'Loading obligations...'),
      error: (error, _) => ErrorStateWidget(
        title: 'Could not load obligations',
        message: 'Obligation balances are not available right now.',
        retryLabel: 'Retry',
        onRetry: () => ref.invalidate(financeObligationBalancesProvider),
      ),
      data: (rows) {
        final visible = _visibleObligations(rows, activeEntityId);
        if (visible.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.assignment_outlined,
            title: 'No obligations',
            subtitle:
                'Obligations where your entities are payer or payee will '
                'appear here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: visible.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final obligation = visible[index];
            return FinanceObligationCard(
              obligation: obligation,
              activeEntityId: activeEntityId,
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => FinanceSettlementSheet(obligation: obligation),
              ),
            );
          },
        );
      },
    );
  }
}

class _PaymentsTab extends ConsumerWidget {
  const _PaymentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeEntityId = ref.watch(
      contextProvider.select((context) => context.entityId),
    );
    final payments = ref.watch(financeVerifiedPaymentCollectionsProvider);

    return payments.when(
      loading: () =>
          const LoadingStateWidget(message: 'Loading verified payments...'),
      error: (error, _) => ErrorStateWidget(
        title: 'Could not load payments',
        message: 'Verified payment collections are not available right now.',
        retryLabel: 'Retry',
        onRetry: () =>
            ref.invalidate(financeVerifiedPaymentCollectionsProvider),
      ),
      data: (rows) {
        final visible = _visiblePayments(rows, activeEntityId);
        if (visible.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.payments_outlined,
            title: 'No verified payments',
            subtitle:
                'Verified collections where your entities are payer or payee '
                'will appear here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: visible.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            return FinancePaymentCard(
              payment: visible[index],
              activeEntityId: activeEntityId,
            );
          },
        );
      },
    );
  }
}

List<FinanceObligationBalance> _visibleObligations(
  List<FinanceObligationBalance> rows,
  String? activeEntityId,
) {
  if (activeEntityId == null || activeEntityId.isEmpty) return rows;
  return rows
      .where(
        (row) =>
            row.payerEntityId == activeEntityId ||
            row.payeeEntityId == activeEntityId,
      )
      .toList();
}

List<FinancePayment> _visiblePayments(
  List<FinancePayment> rows,
  String? activeEntityId,
) {
  if (activeEntityId == null || activeEntityId.isEmpty) return rows;
  return rows
      .where(
        (row) =>
            row.payerEntityId == activeEntityId ||
            row.payeeEntityId == activeEntityId,
      )
      .toList();
}
