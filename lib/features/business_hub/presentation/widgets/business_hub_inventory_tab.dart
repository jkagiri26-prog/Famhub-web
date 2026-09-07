/// ============================================================
/// BUSINESS HUB — INVENTORY TAB
/// ============================================================
///
/// Real (read-only) inventory overview for the ACTIVE business.
///
/// Data source: canonical `commerce.stock_registry` (no duplicate
/// inventory table/model). Display names resolved from `core.items` /
/// `core.item_variants`; unit/location from `core.units` /
/// `core.locations` via batched scalar lookups.
///
/// Content:
///   - Compact summary (records / variants / out-of-stock)
///   - Compact mobile-first stock list:
///       Item/Variant → quantity + unit → location → status
///   - Lightweight detail bottom sheet (no operations yet)
///
/// NOT implemented in this phase: receiving, adjustments, transfers,
/// sale deductions, reservations, stock creation.
///
/// States: loading / loaded / empty / error. Guests see demo inventory
/// through the demo repository (session-aware switch).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';

import '../../application/providers/active_business_provider.dart';
import '../../application/providers/inventory_provider.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/models/inventory_summary.dart';

/// Compact quantity formatter: integers render without decimals.
String _formatQuantity(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

class BusinessHubInventoryTab extends ConsumerWidget {
  const BusinessHubInventoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeBusinessProvider);
    if (active == null) {
      return const EmptyStateWidget(
        icon: Icons.business_outlined,
        title: 'No active business',
        subtitle: 'Select a business to view its inventory.',
      );
    }

    final inventoryAsync = ref.watch(activeBusinessInventoryProvider);

    return inventoryAsync.when(
      loading: () => const LoadingStateWidget(
        message: 'Loading inventory...',
      ),
      error: (e, _) => ErrorStateWidget(
        title: 'Failed to Load',
        message: 'Could not load inventory for ${active.name}.',
        retryLabel: 'Retry',
        onRetry: () =>
            ref.invalidate(inventoryByBusinessProvider(active.id)),
        detailedError: e.toString(),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.inventory_2_outlined,
            title: 'No inventory yet',
            subtitle: 'Stock for this business appears here once it is '
                'created or linked (commerce.stock_registry).',
          );
        }
        return _InventoryLoaded(items: items);
      },
    );
  }
}

/// ============================================================
/// LOADED STATE
/// ============================================================
class _InventoryLoaded extends ConsumerWidget {
  final List<InventoryItem> items;

  const _InventoryLoaded({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = InventorySummary.from(items);
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
                label: 'Records',
                value: '${summary.recordCount}',
                color: theme.colorScheme.primary,
              ),
              _SummaryChip(
                label: 'Variants',
                value: '${summary.variantCount}',
                color: Colors.teal,
              ),
              if (summary.outOfStockCount > 0)
                _SummaryChip(
                  label: 'Out of stock',
                  value: '${summary.outOfStockCount}',
                  color: Colors.red,
                ),
              if (summary.archivedCount > 0)
                _SummaryChip(
                  label: 'Archived',
                  value: '${summary.archivedCount}',
                  color: Colors.grey,
                ),
            ],
          ),
        ),

        // ── Compact stock list ──
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return _InventoryRow(
                item: item,
                onTap: () => _showDetail(context, item),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDetail(BuildContext context, InventoryItem item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _InventoryDetailSheet(item: item),
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
/// STOCK ROW
/// ============================================================
class _InventoryRow extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onTap;

  const _InventoryRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quantityText = item.displayUnit.isEmpty
        ? _formatQuantity(item.quantity)
        : '${_formatQuantity(item.quantity)} ${item.displayUnit}';

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
                  item.isArchived
                      ? Icons.archive_outlined
                      : Icons.category_outlined,
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
                      item.displayLabel,
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
                      'Location: ${item.displayLocation}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    quantityText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _StatusPill(item: item),
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
  final InventoryItem item;

  const _StatusPill({required this.item});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusOf(item);
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

  (String, Color) _statusOf(InventoryItem item) {
    if (item.isArchived) return ('Archived', Colors.grey);
    if (item.isDepleted || item.isOutOfStock) {
      return ('Out of stock', Colors.red.shade600);
    }
    return ('Active', Colors.green.shade700);
  }
}

/// ============================================================
/// DETAIL BOTTOM SHEET (lightweight, read-only)
/// ============================================================
class _InventoryDetailSheet extends StatelessWidget {
  final InventoryItem item;

  const _InventoryDetailSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (statusLabel, statusColor) = _statusOf(item);

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
                    item.displayLabel,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusPill(item: item),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Stock reference',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            _detailRow(context, 'On-hand',
                '${_formatQuantity(item.quantity)} ${item.displayUnit}'),
            _detailRow(context, 'Reserved', _formatQuantity(item.reservedQuantity)),
            _detailRow(context, 'Available', _formatQuantity(item.availableQuantity)),
            _detailRow(context, 'Status', statusLabel, valueColor: statusColor),
            _detailRow(context, 'Location', item.displayLocation),
            if (item.unitId != null)
              _detailRow(context, 'Unit', item.displayUnit),
            const Divider(height: 24),
            _detailRow(context, 'Stock ID', item.id, mono: true),
            if (item.variantId != null)
              _detailRow(context, 'Variant ID', item.variantId!, mono: true),
            if (item.productId != null)
              _detailRow(context, 'Item ID', item.productId!, mono: true),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Receiving, adjustments, transfers and reservations will '
                'be added in a later phase.',
                style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color) _statusOf(InventoryItem item) {
    if (item.isArchived) return ('Archived', Colors.grey);
    if (item.isDepleted || item.isOutOfStock) {
      return ('Out of stock', Colors.red.shade600);
    }
    return ('Active', Colors.green.shade700);
  }

  Widget _detailRow(
    BuildContext context,
    String label,
    String value, {
    bool mono = false,
    Color? valueColor,
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
                color: valueColor ?? Colors.black87,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
