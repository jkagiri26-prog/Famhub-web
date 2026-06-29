import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/feature_page_scaffold.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/cards/kpi_card.dart';
import 'package:famhub_app/shared/layouts/adaptive_content_grid.dart';

import 'package:famhub_app/features/farm_management/application/providers/livestock_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';

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
      ref.read(livestockProvider.notifier).loadLivestock(farmId: farmId);
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

    final livestockState = ref.watch(livestockProvider);

    if (livestockState.isLoading) {
      return const FeaturePageScaffold(
        title: 'Livestock',
        subtitle: 'Loading livestock records...',
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

    final livestock = livestockState.livestock;
    final totalAnimals =
        livestock.fold<int>(0, (sum, l) => sum + (l.count ?? 0));
    final speciesCount = livestock.map((l) => l.species).toSet().length;

    return FeaturePageScaffold(
      title: 'Livestock',
      subtitle: '${livestock.length} animal type${livestock.length == 1 ? '' : 's'}',
      children: [
        // ── KPIs ──
        AdaptiveContentGrid(
          items: [
            KPICard(
              label: 'Total Animals',
              value: '$totalAnimals',
              icon: Icons.pets,
              iconColor: Colors.orange,
            ),
            KPICard(
              label: 'Species',
              value: '$speciesCount',
              icon: Icons.category,
              iconColor: Colors.brown,
            ),
            KPICard(
              label: 'Animal Types',
              value: '${livestock.length}',
              icon: Icons.list,
              iconColor: Colors.teal,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Livestock List ──
        if (livestock.isEmpty)
          const Expanded(
            child: EmptyStateWidget(
              icon: Icons.pets,
              title: 'No Livestock Recorded',
              subtitle: 'Add livestock to start tracking.',
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: livestock.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final animal = livestock[index];
                return _LivestockCard(animal: animal);
              },
            ),
          ),
      ],
    );
  }
}

class _LivestockCard extends StatelessWidget {
  final LivestockEntity animal;

  const _LivestockCard({required this.animal});

  @override
  Widget build(BuildContext context) {
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
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.pets, size: 20, color: Colors.orange),
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
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${animal.count ?? 0} head',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            if (animal.notes != null && animal.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                animal.notes!,
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
}
