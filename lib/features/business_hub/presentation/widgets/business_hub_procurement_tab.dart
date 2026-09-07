/// ============================================================
/// BUSINESS HUB — PROCUREMENT TAB
/// ============================================================
///
/// Real (read-only) procurement overview for the ACTIVE business.
///
/// Data source: canonical `commerce.purchase_orders` (no duplicate
/// table/model). Supplier names are enriched from
/// `commerce.business_profiles`.
///
/// Content:
///   - Compact summary (total / open / completed / cancelled)
///   - Compact mobile-first list:
///       Supplier → date/status → value (only when total_amount is set)
///   - Lightweight detail bottom sheet (read-only)
///
/// NOT implemented in this phase: create / approve / receive / cancel /
/// edit / payment / stock movement — each requires its own verified
/// backend contract.
///
/// States: loading / loaded / empty / error. Guests see demo data
/// through the demo repository (session-aware switch).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';

import '../../application/providers/active_business_provider.dart';
import '../../application/providers/procurement_provider.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/models/procurement_summary.dart';

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

String _formatMoney(double value, String currency) {
  final whole = value.round();
  final digits = whole.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final sign = whole < 0 ? '-' : '';
  return '${currency.trim()} $sign$buffer';
}

class BusinessHubProcurementTab extends ConsumerWidget {
  const BusinessHubProcurementTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeBusinessProvider);
    if (active == null) {
      return const EmptyStateWidget(
        icon: Icons.business_outlined,
        title: 'No active business',
        subtitle: 'Select a business to view its procurement.',
      );
    }

    final ordersAsync = ref.watch(activeBusinessPurchaseOrdersProvider);

    return ordersAsync.when(
      loading: () => const LoadingStateWidget(
        message: 'Loading purchase orders...',
      ),
      error: (e, _) => ErrorStateWidget(
        title: 'Failed to Load',
        message: 'Could not load procurement for ${active.name}.',
        retryLabel: 'Retry',
        onRetry: () =>
            ref.invalidate(purchaseOrdersByBusinessProvider(active.id)),
        detailedError: e.toString(),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.shopping_cart_outlined,
            title: 'No purchase orders yet',
            subtitle: 'Purchase orders for this business appear here once '
                'created (commerce.purchase_orders).',
          );
        }
        return _ProcurementLoaded(orders: orders);
      },
    );
  }
}

/// ============================================================
/// LOADED STATE
/// ============================================================
class _ProcurementLoaded extends ConsumerWidget {
  final List<PurchaseOrder> orders;

  const _ProcurementLoaded({required this.orders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ProcurementSummary.from(orders);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Compact summary chips ──
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(
                label: 'Purchase orders',
                value: '${summary.totalCount}',
                color: theme.colorScheme.primary,
              ),
              if (summary.openCount > 0)
                _SummaryChip(
                  label: 'Open',
                  value: '${summary.openCount}',
                  color: Colors.orange,
                ),
              if (summary.completedCount > 0)
                _SummaryChip(
                  label: 'Completed',
                  value: '${summary.completedCount}',
                  color: Colors.green,
                ),
              if (summary.cancelledCount > 0)
                _SummaryChip(
                  label: 'Cancelled',
                  value: '${summary.cancelledCount}',
                  color: Colors.grey,
                ),
            ],
          ),
        ),

        // ── Compact purchase-order list ──
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final order = orders[index];
              return _PurchaseOrderRow(
                order: order,
                onTap: () => _showDetail(context, order),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDetail(BuildContext context, PurchaseOrder order) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _PurchaseOrderDetailSheet(order: order),
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
/// PURCHASE ORDER ROW
/// ============================================================
class _PurchaseOrderRow extends StatelessWidget {
  final PurchaseOrder order;
  final VoidCallback onTap;

  const _PurchaseOrderRow({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  Icons.receipt_long_outlined,
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
                      order.displaySupplier,
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
                      _formatDate(order.createdAt),
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
                    order.hasValue
                        ? _formatMoney(order.totalAmount, order.currency)
                        : '—',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _StatusPill(order: order),
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
  final PurchaseOrder order;

  const _StatusPill({required this.order});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusOf(order);
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

  (String, Color) _statusOf(PurchaseOrder order) {
    if (order.isReceived) return ('Received', Colors.green.shade700);
    if (order.isCancelled) return ('Cancelled', Colors.grey);
    if (order.status == 'sent') return ('Sent', Colors.blue.shade700);
    return ('Pending', Colors.orange.shade800);
  }
}

/// ============================================================
/// DETAIL BOTTOM SHEET (lightweight, read-only)
/// ============================================================
class _PurchaseOrderDetailSheet extends StatelessWidget {
  final PurchaseOrder order;

  const _PurchaseOrderDetailSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    order.displaySupplier,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusPill(order: order),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Purchase order',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            _detailRow(context, 'Value',
                order.hasValue
                    ? _formatMoney(order.totalAmount, order.currency)
                    : 'Not set'),
            _detailRow(context, 'Created', _formatDate(order.createdAt)),
            if (order.notes != null && order.notes!.trim().isNotEmpty)
              _detailRow(context, 'Notes', order.notes!),
            const Divider(height: 24),
            _detailRow(context, 'PO ID', order.id, mono: true),
            if (order.supplierId != null)
              _detailRow(context, 'Supplier ID', order.supplierId!, mono: true),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Approve, receive, cancel, payment and stock movement are '
                'read-only for now and require verified backend contracts.',
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
            width: 110,
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
}
