import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/feature_page_scaffold.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/inputs/filter_row.dart';
import 'package:famhub_app/shared/widgets/cards/kpi_card.dart';
import 'package:famhub_app/shared/layouts/adaptive_content_grid.dart';

import 'package:famhub_app/features/farm_management/application/providers/assets_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/domain/models/asset_model.dart';

class AssetsPage extends ConsumerStatefulWidget {
  const AssetsPage({super.key});

  @override
  ConsumerState<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends ConsumerState<AssetsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadAssets());
  }

  Future<void> _loadAssets() async {
    final farmId = ref.read(farmContextProvider).farmId;
    if (farmId != null) {
      ref.read(assetsProvider.notifier).loadAssets(farmId: farmId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(farmContextProvider).farmId;

    if (farmId == null) {
      return const FeaturePageScaffold(
        title: 'Assets',
        subtitle: 'Select a farm to view assets',
        children: [],
      );
    }

    final assetState = ref.watch(assetsProvider);

    if (assetState.isLoading) {
      return const FeaturePageScaffold(
        title: 'Assets',
        subtitle: 'Loading asset registry...',
        children: [LoadingStateWidget(useSkeleton: true)],
      );
    }

    if (assetState.errorMessage != null) {
      return FeaturePageScaffold(
        title: 'Assets',
        subtitle: 'Failed to load asset data',
        children: [
          ErrorStateWidget(
            title: 'Error Loading Assets',
            message: assetState.errorMessage!,
            retryLabel: 'Retry',
            onRetry: _loadAssets,
          ),
        ],
      );
    }

    final filtered = assetState.filteredAssets;
    final assetTypes = assetState.assetTypes;
    final needsMaintenance = assetState.needsMaintenance.length;

    return FeaturePageScaffold(
      title: 'Assets',
      subtitle: '${assetState.assets.length} asset${assetState.assets.length == 1 ? '' : 's'}',
      children: [
        // ── KPIs ──
        AdaptiveContentGrid(
          items: [
            KPICard(
              label: 'Total Assets',
              value: '${assetState.assets.length}',
              icon: Icons.precision_manufacturing,
              iconColor: Colors.blue,
            ),
            KPICard(
              label: 'Categories',
              value: '${assetTypes.length}',
              icon: Icons.category,
              iconColor: Colors.teal,
            ),
            KPICard(
              label: 'Needs Maintenance',
              value: '$needsMaintenance',
              icon: Icons.build,
              iconColor: needsMaintenance > 0 ? Colors.red : Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Type Filter ──
        if (assetTypes.length > 1)
          FilterRow(
            filters: assetTypes
                .map((t) => FilterChipItem(value: t, label: _typeLabel(t)))
                .toList(),
            selectedValue: assetState.typeFilter,
            onChanged: (type) {
                            ref
                  .read(assetsProvider.notifier)
                  .setTypeFilter(type.isEmpty ? null : type);
            },
          ),
        const SizedBox(height: 8),

        // ── Asset List ──
        if (filtered.isEmpty)
          const Expanded(
            child: EmptyStateWidget(
              icon: Icons.precision_manufacturing,
              title: 'No Assets Registered',
              subtitle: 'Add machinery, equipment, and other farm assets.',
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final asset = filtered[index];
                return _AssetCard(asset: asset);
              },
            ),
          ),
      ],
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'machinery':
        return 'Machinery';
      case 'equipment':
        return 'Equipment';
      case 'structure':
        return 'Structure';
      case 'vehicle':
        return 'Vehicle';
      default:
        return type;
    }
  }
}

class _AssetCard extends StatelessWidget {
  final AssetModel asset;

  const _AssetCard({required this.asset});

  @override
  Widget build(BuildContext context) {
    final maintColor = asset.daysSinceMaintenance != null &&
            asset.daysSinceMaintenance! >= 90
        ? Colors.red
        : Colors.green;

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
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.precision_manufacturing,
                    size: 20,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.assetName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (asset.manufacturer != null || asset.model != null)
                        Text(
                          [asset.manufacturer, asset.model]
                              .where((s) => s != null)
                              .join(' '),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: maintColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.build,
                        size: 12,
                        color: maintColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        asset.daysSinceMaintenance != null
                            ? '${asset.daysSinceMaintenance}d'
                            : 'N/A',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: maintColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.category,
                  label: asset.typeLabel,
                ),
                const SizedBox(width: 12),
                _InfoChip(
                  icon: Icons.check_circle,
                  label: asset.conditionLabel,
                ),
                if (asset.yearPurchased != null) ...[
                  const SizedBox(width: 12),
                  _InfoChip(
                    icon: Icons.calendar_today,
                    label: '${asset.yearPurchased}',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

