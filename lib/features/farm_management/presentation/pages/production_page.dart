import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/feature_page_scaffold.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/cards/kpi_card.dart';
import 'package:famhub_app/shared/layouts/adaptive_content_grid.dart';

import 'package:famhub_app/features/farm_management/application/providers/production_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';

class ProductionPage extends ConsumerStatefulWidget {
  const ProductionPage({super.key});

  @override
  ConsumerState<ProductionPage> createState() => _ProductionPageState();
}

class _ProductionPageState extends ConsumerState<ProductionPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadProduction());
  }

  Future<void> _loadProduction() async {
    final farmId = ref.read(farmContextProvider).farmId;
    if (farmId != null) {
      ref.read(productionProvider(farmId).notifier).loadProduction();
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(farmContextProvider).farmId;

    if (farmId == null) {
      return const FeaturePageScaffold(
        title: 'Production',
        subtitle: 'Select a farm to view production records',
        children: [],
      );
    }

    final prodState = ref.watch(productionProvider(farmId));

    if (prodState.isLoading) {
      return const FeaturePageScaffold(
        title: 'Production',
        subtitle: 'Loading production records...',
        children: [LoadingStateWidget(useSkeleton: true)],
      );
    }

    if (prodState.errorMessage != null) {
      return FeaturePageScaffold(
        title: 'Production',
        subtitle: 'Failed to load production data',
        children: [
          ErrorStateWidget(
            title: 'Error Loading Production',
            message: prodState.errorMessage!,
            retryLabel: 'Retry',
            onRetry: _loadProduction,
          ),
        ],
      );
    }

    final records = prodState.records;

    return FeaturePageScaffold(
      title: 'Production',
      subtitle: '${records.length} record${records.length == 1 ? '' : 's'}',
      children: [
        // ── KPIs ──
        AdaptiveContentGrid(
          items: [
            KPICard(
              label: 'Total Records',
              value: '${prodState.recordCount}',
              icon: Icons.receipt_long,
              iconColor: Colors.blue,
            ),
            KPICard(
              label: 'Total Quantity',
              value: prodState.totalQuantity.toStringAsFixed(1),
              icon: Icons.inventory_2,
              iconColor: Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Production List ──
        if (records.isEmpty)
          const Expanded(
            child: EmptyStateWidget(
              icon: Icons.trending_up,
              title: 'No Production Records',
              subtitle: 'Record harvests and production to track yields. '
                  'This data will feed into Marketplace inventory.',
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final record = records[index];
                return _ProductionCard(record: record);
              },
            ),
          ),
      ],
    );
  }
}

class _ProductionCard extends StatelessWidget {
  final ProductionModel record;

  const _ProductionCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shopping_basket,
                    size: 20,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Production #${record.id.substring(0, 8)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Quantity: ${record.quantity?.toStringAsFixed(1) ?? "N/A"}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (record.fieldId != null)
                  _DetailChip(
                    icon: Icons.landscape,
                    label: 'Field: ${record.fieldId!.substring(0, 8)}',
                  ),
                if (record.fieldId != null && record.categoryId != null)
                  const SizedBox(width: 8),
                if (record.categoryId != null)
                  _DetailChip(
                    icon: Icons.category,
                    label: 'Cat: ${record.categoryId!.substring(0, 8)}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

