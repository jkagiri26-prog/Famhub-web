/// ============================================================
/// BUSINESS HUB — PAYMENTS TAB
/// ============================================================
///
/// Read-only payment visibility for the ACTIVE business.
///
/// Data source: canonical, currency-aware `commerce.transactions`,
/// scoped by the verified `supplier_id` FK →
/// `commerce.business_profiles` of the active business (business of
/// record).
///
/// Content:
///   - Compact summary COUNTS (transactions / completed / pending /
///     failed / refunded) — real status enum, no amounts summed.
///   - Compact rows: reference → date + method → amount + currency →
///     status.
///   - Lightweight read-only detail bottom sheet (verified fields only).
///
/// Boundary: this is visibility only. Wallets, reconciliation,
/// invoicing, payouts, refunds, financing and financial reporting belong
/// to Finance or a specialist capability — never here.
///
/// Currency: amounts are shown per row with their REAL backend currency
/// code. No currency symbol is invented and no cross-currency totals are
/// computed.
///
/// States: loading / loaded / empty / error. Guests see demo data via
/// the demo repository.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';

import '../../application/providers/active_business_provider.dart';
import '../../application/providers/payments_provider.dart';
import '../../domain/entities/business_transaction.dart';
import '../../domain/models/payments_summary.dart';

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

String _formatAmount(double value) {
  final whole = value.round();
  final digits = whole.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return whole < 0 ? '-$buffer' : buffer.toString();
}

String _methodLabel(String method) {
  switch (method) {
    case 'mpesa':
      return 'M-Pesa';
    case 'visa':
      return 'Visa';
    case 'bank':
      return 'Bank';
    case 'card':
      return 'Card';
    default:
      return method.isEmpty ? '—' : method;
  }
}

class BusinessHubPaymentsTab extends ConsumerWidget {
  const BusinessHubPaymentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeBusinessProvider);
    if (active == null) {
      return const EmptyStateWidget(
        icon: Icons.business_outlined,
        title: 'No active business',
        subtitle: 'Select a business to view its payments.',
      );
    }

    final transactionsAsync = ref.watch(activeBusinessTransactionsProvider);

    return transactionsAsync.when(
      loading: () => const LoadingStateWidget(
        message: 'Loading transactions...',
      ),
      error: (e, _) => ErrorStateWidget(
        title: 'Failed to Load',
        message: 'Could not load payments for ${active.name}.',
        retryLabel: 'Retry',
        onRetry: () =>
            ref.invalidate(transactionsByBusinessProvider(active.id)),
        detailedError: e.toString(),
      ),
      data: (transactions) {
        if (transactions.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.payments_outlined,
            title: 'No payment transactions yet',
            subtitle: 'Transactions under this business\'s seller profile '
                'appear here (commerce.transactions).',
          );
        }
        return _PaymentsLoaded(transactions: transactions);
      },
    );
  }
}

/// ============================================================
/// LOADED STATE
/// ============================================================
class _PaymentsLoaded extends ConsumerWidget {
  final List<BusinessTransaction> transactions;

  const _PaymentsLoaded({required this.transactions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = PaymentsSummary.from(transactions);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Compact summary chips (counts only) ──
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(
                label: 'Transactions',
                value: '${summary.totalCount}',
                color: theme.colorScheme.primary,
              ),
              if (summary.completedCount > 0)
                _SummaryChip(
                  label: 'Completed',
                  value: '${summary.completedCount}',
                  color: Colors.green,
                ),
              if (summary.pendingCount > 0)
                _SummaryChip(
                  label: 'Pending',
                  value: '${summary.pendingCount}',
                  color: Colors.orange,
                ),
              if (summary.failedCount > 0)
                _SummaryChip(
                  label: 'Failed',
                  value: '${summary.failedCount}',
                  color: Colors.red,
                ),
              if (summary.refundedCount > 0)
                _SummaryChip(
                  label: 'Refunded',
                  value: '${summary.refundedCount}',
                  color: Colors.grey,
                ),
            ],
          ),
        ),

        // ── Compact transaction list ──
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return _TransactionRow(
                transaction: transaction,
                onTap: () => _showDetail(context, transaction),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDetail(BuildContext context, BusinessTransaction transaction) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _TransactionDetailSheet(transaction: transaction),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// TRANSACTION ROW
/// ============================================================
class _TransactionRow extends StatelessWidget {
  final BusinessTransaction transaction;
  final VoidCallback onTap;

  const _TransactionRow({
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reference = transaction.transactionRef;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.payments_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reference != null && reference.trim().isNotEmpty
                          ? reference
                          : 'Payment transaction',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDate(transaction.transactionDate)} · '
                      '${_methodLabel(transaction.paymentMethod)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${transaction.currency.trim()} '
                    '${_formatAmount(transaction.amount)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _StatusPill(transaction: transaction),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final BusinessTransaction transaction;

  const _StatusPill({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusOf(transaction);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  (String, Color) _statusOf(BusinessTransaction transaction) {
    if (transaction.isCompleted) return ('Completed', Colors.green.shade700);
    if (transaction.isPending) return ('Pending', Colors.orange.shade800);
    if (transaction.isRefunded) return ('Refunded', Colors.grey);
    return ('Failed', Colors.red.shade600);
  }
}

/// ============================================================
/// TRANSACTION DETAIL SHEET (read-only)
/// ============================================================
class _TransactionDetailSheet extends StatelessWidget {
  final BusinessTransaction transaction;

  const _TransactionDetailSheet({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reference = transaction.transactionRef;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    reference != null && reference.trim().isNotEmpty
                        ? reference
                        : 'Payment transaction',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusPill(transaction: transaction),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Payment transaction',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            _detailRow(
              context,
              'Amount',
              '${transaction.currency.trim()} '
                  '${_formatAmount(transaction.amount)}',
            ),
            _detailRow(
              context,
              'Method',
              _methodLabel(transaction.paymentMethod),
            ),
            _detailRow(
              context,
              'Status',
              _statusLabel(transaction.paymentStatus),
            ),
            _detailRow(
              context,
              'Date',
              _formatDate(transaction.transactionDate),
            ),
            if (transaction.recordedBy != null)
              _detailRow(
                context,
                'Recorded by',
                _recordedByLabel(transaction.recordedBy!),
              ),
            const Divider(height: 24),
            _detailRow(
                context, 'Transaction ID', transaction.id, mono: true),
            _detailRow(
                context, 'Related order', transaction.orderId, mono: true),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Collection, payouts, refunds, invoicing, wallets and '
                'reconciliation belong to Finance and are not available '
                'from Business Hub.',
                style: TextStyle(fontSize: 11, color: Colors.blueGrey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    BuildContext context,
    String label,
    String value, {
    bool mono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'failed':
        return 'Failed';
      case 'refunded':
        return 'Refunded';
      default:
        return status;
    }
  }

  String _recordedByLabel(String recordedBy) {
    switch (recordedBy) {
      case 'supplier':
        return 'Supplier';
      case 'buyer':
        return 'Buyer';
      case 'system':
        return 'System';
      default:
        return recordedBy;
    }
  }
}
