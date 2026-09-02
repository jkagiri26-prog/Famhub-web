import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/cards/kpi_card.dart';
import 'package:famhub_app/shared/layouts/adaptive_content_grid.dart';

import 'package:famhub_app/features/farm_management/application/providers/livestock_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/add_livestock_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/activity_template_selection_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/crop_livestock_detail_page.dart';
import 'package:famhub_app/features/marketplace/presentation/pages/stock_selection_page.dart';

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
    final hierarchy = ref.watch(hierarchyProvider);

        if (farmId == null) {
      return const ShellPageContent(
        title: 'Livestock',
        subtitle: 'Select a farm to view livestock',
        child: SizedBox.shrink(),
      );
    }

    // 🚫 BLOCK: Livestock belong to a field — require field selection
    if (!hierarchy.hasField) {
      return ShellPageContent(
        title: 'Livestock',
        subtitle: 'Select a field to view and add livestock',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pets, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('Select a Field/Block first',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(
                  'Navigate to the Fields/Blocks tab and tap a field to select it. '
                  'Then you can add livestock to that field.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final livestockState = ref.watch(livestockProvider);

    if (livestockState.isLoading) {
      return const ShellPageContent(
        title: 'Livestock',
        subtitle: 'Loading livestock records...',
        child: LoadingStateWidget(useSkeleton: true),
      );
    }

    if (livestockState.errorMessage != null) {
      return ShellPageContent(
        title: 'Livestock',
        subtitle: 'Failed to load livestock data',
        child: ErrorStateWidget(
          title: 'Error Loading Livestock',
          message: livestockState.errorMessage!,
          retryLabel: 'Retry',
          onRetry: _loadLivestock,
        ),
      );
    }

    final livestock = livestockState.livestock;
    final totalAnimals =
        livestock.fold<int>(0, (sum, l) => sum + (l.count ?? 0));
    final speciesCount = livestock.map((l) => l.species).toSet().length;

        return ShellPageContent(
      title: 'Livestock',
      subtitle: hierarchy.hasField
          ? '${hierarchy.field!.fieldName} — ${livestock.length} types'
          : '${livestock.length} animal type${livestock.length == 1 ? '' : 's'}',
      actions: [
        // ✅ CONTEXT: Add Livestock visible ONLY when a Field/Block is selected
        if (hierarchy.hasField)
          IconButton(
            onPressed: () => _navigateToAddLivestock(context),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Livestock to ${hierarchy.field!.fieldName}',
          ),
        // Phase 1: publish managed stock to Marketplace
        IconButton(
          onPressed: () => _navigateToSellOnMarketplace(context),
          icon: const Icon(Icons.storefront_outlined),
          tooltip: 'Sell on Marketplace',
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                return _LivestockCard(
                  animal: animal,
                  onTap: () => _openLivestockDetails(context, animal),
                  onSell: () => _sellLivestock(context, animal),
                  onRecordActivity: () => _recordActivity(context, animal),
                );
              },
            ),
                    ),
      ],
    ),
    );
    }

  void _navigateToAddLivestock(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddLivestockPage()),
    );
  }

  void _navigateToSellOnMarketplace(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StockSelectionPage()),
    );
  }

  void _sellLivestock(BuildContext context, LivestockEntity animal) {
    // Opens the eligible-stock picker pre-filtered to this animal's species.
    // After production, the matching commerce.stock_registry row appears here.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockSelectionPage(initialSearchQuery: animal.species),
      ),
    );
  }

  void _recordActivity(BuildContext context, LivestockEntity animal) {
    // Activities belong to a livestock record within the hierarchy
    // (farm → field → livestock).
    ref.read(hierarchyProvider.notifier).selectLivestock(animal);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ActivityTemplateSelectionPage(),
      ),
    );
  }

  void _openLivestockDetails(BuildContext context, LivestockEntity animal) {
    ref.read(hierarchyProvider.notifier).selectLivestock(animal);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CropLivestockDetailPage.livestock(livestock: animal),
      ),
    );
  }
}

class _LivestockCard extends StatelessWidget {
  final LivestockEntity animal;
  final VoidCallback onTap;
  final VoidCallback onSell;
  final VoidCallback onRecordActivity;

  const _LivestockCard({
    required this.animal,
    required this.onTap,
    required this.onSell,
    required this.onRecordActivity,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRecordActivity,
                    icon: const Icon(Icons.event_note, size: 16),
                    label: const Text('Activity'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onSell,
                    icon: const Icon(Icons.storefront_outlined, size: 16),
                    label: const Text('Sell on Marketplace'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
