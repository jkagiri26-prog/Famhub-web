/// ============================================================
/// FINANCE — PAYMENT ATTEMPT STATUS PANEL
/// ============================================================
///
/// Read-only attempt lookup through
/// `finance.get_payment_attempt_status(p_payment_attempt_id)`.
///
/// Only the safe deployed fields are shown. Raw failure codes/messages,
/// provider references, payloads and internal metadata are never read.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/finance/application/providers/finance_read_providers.dart';
import 'package:famhub_app/features/finance/domain/models/finance_payment_attempt.dart';
import 'package:famhub_app/features/finance/domain/repositories/finance_repository.dart';
import 'package:famhub_app/shared/widgets/states/states.dart';

class FinanceAttemptStatusPanel extends ConsumerStatefulWidget {
  const FinanceAttemptStatusPanel({super.key});

  @override
  ConsumerState<FinanceAttemptStatusPanel> createState() =>
      _FinanceAttemptStatusPanelState();
}

class _FinanceAttemptStatusPanelState
    extends ConsumerState<FinanceAttemptStatusPanel>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _attemptIdController = TextEditingController();
  String _attemptId = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _attemptIdController.dispose();
    super.dispose();
  }

  void _checkStatus() {
    final value = _attemptIdController.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a payment attempt ID.')),
      );
      return;
    }
    setState(() => _attemptId = value);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const Text(
          'Payment attempt status',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter the attempt ID returned when a payment was requested. '
          'Only the safe status fields are displayed.',
          style: TextStyle(
            fontSize: 11.5,
            height: 1.35,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _attemptIdController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _checkStatus(),
          decoration: InputDecoration(
            hintText: 'Payment attempt ID',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF2E7D32),
                width: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _checkStatus,
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Check status'),
          ),
        ),
        const SizedBox(height: 16),
        if (_attemptId.isEmpty)
          const EmptyStateWidget(
            icon: Icons.manage_search_outlined,
            title: 'No attempt selected',
            subtitle: 'Enter an attempt ID to view its safe payment status.',
          )
        else
          _AttemptStatusView(attemptId: _attemptId),
      ],
    );
  }
}

class _AttemptStatusView extends ConsumerWidget {
  final String attemptId;

  const _AttemptStatusView({required this.attemptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(financePaymentAttemptStatusProvider(attemptId));

    return status.when(
      loading: () => const LoadingStateWidget(
        message: 'Loading payment attempt status...',
      ),
      error: (error, _) => ErrorStateWidget(
        title: 'Could not load attempt status',
        message: error is FinanceUnavailableException
            ? 'Finance is not available in this environment yet.'
            : 'Payment attempt status is not available right now.',
        retryLabel: 'Retry',
        onRetry: () =>
            ref.invalidate(financePaymentAttemptStatusProvider(attemptId)),
      ),
      data: (attempt) {
        if (attempt == null) {
          return const EmptyStateWidget(
            icon: Icons.search_off_outlined,
            title: 'Attempt not found',
            subtitle:
                'No accessible payment attempt matches that ID. It may not '
                'belong to your active entity.',
          );
        }
        return _AttemptStatusCard(attempt: attempt);
      },
    );
  }
}

class _AttemptStatusCard extends StatelessWidget {
  final FinancePaymentAttempt attempt;

  const _AttemptStatusCard({required this.attempt});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(attempt.status);

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
                  '${attempt.currency} ${attempt.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(attempt.status),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Meta(
            icon: Icons.add_circle_outline,
            label: 'Created',
            value: _formatDateTime(attempt.createdAt),
          ),
          _Meta(
            icon: Icons.update,
            label: 'Updated',
            value: _formatDateTime(attempt.updatedAt),
          ),
          if (attempt.completedAt != null)
            _Meta(
              icon: Icons.check_circle_outline,
              label: 'Completed',
              value: _formatDateTime(attempt.completedAt!),
            ),
          if (attempt.hasFailed)
            const _Meta(
              icon: Icons.error_outline,
              label: 'Outcome',
              value: 'Attempt failed',
            ),
        ],
      ),
    );
  }

  static Color _statusColor(FinancePaymentAttemptStatus status) {
    return switch (status) {
      FinancePaymentAttemptStatus.created => Colors.grey,
      FinancePaymentAttemptStatus.pending => const Color(0xFFEF6C00),
      FinancePaymentAttemptStatus.processing => const Color(0xFF1565C0),
      FinancePaymentAttemptStatus.succeeded => const Color(0xFF2E7D32),
      FinancePaymentAttemptStatus.failed => Colors.red.shade700,
      FinancePaymentAttemptStatus.cancelled => Colors.red.shade700,
      FinancePaymentAttemptStatus.expired => Colors.grey.shade700,
    };
  }

  static String _statusLabel(FinancePaymentAttemptStatus status) {
    return switch (status) {
      FinancePaymentAttemptStatus.created => 'Created',
      FinancePaymentAttemptStatus.pending => 'Pending',
      FinancePaymentAttemptStatus.processing => 'Processing',
      FinancePaymentAttemptStatus.succeeded => 'Succeeded',
      FinancePaymentAttemptStatus.failed => 'Failed',
      FinancePaymentAttemptStatus.cancelled => 'Cancelled',
      FinancePaymentAttemptStatus.expired => 'Expired',
    };
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Meta({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11.5))),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day}/${local.month}/${local.year} $hour:$minute';
}
