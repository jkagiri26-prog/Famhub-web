// ignore: dangling_library_doc_comments
/// ============================================================
/// INVENTORY VALUATION CARD — LIVE PROVIDER WIDGET
/// ============================================================
///
/// ✅ CONSUMES:
///   - farmDashboardProvider (existing async provider)
///
/// ✅ RESPONSIBILITIES:
///   - Display inventory/stock valuation
///   - Show loading/error states
///   - React to provider invalidation
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/application/providers/farm_dashboard_provider.dart';
import 'package:famhub_app/shared/widgets/cards/kpi_card.dart';

class InventoryValuationCard extends ConsumerWidget {
  const InventoryValuationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(farmDashboardProvider);

    return dashboardAsync.when(
      loading: () => _buildSkeleton(),
      error: (e, _) => _buildError(context, e.toString()),
      data: (data) {
        final stockValue = data.summary.stockValue;
        return KPICard(
          label: 'Inventory Value',
          value: stockValue.toStringAsFixed(2),
          icon: Icons.inventory_2_rounded,
          iconColor: Colors.amber.shade700,
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
