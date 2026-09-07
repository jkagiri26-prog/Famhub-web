/// ============================================================
/// BUSINESS HUB — OVERVIEW TAB
/// ============================================================
///
/// Operating summary answering one question:
///   "What is happening in this business right now?"
///
/// It COMPOSES the already-implemented Business Hub providers — no
/// duplicate queries, no N+1, no new activity backend.
///
/// Structure:
///   1. Compact operational summary chips (capability-aware counts)
///   2. Recent activity (orders / procurement / listings / payments
///      composed from cached provider data)
///   3. Quick access to the operational tabs (switches the existing
///      TabController — no new routes)
///
/// Capability-aware: a metric/source only renders when the current
/// context has the relevant capability. No `businessType == ...`
/// branching and no fabricated KPIs (no revenue, profit, balances,
/// totals, growth or charts).
///
/// Loading is independent: each operational section renders from its own
/// provider state, so one empty section never blocks the rest, and zero
/// values are never shown while a provider is still loading.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/capabilities/application/capability_profile_provider.dart';
import 'package:famhub_app/core/capabilities/domain/capability.dart';

import 'package:famhub_app/features/business_hub/application/providers/active_business_provider.dart';
import 'package:famhub_app/features/business_hub/application/providers/inventory_provider.dart';
import 'package:famhub_app/features/business_hub/application/providers/listings_provider.dart';
import 'package:famhub_app/features/business_hub/application/providers/payments_provider.dart';
import 'package:famhub_app/features/business_hub/application/providers/procurement_provider.dart';
import 'package:famhub_app/features/business_hub/application/providers/sales_provider.dart';
import 'package:famhub_app/features/business_hub/domain/entities/business_listing.dart';
import 'package:famhub_app/features/business_hub/domain/entities/business_transaction.dart';
import 'package:famhub_app/features/business_hub/domain/entities/inventory_item.dart';
import 'package:famhub_app/features/business_hub/domain/entities/purchase_order.dart';
import 'package:famhub_app/features/business_hub/domain/entities/sales_order.dart';

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _date(DateTime? d) {
  if (d == null) return '';
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

String _num(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

/// Metric / quick-access operation descriptor (capability-gated).
class _OpDescriptor {
  final String label;
  final IconData icon;
  final Capability capability;

  const _OpDescriptor({
    required this.label,
    required this.icon,
    required this.capability,
  });
}

const List<_OpDescriptor> _operations = [
  _OpDescriptor(
    label: 'Inventory',
    icon: Icons.inventory_2_outlined,
    capability: Capabilities.inventoryStock,
  ),
  _OpDescriptor(
    label: 'Procurement',
    icon: Icons.shopping_cart_outlined,
    capability: Capabilities.marketplaceOrders,
  ),
  _OpDescriptor(
    label: 'Sales',
    icon: Icons.trending_up,
    capability: Capabilities.marketplaceOrders,
  ),
  _OpDescriptor(
    label: 'Listings',
    icon: Icons.storefront_outlined,
    capability: Capabilities.marketplaceListings,
  ),
  _OpDescriptor(
    label: 'Payments',
    icon: Icons.payments_outlined,
    capability: Capabilities.financeRecording,
  ),
];

class BusinessHubOverviewTab extends ConsumerWidget {
  /// Invoked to switch to an existing Business Hub tab by its label
  /// (no new routes).
  final void Function(String tabLabel) onOpenTab;

  const BusinessHubOverviewTab({super.key, required this.onOpenTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeBusinessProvider);
    if (active == null) return const SizedBox.shrink();

    final profile = ref.watch(capabilityProfileProvider);
    bool enabled(Capability capability) =>
        profile?.hasCapability(capability.id) ?? false;

    // Single deterministic watches over the shared Business Hub providers
    // (results are cached and reused by the operational tabs — no
    // duplicate backend requests, no N+1).
    final inventory = ref.watch(activeBusinessInventoryProvider);
    final procurement = ref.watch(activeBusinessPurchaseOrdersProvider);
    final sales = ref.watch(activeBusinessSalesOrdersProvider);
    final listings = ref.watch(activeBusinessListingsProvider);
    final transactions = ref.watch(activeBusinessTransactionsProvider);

    final enabledOps =
        _operations.where((op) => enabled(op.capability)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. At-a-glance operational summary ──
        _sectionLabel(context, 'At a glance'),
        const SizedBox(height: 8),
        if (enabledOps.isEmpty)
          _emptyLine('No operations are enabled for this business yet.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (enabled(Capabilities.inventoryStock))
                _metricChip(
                  context,
                  label: 'Inventory records',
                  value: _count(inventory),
                ),
              if (enabled(Capabilities.marketplaceOrders)) ...[
                _metricChip(
                  context,
                  label: 'Open procurement',
                  value: _count(procurement, filter: (o) => o.isOpen),
                ),
                _metricChip(
                  context,
                  label: 'Open sales',
                  value: _count(sales, filter: (o) => o.isOpen),
                ),
              ],
              if (enabled(Capabilities.marketplaceListings))
                _metricChip(
                  context,
                  label: 'Active listings',
                  value: _count(listings, filter: (l) => l.isActive),
                ),
              if (enabled(Capabilities.financeRecording))
                _metricChip(
                  context,
                  label: 'Pending transactions',
                  value: _count(transactions, filter: (t) => t.isPending),
                ),
            ],
          ),
        const SizedBox(height: 18),

        // ── 2. Recent activity ──
        _sectionLabel(context, 'Recent activity'),
        const SizedBox(height: 8),
        _buildRecentActivity(
          context,
          showInventory: enabled(Capabilities.inventoryStock),
          inventory: inventory,
          showProcurement: enabled(Capabilities.marketplaceOrders),
          procurement: procurement,
          sales: sales,
          showListings: enabled(Capabilities.marketplaceListings),
          listings: listings,
          showTransactions: enabled(Capabilities.financeRecording),
          transactions: transactions,
        ),
        const SizedBox(height: 18),

        // ── 3. Quick access to operational tabs ──
        _sectionLabel(context, 'Quick access'),
        const SizedBox(height: 8),
        if (enabledOps.isEmpty)
          _emptyLine('Operations open up here once capabilities are '
              'available for this business.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final op in enabledOps)
                OutlinedButton.icon(
                  onPressed: () => onOpenTab(op.label),
                  icon: Icon(op.icon, size: 16),
                  label: Text(op.label),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // RECENT ACTIVITY (composed from cached providers)
  // ════════════════════════════════════════════════════════════
  Widget _buildRecentActivity(
    BuildContext context, {
    required bool showInventory,
    required AsyncValue<List<InventoryItem>> inventory,
    required bool showProcurement,
    required AsyncValue<List<PurchaseOrder>> procurement,
    required AsyncValue<List<SalesOrder>> sales,
    required bool showListings,
    required AsyncValue<List<BusinessListing>> listings,
    required bool showTransactions,
    required AsyncValue<List<BusinessTransaction>> transactions,
  }) {
    final entries = <_ActivityEntry>[];

    if (showInventory) {
      for (final item in _take(inventory)) {
        entries.add(_ActivityEntry(
          type: 'Inventory',
          icon: Icons.inventory_2_outlined,
          title: item.displayLabel,
          subtitle: item.isOutOfStock
              ? 'Out of stock'
              : '${_num(item.quantity)} ${item.displayUnit}',
        ));
      }
    }

    if (showProcurement) {
      for (final po in _take(procurement)) {
        entries.add(_ActivityEntry(
          type: 'Procurement',
          icon: Icons.shopping_cart_outlined,
          title: po.displaySupplier,
          subtitle: '${_statusLabel(po.status)} · ${_date(po.createdAt)}',
          date: po.createdAt,
        ));
      }
      for (final order in _take(sales)) {
        entries.add(_ActivityEntry(
          type: 'Sales',
          icon: Icons.trending_up,
          title: order.displayBuyer,
          subtitle:
              '${_statusLabel(order.status)} · ${_date(order.orderDate)}',
          date: order.orderDate,
        ));
      }
    }

    if (showListings) {
      for (final listing in _take(listings)) {
        entries.add(_ActivityEntry(
          type: 'Listing',
          icon: Icons.storefront_outlined,
          title: listing.displayItem,
          subtitle: _statusLabel(listing.status.name),
          date: listing.createdAt,
        ));
      }
    }

    if (showTransactions) {
      for (final txn in _take(transactions)) {
        final reference = txn.transactionRef;
        entries.add(_ActivityEntry(
          type: 'Payment',
          icon: Icons.payments_outlined,
          title: reference != null && reference.trim().isNotEmpty
              ? reference
              : 'Payment',
          subtitle: '${_statusLabel(txn.paymentStatus)} · '
              '${txn.currency} ${_num(txn.amount)}',
          date: txn.transactionDate,
        ));
      }
    }

    // Newest first across sources.
    entries.sort((a, b) {
      final da = a.date;
      final db = b.date;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    final recent = entries.take(6).toList();
    if (recent.isEmpty) {
      return _emptyCard(
        'No recent activity yet',
        'New orders, procurement, listings and payments will appear here.',
      );
    }

    return Column(
      children: [for (final entry in recent) _ActivityRow(entry: entry)],
    );
  }

  // ════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ════════════════════════════════════════════════════════════
  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade500,
            letterSpacing: 0.6,
          ),
    );
  }

  Widget _metricChip(
    BuildContext context, {
    required String label,
    required String? value,
  }) {
    final theme = Theme.of(context);
    final loading = value == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            loading ? '···' : value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
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

  Widget _emptyLine(String message) {
    return Text(
      message,
      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
    );
  }

  Widget _emptyCard(String title, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'paused':
        return 'Paused';
      case 'draft':
        return 'Draft';
      case 'sold_out':
        return 'Sold out';
      case 'pending':
        return 'Pending';
      case 'sent':
        return 'Sent';
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
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'refunded':
        return 'Refunded';
      default:
        return status.isEmpty ? '—' : status;
    }
  }
}

/// No misleading zero while a provider is loading/errored: returns null
/// until the list is actually available.
String? _count<T>(AsyncValue<List<T>> async, {bool Function(T)? filter}) {
  final list = async.value;
  if (list == null) return null;
  final result =
      filter == null ? list.length : list.where(filter).length;
  return '$result';
}

/// Take the most recent items from a loaded provider (no-op while
/// loading/errored).
List<T> _take<T>(AsyncValue<List<T>> async, [int limit = 3]) {
  final list = async.value;
  if (list == null) return const [];
  return list.take(limit).toList();
}

/// One recent-activity entry composed from cached provider data.
class _ActivityEntry {
  final String type;
  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime? date;

  const _ActivityEntry({
    required this.type,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.date,
  });
}

/// One compact activity row.
class _ActivityRow extends StatelessWidget {
  final _ActivityEntry entry;

  const _ActivityRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(entry.icon, size: 16, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  entry.subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
