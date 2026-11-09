/// ============================================================
/// FINANCE — SETTLEMENT HISTORY SHEET
/// ============================================================
///
/// Read-only settlement history for one obligation, sourced from
/// `finance.v_obligation_settlement_history` through the Finance providers.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/finance/application/providers/finance_read_providers.dart';
import 'package:famhub_app/features/finance/domain/models/finance_obligation_balance.dart';
import 'package:famhub_app/features/finance/domain/models/finance_settlement.dart';
import 'package:famhub_app/shared/widgets/states/states.dart';

class FinanceSettlementSheet extends ConsumerWidget {
  final FinanceObligationBalance obligation;

  const FinanceSettlementSheet({super.key, required this.obligation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlements = ref.watch(
      financeSettlementHistoryProvider(obligation.obligationId),
    );

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Settlement history',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '${obligation.currency} ${obligation.obligationAmount.toStringAsFixed(2)} '
                'obligation · ${obligation.settlementCount} settlement'
                '${obligation.settlementCount == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: settlements.when(
                  loading: () => const LoadingStateWidget(
                    message: 'Loading settlement history...',
                  ),
                  error: (error, _) => ErrorStateWidget(
                    title: 'Could not load settlements',
                    message: 'Settlement history is not available right now.',
                    retryLabel: 'Retry',
                    onRetry: () => ref.invalidate(
                      financeSettlementHistoryProvider(obligation.obligationId),
                    ),
                  ),
                  data: (rows) {
                    if (rows.isEmpty) {
                      return const EmptyStateWidget(
                        icon: Icons.receipt_long_outlined,
                        title: 'No settlements yet',
                        subtitle:
                            'Settlements recorded against this obligation '
                            'will appear here.',
                      );
                    }
                    return ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _SettlementTile(settlement: rows[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettlementTile extends StatelessWidget {
  final FinanceSettlement settlement;

  const _SettlementTile({required this.settlement});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 19,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${settlement.currency} ${settlement.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Payment ${_shortId(settlement.paymentId)}',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            _formatDate(settlement.settledAt),
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

String _shortId(String value) {
  if (value.length <= 8) return value;
  return value.substring(0, 8);
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
