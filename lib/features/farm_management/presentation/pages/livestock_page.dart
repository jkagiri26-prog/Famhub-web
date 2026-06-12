import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/feature_page_scaffold.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/inputs/filter_row.dart';
import 'package:famhub_app/shared/widgets/cards/kpi_card.dart';
import 'package:famhub_app/shared/layouts/adaptive_content_grid.dart';

import 'package:famhub_app/features/farm_management/application/providers/livestock_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';

class LivestockPage extends ConsumerStatefulWidget {
  const LivestockPage({super.key});

  @override
  ConsumerState<LivestockPage> createState() => _LivestockPageState();
}

class _LivestockPageState extends ConsumerState<LivestockPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadLivestock());
  }

  Future<void> _loadLivestock() async {
    final farmId = ref.read(farmContextProvider).farmId;
    if (farmId != null) {
      ref.read(livestockProvider(farmId).notifier).loadLivestock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(farmContextProvider).farmId;

    if (farmId == null) {
      return const FeaturePageScaffold(
        title: 'Livestock',
        subtitle: 'Select a farm to view livestock',
        children: [],
      );
    }

    final livestockState = ref.watch(livestockProvider(farmId));

    if (livestockState.isLoading) {
      return const FeaturePageScaffold(
        title: 'Livestock',
        subtitle: 'Loading livestock inventory...',
        children: [LoadingStateWidget(useSkeleton: true)],
      );
    }

    if (livestockState.errorMessage != null) {
      return FeaturePageScaffold(
        title: 'Livestock',
        subtitle: 'Failed to load livestock data',
        children: [
          ErrorStateWidget(
            title: 'Error Loading Livestock',
            message: livestockState.errorMessage!,
            retryLabel: 'Retry',
            onRetry: _loadLivestock,
          ),
        ],
      );
    }

    final filtered = livestockState.filteredLivestock;
    final speciesList = livestockState.species;

    return FeaturePageScaffold(
      title: 'Livestock',
      subtitle: '${livestockState.totalCount} animals total',
      children: [
        // ── KPIs ──
        AdaptiveContentGrid(
          items: [
            KPICard(
              label: 'Total Animals',
              value: '${livestockState.totalCount}',
              icon: Icons.pets,
              iconColor: Colors.brown,
            ),
            KPICard(
              label: 'Species',
              value: '${speciesList.length}',
              icon: Icons.category,
              iconColor: Colors.teal,
            ),
            KPICard(
              label: 'Groups',
              value: '${livestockState.livestock.length}',
              icon: Icons.groups,
              iconColor: Colors.indigo,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Species Filter ──
        if (speciesList.length > 1)
          FilterRow(
            filters: speciesList
                .map((s) => FilterChipItem(value: s, label: s))
                .toList(),
            selectedValue: livestockState.speciesFilter,
            onChanged: (species) {
              ref
                  .read(livestockProvider(farmId).notifier)
                  .setSpeciesFilter(species.isEmpty ? null : species);
            },
          ),
        const SizedBox(height: 8),

        // ── Livestock List ──
        if (filtered.isEmpty)
          const Expanded(
            child: EmptyStateWidget(
              icon: Icons.pets,
              title: 'No Livestock',
              subtitle: 'Add your first livestock record.',
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final animal = filtered[index];
                return _LivestockCard(animal: animal);
              },
            ),
          ),
      ],
    );
  }
}

class _LivestockCard extends StatelessWidget {
  final LivestockModel animal;

  const _LivestockCard({required this.animal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final healthColor = _healthColor(animal.healthStatus);

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
                    color: Colors.brown.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.pets, size: 20, color: Colors.brown),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        animal.species,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (animal.breed != null)
                        Text(
                          animal.breed!,
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
                    color: healthColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    animal.healthLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: healthColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.numbers,
                  label: 'Count: ${animal.count}',
                ),
                const SizedBox(width: 12),
                if (animal.purpose != null)
                  _InfoChip(
                    icon: Icons.flag,
                    label: animal.purpose!,
                  ),
                if (animal.ageInMonths != null) ...[
                  const SizedBox(width: 12),
                  _InfoChip(
                    icon: Icons.schedule,
                    label: '${animal.ageInMonths}mo',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _healthColor(String? health) {
    switch (health?.toLowerCase()) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.blue;
      case 'fair':
        return Colors.orange;
      case 'poor':
        return Colors.red;
      default:
        return Colors.grey;
    }
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

