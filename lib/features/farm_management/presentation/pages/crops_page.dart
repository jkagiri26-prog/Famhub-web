import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/inputs/search_bar_widget.dart';
import 'package:famhub_app/shared/widgets/cards/kpi_card.dart';
import 'package:famhub_app/shared/layouts/adaptive_content_grid.dart';

import 'package:famhub_app/features/farm_management/application/providers/crops_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/enums/crop_status.dart';


class CropsPage extends ConsumerStatefulWidget {
  const CropsPage({super.key});

  @override
  ConsumerState<CropsPage> createState() => _CropsPageState();
}

class _CropsPageState extends ConsumerState<CropsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadCrops());
  }

  Future<void> _loadCrops() async {
    final farmId = ref.read(farmContextProvider).farmId;
        if (farmId != null) {
      ref.read(cropsProvider.notifier).loadCrops(farmId: farmId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(farmContextProvider).farmId;

                if (farmId == null) {
      return const ShellPageContent(
        title: 'Crops',
        subtitle: 'Select a farm to view crops',
        child: SizedBox.shrink(),
      );
    }

    final cropState = ref.watch(cropsProvider);

    if (cropState.isLoading) {
      return const ShellPageContent(
        title: 'Crops',
        subtitle: 'Loading crop records...',
        child: LoadingStateWidget(useSkeleton: true),
      );
    }

    if (cropState.errorMessage != null) {
      return ShellPageContent(
        title: 'Crops',
        subtitle: 'Failed to load crop data',
        child: ErrorStateWidget(
          title: 'Error Loading Crops',
          message: cropState.errorMessage!,
          retryLabel: 'Retry',
          onRetry: _loadCrops,
        ),
      );
    }

    final filtered = cropState.filteredCrops;

    // ── Summary KPIs ──
    final activeCrops = cropState.crops.where(
      (c) => c.status == CropStatus.planted || c.status == CropStatus.growing,
    ).length;
    final totalArea = cropState.crops.fold<double>(
      0.0, (sum, c) => sum + (c.areaPlanted ?? 0),
    );
    final harvestedCount = cropState.crops.where(
      (c) => c.status == CropStatus.harvested,
    ).length;

    return ShellPageContent(
      title: 'Crops',
      subtitle: '${cropState.crops.length} crop records',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // ── KPI Summary ──
        AdaptiveContentGrid(
          items: [
            KPICard(
              label: 'Active Crops',
              value: '$activeCrops',
              icon: Icons.grass,
              iconColor: Colors.green,
            ),
            KPICard(
              label: 'Total Area',
              value: '${totalArea.toStringAsFixed(1)} ha',
              icon: Icons.straighten,
              iconColor: Colors.blue,
            ),
            KPICard(
              label: 'Harvested',
              value: '$harvestedCount',
              icon: Icons.shopping_basket,
              iconColor: Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Search ──
        SearchBarWidget(
          hintText: 'Search crops...',
          onChanged: (query) {
            ref.read(cropsProvider.notifier).setSearchQuery(query);
          },
        ),
        const SizedBox(height: 12),

        // ── Crop List ──
        if (filtered.isEmpty)
          const Expanded(
            child: EmptyStateWidget(
              icon: Icons.grass,
              title: 'No Crops Found',
              subtitle: 'Plant your first crop to start tracking.',
            ),
          )
        else
                    Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final crop = filtered[index];
                return _CropCard(crop: crop);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CropCard extends StatelessWidget {
  final CropEntity crop;

  const _CropCard({required this.crop});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(crop.status);

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
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.grass, size: 20, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        crop.cropName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (crop.variety != null)
                        Text(
                          crop.variety!,
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
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    crop.statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (crop.areaPlanted != null) ...[
                  _InfoChip(
                    icon: Icons.straighten,
                    label: '${crop.areaPlanted!.toStringAsFixed(1)} ha',
                  ),
                  const SizedBox(width: 12),
                ],
                _InfoChip(
                  icon: Icons.calendar_today,
                  label: '${crop.daysSincePlanting.inDays}d ago',
                ),
                if (crop.expectedHarvestDate != null) ...[
                  const SizedBox(width: 12),
                  _InfoChip(
                    icon: Icons.event,
                    label: 'Harvest: ${_formatDate(crop.expectedHarvestDate!)}',
                  ),
                ],
              ],
            ),
            if (crop.notes != null && crop.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                crop.notes!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(CropStatus status) {
    switch (status) {
      case CropStatus.planted:
        return Colors.blue;
      case CropStatus.growing:
        return Colors.green;
      case CropStatus.harvested:
        return Colors.orange;
      case CropStatus.failed:
        return Colors.red;
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
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