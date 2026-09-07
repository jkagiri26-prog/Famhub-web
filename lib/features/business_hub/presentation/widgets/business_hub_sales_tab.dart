/// ============================================================
/// BUSINESS HUB — SALES TAB
/// ============================================================
///
/// Real (read-only) sales overview for the ACTIVE business.
///
/// Data source: canonical `commerce.orders` (scoped to the business's
/// seller profiles via the verified `supplier_id` FK →
/// `commerce.business_profiles`). Buyers enriched from `users.profiles`.
/// Item lines from `commerce.order_items` (verified `order_id` FK).
///
/// Content:
///   - Compact summary (orders / open / completed / cancelled / returned)
///   - Compact mobile-first list:
///       Buyer → date → amount (no currency — orders has no currency
///       column) → status
///   - Lightweight read-only detail bottom sheet incl. item lines
///
/// NOT implemented in this phase: create / approve / fulfil / cancel /
/// payment / stock deduction / reservation / dispatch.
///
/// States: loading / loaded / empty / error. Guests see demo data via
/// the demo repository (session-aware switch).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';

import '../../application/providers/active_business_provider.dart';
import '../../application/providers/sales_provider.dart';
import '../../domain/entities/sales_order.dart';
import '../../domain/entities/sales_order_line.dart';
import '../../domain/models/sales_summary.dart';

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

class BusinessHubSalesTab extends ConsumerWidget {
  const BusinessHubSalesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeBusinessProvider);
    if (active == null) {
      return const EmptyStateWidget(
        icon: Icons.business_outlined,
        title: 'No active business',
        subtitle: 'Select a business to view its sales.',
      );
    }

    final ordersAsync = ref.watch(activeBusinessSalesOrdersProvider);

    return ordersAsync.when(
      loading: () => const LoadingStateWidget(
        message: 'Loading orders...',
      ),
      error: (e, _) => ErrorStateWidget(
        title: 'Failed to Load',
        message: 'Could not load sales for ${active.name}.',
        retryLabel: 'Retry',
        onRetry: () =>
            ref.invalidate(salesOrdersByBusinessProvider(active.id)),
        detailedError: e.toString(),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.sell_outlined,
            title: 'No sales orders yet',
            subtitle: 'Orders for this business appear here once buyers '
                'place orders (commerce.orders).',
          );
        }
        return _SalesLoaded(orders: orders);
      },
    );
  }
}

/// ============================================================
/// LOADED STATE
/// ============================================================
class _SalesLoaded extends ConsumerWidget {
  final List<SalesOrder> orders;

  const _SalesLoaded({required this.orders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = SalesSummary.from(orders);
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
                label: 'Orders',
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
              if (summary.returnedCount > 0)
                _SummaryChip(
                  label: 'Returned',
                  value: '${summary.returnedCount}',
                  color: Colors.red,
                ),
            ],
          ),
        ),

        // ── Compact order list ──
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final order = orders[index];
              return _SalesOrderRow(
                order: order,
                onTap: () => _showDetail(context, order),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDetail(BuildContext context, SalesOrder order) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _SalesOrderDetailSheet(order: order),
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
/// SALES ORDER ROW
/// ============================================================
class _SalesOrderRow extends StatelessWidget {
  final SalesOrder order;
  final VoidCallback onTap;

  const _SalesOrderRow({required this.order, required this.onTap});

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
                  Icons.shopping_bag_outlined,
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
                      order.displayBuyer,
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
                      _formatDate(order.orderDate),
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
                    _formatAmount(order.totalAmount),
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
  final SalesOrder order;

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

  (String, Color) _statusOf(SalesOrder order) {
    switch (order.status) {
      case 'confirmed':
        return ('Confirmed', Colors.blue.shade700);
      case 'shipped':
        return ('Shipped', Colors.indigo.shade600);
      case 'delivered':
        return ('Delivered', Colors.green.shade700);
      case 'cancelled':
        return ('Cancelled', Colors.grey);
      case 'returned':
        return ('Returned', Colors.red.shade600);
      default:
        return ('Pending', Colors.orange.shade800);
    }
  }
}

/// ============================================================
/// SALES ORDER DETAIL SHEET (read-only)
/// ============================================================
class _SalesOrderDetailSheet extends ConsumerWidget {
  final SalesOrder order;

  const _SalesOrderDetailSheet({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(orderItemsByOrderProvider(order.id));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.displayBuyer,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  _StatusPill(order: order),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Sales order',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              _detailRow(context, 'Amount', _formatAmount(order.totalAmount)),
              _detailRow(context, 'Date', _formatDate(order.orderDate)),
              if (order.deliveryDate != null)
                _detailRow(
                    context, 'Delivery', _formatDate(order.deliveryDate)),
              _detailRow(context, 'Status', _statusLabel(order.status)),
              _detailRow(
                  context, 'Payment', _paymentStatusLabel(order)),
              if (order.paymentMode != null && order.paymentMode != 'direct_supplier')
                _detailRow(context, 'Mode', _paymentModeLabel(order.paymentMode!)),
              const Divider(height: 24),

              // ── Item lines (commerce.order_items) ──
              Text(
                'Items',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              itemsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Could not load items.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
                data: (lines) => lines.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          'No line items recorded.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    : Column(
                        children: [for (final line in lines) _lineRow(line)],
                      ),
              ),
              const Divider(height: 24),
              _detailRow(context, 'Order ID', order.id, mono: true),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Fulfilment, payments, stock deductions, reservations and '
                  'dispatch are read-only for now and require verified '
                  'backend contracts.',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lineRow(SalesOrderLine line) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              line.displayLabel,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                line.displayQuantity,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              if (line.totalAmount > 0)
                Text(
                  _formatAmount(line.totalAmount),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
            ],
          ),
        ],
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

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmed';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      case 'returned':
        return 'Returned';
      default:
        return 'Pending';
    }
  }

  String _paymentStatusLabel(SalesOrder order) {
    switch (order.paymentStatus) {
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'refunded':
        return 'Refunded';
      default:
        return 'Pending';
    }
  }

  String _paymentModeLabel(String mode) {
    switch (mode) {
      case 'platform':
        return 'Platform';
      case 'escrow':
        return 'Escrow';
      default:
        return 'Direct supplier';
    }
  }
}
