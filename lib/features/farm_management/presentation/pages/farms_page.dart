import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/cards/kpi_card.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/layouts/adaptive_content_grid.dart';

import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_selector_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';

import 'package:famhub_app/features/farm_management/presentation/pages/farm_detail_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/add_farm_page.dart';

class FarmsPage extends ConsumerStatefulWidget {
  const FarmsPage({super.key});

  @override
  ConsumerState<FarmsPage> createState() => _FarmsPageState();
}

class _FarmsPageState extends ConsumerState<FarmsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(farmSelectorProvider.notifier).loadFarms();
    });
  }

  @override
  Widget build(BuildContext context) {
    final farmState = ref.watch(farmSelectorProvider);
    final contextState = ref.watch(farmContextProvider);

        return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // ── Header ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Farms',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage and monitor your agricultural operations',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _navigateToAddFarm(context),
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Add Farm',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Loading State ──
          if (farmState.isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )

          // ── Error State ──
          else if (farmState.errorMessage != null)
            Expanded(
              child: ErrorStateWidget(
                title: 'Failed to Load Farms',
                message: farmState.errorMessage!,
                retryLabel: 'Retry',
                onRetry: () => ref.read(farmSelectorProvider.notifier).loadFarms(),
              ),
            )

          // ── Empty State ──
          else if (farmState.farms.isEmpty)
            const Expanded(
              child: EmptyStateWidget(
                icon: Icons.agriculture,
                title: 'No Farms Registered',
                subtitle: 'Add your first farm to start managing operations, '
                    'track activities, and record production.',
              ),
            )

          // ── Farm List ──
          else
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: farmState.farms.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildOverviewCards(context, farmState.farms);
                  }
                  final farm = farmState.farms[index - 1];
                  return _FarmCard(
                    farm: farm,
                    isSelected: farm.id == contextState.farmId,
                    onTap: () => _navigateToFarmDetail(context, farm),
                    onSelect: () {
                      ref.read(hierarchyProvider.notifier).selectEntity(farm);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards(BuildContext context, List<FarmEntity> farms) {
    final activeFarms = farms.where((f) => f.isActive).length;
    final verifiedFarms = farms.where((f) => f.isVerified).length;
    final totalAcreage = farms.fold<double>(0, (sum, f) => sum + (f.size ?? 0));

    return AdaptiveContentGrid(
      items: [
        KPICard(
          label: 'Total Farms',
          value: '${farms.length}',
          icon: Icons.agriculture,
          iconColor: Colors.green,
        ),
        KPICard(
          label: 'Active',
          value: '$activeFarms',
          icon: Icons.check_circle,
          iconColor: Colors.blue,
        ),
        KPICard(
          label: 'Verified',
          value: '$verifiedFarms',
          icon: Icons.verified,
          iconColor: Colors.teal,
        ),
        KPICard(
          label: 'Total Acreage',
          value: '${totalAcreage.toStringAsFixed(1)} ha',
          icon: Icons.straighten,
          iconColor: Colors.orange,
        ),
      ],
    );
  }

  void _navigateToAddFarm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddFarmPage()),
    );
  }

  void _navigateToFarmDetail(BuildContext context, FarmEntity farm) {
    // Single source of truth: set the selected farm in the hierarchy
    // BEFORE entering Farm Detail (hierarchyProvider.selectEntity).
    ref.read(hierarchyProvider.notifier).selectEntity(farm);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FarmDetailPage(farmId: farm.id, farmName: farm.farmName),
      ),
    );
  }
}

class _FarmCard extends StatelessWidget {
  final FarmEntity farm;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onSelect;

  const _FarmCard({
    required this.farm,
    required this.isSelected,
    required this.onTap,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = isSelected ? theme.colorScheme.primary : Colors.grey.shade200;

    return Card(
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: isSelected ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.agriculture,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          farm.farmName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        if (farm.description != null && farm.description!.isNotEmpty)
                          Text(
                            farm.description!,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (farm.isVerified)
                        const _StatusBadge(
                          icon: Icons.verified,
                          label: 'Verified',
                          color: Colors.green,
                        ),
                      if (farm.isVerified) const SizedBox(width: 8),
                      if (!farm.isActive)
                        const _StatusBadge(
                          icon: Icons.pause_circle,
                          label: 'Inactive',
                          color: Colors.orange,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (farm.size != null)
                    _FarmDetailChip(
                      icon: Icons.straighten,
                      label: '${farm.size!.toStringAsFixed(1)} ha',
                    ),
                  if (farm.size != null) const SizedBox(width: 12),
                  _FarmDetailChip(
                    icon: farm.isActive ? Icons.check_circle : Icons.pause_circle,
                    label: farm.isActive ? 'Active' : 'Inactive',
                    color: farm.isActive ? Colors.green : Colors.orange,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onSelect,
                    icon: Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? theme.colorScheme.primary : Colors.grey,
                      size: 20,
                    ),
                    tooltip: isSelected ? 'Selected' : 'Select Farm',
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FarmDetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _FarmDetailChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Colors.grey.shade600;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: chipColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: chipColor, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

