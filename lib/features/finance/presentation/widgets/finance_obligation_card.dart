/// ============================================================
/// FINANCE — OBLIGATION CARD
/// ============================================================
///
/// Read-only presentation for one `FinanceObligationBalance`.
/// ============================================================
library;

import 'package:flutter/material.dart';

import 'package:famhub_app/features/finance/domain/models/finance_obligation_balance.dart';
import 'package:famhub_app/features/finance/presentation/widgets/finance_party_direction.dart';

class FinanceObligationCard extends StatelessWidget {
  final FinanceObligationBalance obligation;
  final String? activeEntityId;
  final VoidCallback? onTap;

  const FinanceObligationCard({
    super.key,
    required this.obligation,
    this.activeEntityId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final direction = resolveFinancePartyDirection(
      activeEntityId: activeEntityId,
      payerEntityId: obligation.payerEntityId,
      payeeEntityId: obligation.payeeEntityId,
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _typeLabel(obligation.obligationType),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _StatusChip(status: obligation.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _AmountBlock(
                      label: 'Outstanding',
                      value: obligation.outstandingBalance,
                      currency: obligation.currency,
                    ),
                  ),
                  _AmountBlock(
                    label: 'Total',
                    value: obligation.obligationAmount,
                    currency: obligation.currency,
                    alignEnd: true,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  _Meta(
                    icon: Icons.swap_horiz,
                    text: financePartyDirectionLabel(direction),
                  ),
                  _Meta(
                    icon: Icons.event_outlined,
                    text: obligation.dueAt == null
                        ? 'No due date'
                        : 'Due ${_formatDate(obligation.dueAt!)}',
                  ),
                  if (obligation.settlementCount > 0)
                    _Meta(
                      icon: Icons.receipt_long_outlined,
                      text:
                          '${obligation.settlementCount} settlement${obligation.settlementCount == 1 ? '' : 's'}',
                    ),
                ],
              ),
              if (onTap != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'View settlement history',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _typeLabel(FinanceObligationType type) {
    return switch (type) {
      FinanceObligationType.order => 'Order obligation',
      FinanceObligationType.subscription => 'Subscription',
      FinanceObligationType.fee => 'Fee',
      FinanceObligationType.payout => 'Payout',
      FinanceObligationType.refund => 'Refund',
      FinanceObligationType.other => 'Other obligation',
    };
  }
}

class _AmountBlock extends StatelessWidget {
  final String label;
  final double value;
  final String currency;
  final bool alignEnd;

  const _AmountBlock({
    required this.label,
    required this.value,
    required this.currency,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$currency ${value.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final FinanceObligationStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      FinanceObligationStatus.draft => Colors.grey,
      FinanceObligationStatus.open => const Color(0xFF2E7D32),
      FinanceObligationStatus.partiallySettled => const Color(0xFFEF6C00),
      FinanceObligationStatus.settled => const Color(0xFF1565C0),
      FinanceObligationStatus.cancelled => Colors.red.shade700,
      FinanceObligationStatus.voided => Colors.red.shade700,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  static String _statusLabel(FinanceObligationStatus status) {
    return switch (status) {
      FinanceObligationStatus.draft => 'Draft',
      FinanceObligationStatus.open => 'Open',
      FinanceObligationStatus.partiallySettled => 'Partially settled',
      FinanceObligationStatus.settled => 'Settled',
      FinanceObligationStatus.cancelled => 'Cancelled',
      FinanceObligationStatus.voided => 'Void',
    };
  }
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
