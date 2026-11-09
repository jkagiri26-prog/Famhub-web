/// ============================================================
/// FINANCE — VERIFIED PAYMENT CARD
/// ============================================================
///
/// Read-only presentation for one `FinancePayment` from
/// `finance.v_verified_payment_collections`.
/// ============================================================
library;

import 'package:flutter/material.dart';

import 'package:famhub_app/features/finance/domain/models/finance_payment.dart';
import 'package:famhub_app/features/finance/presentation/widgets/finance_party_direction.dart';

class FinancePaymentCard extends StatelessWidget {
  final FinancePayment payment;
  final String? activeEntityId;

  const FinancePaymentCard({
    super.key,
    required this.payment,
    this.activeEntityId,
  });

  @override
  Widget build(BuildContext context) {
    final direction = resolveFinancePartyDirection(
      activeEntityId: activeEntityId,
      payerEntityId: payment.payerEntityId,
      payeeEntityId: payment.payeeEntityId,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  _providerLabel(payment.provider),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Verified',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${payment.currency} ${payment.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _Meta(
                icon: Icons.swap_horiz,
                text: financePartyDirectionLabel(direction),
              ),
              if (payment.providerReference != null)
                _Meta(icon: Icons.tag, text: payment.providerReference!),
              _Meta(
                icon: Icons.verified_outlined,
                text: payment.verifiedAt == null
                    ? 'Verification pending'
                    : 'Verified ${_formatDate(payment.verifiedAt!)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _providerLabel(String provider) {
    return switch (provider.toLowerCase()) {
      'mpesa' => 'M-Pesa',
      'bank' => 'Bank',
      'card' => 'Card',
      'wallet' => 'Wallet',
      _ => provider,
    };
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

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
