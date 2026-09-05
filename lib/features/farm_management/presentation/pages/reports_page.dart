import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';

import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/domain/utils/display_text.dart';
import 'package:famhub_app/features/farm_management/presentation/widgets/workspace_tab_header.dart';

// ─────────────────────────────────────────────────────────────
// HONEST REPORT DATA
//
// Every value below is derived from an existing authorized repository
// call. Missing financial data is NEVER fabricated — sales/expenses/profit
// are simply omitted until the backend exposes a trustworthy source.
// ─────────────────────────────────────────────────────────────

class FarmReportEntry {
  final FarmEntity farm;
  final List<FieldEntity> fields;
  final List<CropEntity> crops;
  final List<LivestockEntity> livestock;

  /// Summed production quantity per asset id (production_records.asset_id).
  final Map<String, double> productionByAsset;

  /// Activity count per asset id (activities.asset_id).
  final Map<String, int> activitiesByAsset;

  /// Available stock quantity per asset id (assets.quantity > 0).
  final Map<String, double> stockByAsset;

  const FarmReportEntry({
    required this.farm,
    this.fields = const [],
    this.crops = const [],
    this.livestock = const [],
    this.productionByAsset = const {},
    this.activitiesByAsset = const {},
    this.stockByAsset = const {},
  });

  double get totalProduction => productionByAsset.values.fold(
      0, (sum, v) => sum + v);

  int get totalActivities =>
      activitiesByAsset.values.fold(0, (sum, v) => sum + v);

  double get totalStockQty =>
      stockByAsset.values.fold(0, (sum, v) => sum + v);

  FieldEntity? fieldById(String? id) {
    if (id == null) return null;
    for (final f in fields) {
      if (f.id == id) return f;
    }
    return null;
  }
}

/// Builds reporting data for ALL of the user's authorized farms. Any farm
/// that fails to load is skipped so one broken farm never blanks the tab.
final farmReportsProvider =
    FutureProvider<Map<String, FarmReportEntry>>((ref) async {
  final repository = ref.read(farmRepositoryProvider);
  final farms = await repository.getUserFarms();
  final out = <String, FarmReportEntry>{};

  for (final farm in farms) {
    List<FieldEntity> fields = const [];
    List<CropEntity> crops = const [];
    List<LivestockEntity> livestock = const [];
    try {
      fields = await repository.getFields(farmId: farm.id);
    } catch (_) {}
    try {
      crops = await repository.getCrops(farmId: farm.id);
    } catch (_) {}
    try {
      livestock = await repository.getLivestock(farmId: farm.id);
    } catch (_) {}

    final productionByAsset = <String, double>{};
    try {
      final records = await repository.getProductionRecords(farmId: farm.id);
      for (final record in records) {
        final assetId = record.assetId;
        if (assetId == null) continue;
        productionByAsset[assetId] =
            (productionByAsset[assetId] ?? 0) + (record.quantity ?? 0);
      }
    } catch (_) {}

    final activitiesByAsset = <String, int>{};
    try {
      final activities = await repository.getActivities(farmId: farm.id);
      for (final activity in activities) {
        final assetId = activity.assetId ?? activity.cropOrLivestockId;
        if (assetId == null) continue;
        activitiesByAsset[assetId] = (activitiesByAsset[assetId] ?? 0) + 1;
      }
    } catch (_) {}

    var stockByAsset = <String, double>{};
    try {
      stockByAsset = await repository.getAvailableStock(farmId: farm.id);
    } catch (_) {}

    out[farm.id] = FarmReportEntry(
      farm: farm,
      fields: fields,
      crops: crops,
      livestock: livestock,
      productionByAsset: productionByAsset,
      activitiesByAsset: activitiesByAsset,
      stockByAsset: stockByAsset,
    );
  }

  return out;
});

// ─────────────────────────────────────────────────────────────
// REPORTS WORKSPACE
// ─────────────────────────────────────────────────────────────

class ReportsPage extends ConsumerStatefulWidget {
  /// Switch to the Crops tab.
  final VoidCallback? onOpenCrops;

  /// Switch to the Livestock tab.
  final VoidCallback? onOpenLivestock;

  /// Switch to the Activity Logs tab.
  final VoidCallback? onOpenActivities;

  const ReportsPage({
    super.key,
    this.onOpenCrops,
    this.onOpenLivestock,
    this.onOpenActivities,
  });

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  void _resetToGlobal() {
    ref.read(hierarchyProvider.notifier).reset();
  }

  void _openFarm(FarmEntity farm) {
    ref.read(hierarchyProvider.notifier).selectEntity(farm);
  }

  void _openCrop(FarmReportEntry entry, CropEntity crop) {
    final notifier = ref.read(hierarchyProvider.notifier);
    notifier.selectEntity(entry.farm);
    final field = entry.fieldById(crop.fieldId);
    if (field != null) notifier.selectField(field);
    notifier.selectCrop(crop);
    widget.onOpenCrops?.call();
  }

  void _openLivestock(FarmReportEntry entry, LivestockEntity animal) {
    final notifier = ref.read(hierarchyProvider.notifier);
    notifier.selectEntity(entry.farm);
    final field = entry.fieldById(animal.fieldId);
    if (field != null) notifier.selectField(field);
    notifier.selectLivestock(animal);
    widget.onOpenLivestock?.call();
  }

  @override
  Widget build(BuildContext context) {
    final hierarchy = ref.watch(hierarchyProvider);
    final reportsAsync = ref.watch(farmReportsProvider);

    if (hierarchy.cropOrLivestock is CropEntity) {
      return _buildAssetReport(context, reportsAsync, isCrop: true);
    }
    if (hierarchy.cropOrLivestock is LivestockEntity) {
      return _buildAssetReport(context, reportsAsync, isCrop: false);
    }
    if (hierarchy.hasEntity) {
      return _buildFarmReport(context, reportsAsync);
    }
    return _buildGlobalReport(context, reportsAsync);
  }

  // ─────────────────────────────────────────────────────────────
  // GLOBAL (ALL FARMS)
  // ─────────────────────────────────────────────────────────────
  Widget _buildGlobalReport(
    BuildContext context,
    AsyncValue<Map<String, FarmReportEntry>> reportsAsync,
  ) {
    return _ReportsScaffold(
      subtitle: 'How are all your farms performing?',
      child: reportsAsync.when(
        loading: () => const LoadingStateWidget(useSkeleton: true),
        error: (err, _) => ErrorStateWidget(
          title: 'Unable to load farm performance',
          message: 'We encountered a problem loading your reports.',
          retryLabel: 'Retry',
          onRetry: () => ref.invalidate(farmReportsProvider),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.agriculture,
              title: 'No Farms Registered',
              subtitle: 'Add a farm to start viewing performance reports.',
            );
          }
          final sorted = entries.values.toList()
            ..sort((a, b) => a.farm.farmName.compareTo(b.farm.farmName));

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: sorted.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const _FinancialUnavailableNote();
              }
              final entry = sorted[index - 1];
              return _FarmSummaryRow(
                entry: entry,
                onTap: () => _openFarm(entry.farm),
              );
            },
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FARM REPORT
  // ─────────────────────────────────────────────────────────────
  Widget _buildFarmReport(
    BuildContext context,
    AsyncValue<Map<String, FarmReportEntry>> reportsAsync,
  ) {
    final hierarchy = ref.watch(hierarchyProvider);
    final farmId = hierarchy.entityId;

    return _ReportsScaffold(
      subtitle: hierarchy.entity?.farmName ?? 'Farm',
      leadingBack: TextButton.icon(
        onPressed: _resetToGlobal,
        icon: const Icon(Icons.arrow_back, size: 18),
        label: const Text('All Farms'),
      ),
      child: reportsAsync.when(
        loading: () => const LoadingStateWidget(useSkeleton: true),
        error: (err, _) => ErrorStateWidget(
          title: 'Unable to load farm performance',
          message: 'We encountered a problem loading your reports.',
          retryLabel: 'Retry',
          onRetry: () => ref.invalidate(farmReportsProvider),
        ),
        data: (entries) {
          final entry = entries[farmId];
          if (entry == null) {
            return const EmptyStateWidget(
              icon: Icons.description_outlined,
              title: 'Farm report unavailable',
              subtitle: 'No reporting data is available for this farm.',
            );
          }
          return _buildFarmBody(context, entry);
        },
      ),
    );
  }

  Widget _buildFarmBody(BuildContext context, FarmReportEntry entry) {
    final theme = Theme.of(context);
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricTile(
                    label: 'Production',
                    value: entry.totalProduction > 0
                        ? _num(entry.totalProduction)
                        : '—',
                    icon: Icons.production_quantity_limits,
                    color: Colors.green,
                  ),
                  _MetricTile(
                    label: 'Activities',
                    value: '${entry.totalActivities}',
                    icon: Icons.list_alt,
                    color: Colors.blue,
                  ),
                  _MetricTile(
                    label: 'Crops',
                    value: '${entry.crops.length}',
                    icon: Icons.eco,
                    color: Colors.teal,
                  ),
                  _MetricTile(
                    label: 'Livestock',
                    value: '${entry.livestock.length}',
                    icon: Icons.pets,
                    color: Colors.orange,
                  ),
                  if (entry.stockByAsset.isNotEmpty)
                    _MetricTile(
                      label: 'Stocked Items',
                      value: '${entry.stockByAsset.length}',
                      icon: Icons.inventory,
                      color: Colors.indigo,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.onOpenActivities != null)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: widget.onOpenActivities,
              icon: const Icon(Icons.list_alt, size: 18),
              label: const Text('Open Activity Logs'),
            ),
          ),
        const SizedBox(height: 20),

        if (entry.crops.isNotEmpty) ...[
          Text(
            'Crops',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...entry.crops.map((crop) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AssetReportRow(
                  title: assetDisplayTitle(crop.cropName),
                  activities:
                      entry.activitiesByAsset[crop.id] ?? 0,
                  production:
                      entry.productionByAsset[crop.id] ?? 0,
                  color: Colors.green,
                  icon: Icons.eco,
                  onTap: () => _openCrop(entry, crop),
                ),
              )),
          const SizedBox(height: 12),
        ],

        if (entry.livestock.isNotEmpty) ...[
          Text(
            'Livestock',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...entry.livestock.map((animal) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AssetReportRow(
                  title: assetDisplayTitle(animal.species),
                  activities:
                      entry.activitiesByAsset[animal.id] ?? 0,
                  production:
                      entry.productionByAsset[animal.id] ?? 0,
                  color: Colors.orange,
                  icon: Icons.pets,
                  onTap: () => _openLivestock(entry, animal),
                ),
              )),
          const SizedBox(height: 12),
        ],

        if (entry.crops.isEmpty && entry.livestock.isEmpty)
          const _NoAssetsYet(),

        const _FinancialUnavailableNote(),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ASSET REPORT (crop / livestock)
  // ─────────────────────────────────────────────────────────────
  Widget _buildAssetReport(
    BuildContext context,
    AsyncValue<Map<String, FarmReportEntry>> reportsAsync,
    {required bool isCrop,
  }) {
    final hierarchy = ref.watch(hierarchyProvider);
    final entity = hierarchy.cropOrLivestock;
    final assetId = hierarchy.cropOrLivestockId;
    final farmName = hierarchy.entity?.farmName ?? '—';
    final fieldName = hierarchy.field?.fieldName ?? '—';

    final assetLabel = isCrop
        ? assetDisplayTitle((entity as CropEntity).cropName)
        : assetDisplayTitle((entity as LivestockEntity).species);

    return _ReportsScaffold(
      subtitle: assetLabel,
      leadingBack: TextButton.icon(
        onPressed: _resetToGlobal,
        icon: const Icon(Icons.arrow_back, size: 18),
        label: const Text('All Farms'),
      ),
      contextPath: [farmName, fieldName],
      child: reportsAsync.when(
        loading: () => const LoadingStateWidget(useSkeleton: true),
        error: (err, _) => ErrorStateWidget(
          title: 'Unable to load asset report',
          message: 'We encountered a problem loading your reports.',
          retryLabel: 'Retry',
          onRetry: () => ref.invalidate(farmReportsProvider),
        ),
        data: (entries) {
          final entry = entries[hierarchy.entityId];
          if (entry == null) {
            return const EmptyStateWidget(
              icon: Icons.description_outlined,
              title: 'Report unavailable',
              subtitle: 'No reporting data is available for this asset.',
            );
          }
          final activities = entry.activitiesByAsset[assetId] ?? 0;
          final production = entry.productionByAsset[assetId] ?? 0;
          final stockQty = entry.stockByAsset[assetId];

          return ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricTile(
                    label: isCrop ? 'Crop' : 'Livestock',
                    value: assetLabel,
                    icon: isCrop ? Icons.eco : Icons.pets,
                    color: isCrop ? Colors.green : Colors.orange,
                  ),
                  _MetricTile(
                    label: 'Activities',
                    value: '$activities',
                    icon: Icons.list_alt,
                    color: Colors.blue,
                  ),
                  if (production > 0)
                    _MetricTile(
                      label: 'Production',
                      value: _num(production),
                      icon: Icons.production_quantity_limits,
                      color: Colors.teal,
                    ),
                  if (stockQty != null && stockQty > 0)
                    _MetricTile(
                      label: 'Stock',
                      value: _num(stockQty),
                      icon: Icons.inventory,
                      color: Colors.indigo,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.onOpenActivities != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: widget.onOpenActivities,
                    icon: const Icon(Icons.list_alt, size: 18),
                    label: const Text('Open Activity Logs'),
                  ),
                ),
              const SizedBox(height: 20),
              _InfoCard(
                rows: [
                  ('Farm', farmName),
                  ('Field', fieldName),
                  ('Asset', assetLabel),
                  if (production > 0) ('Production', _num(production)),
                  if (stockQty != null && stockQty > 0)
                    ('Stock', _num(stockQty)),
                ],
              ),
              const _FinancialUnavailableNote(),
            ],
          );
        },
      ),
    );
  }

  String _num(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

// ─────────────────────────────────────────────────────────────
// SCAFFOLD + SHARED WIDGETS
// ─────────────────────────────────────────────────────────────

class _ReportsScaffold extends StatelessWidget {
  final String subtitle;
  final Widget child;
  final Widget? leadingBack;
  final List<String>? contextPath;

  const _ReportsScaffold({
    required this.subtitle,
    required this.child,
    this.leadingBack,
    this.contextPath,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          if (leadingBack != null) ...[
            leadingBack!,
            const Divider(height: 1),
          ],
          const SizedBox(height: 4),
          WorkspaceTabHeader(
            title: 'Reports',
            subtitle: subtitle,
            icon: Icons.description,
            color: Colors.purple,
          ),
          if (contextPath != null && contextPath!.isNotEmpty) ...[
            _BreadcrumbLine(segments: contextPath!),
            const SizedBox(height: 8),
          ],
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _BreadcrumbLine extends StatelessWidget {
  final List<String> segments;

  const _BreadcrumbLine({required this.segments});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
      ),
      child: Text(
        segments.join('  ›  '),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label: ',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AssetReportRow extends StatelessWidget {
  final String title;
  final int activities;
  final double production;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _AssetReportRow({
    required this.title,
    required this.activities,
    required this.production,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (activities > 0) '$activities activities',
                      if (production > 0)
                        '${production == production.roundToDouble() ? production.toInt().toString() : production.toStringAsFixed(1)} production',
                    ].join(' · '),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _FarmSummaryRow extends StatelessWidget {
  final FarmReportEntry entry;
  final VoidCallback onTap;

  const _FarmSummaryRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.agriculture,
                      size: 20, color: Colors.purple),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.farm.farmName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _stat('Production', entry.totalProduction > 0
                    ? (entry.totalProduction == entry.totalProduction
                            .roundToDouble()
                        ? entry.totalProduction.toInt().toString()
                        : entry.totalProduction.toStringAsFixed(1))
                    : '—'),
                _stat('Activities', '${entry.totalActivities}'),
                _stat('Crops', '${entry.crops.length}'),
                _stat('Livestock', '${entry.livestock.length}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Text(
      '$label: $value',
      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<(String, String)> rows;

  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows
              .map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            r.$1,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            r.$2,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _NoAssetsYet extends StatelessWidget {
  const _NoAssetsYet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        'No crops or livestock recorded on this farm yet.',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      ),
    );
  }
}

class _FinancialUnavailableNote extends StatelessWidget {
  const _FinancialUnavailableNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.amber),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Financial reporting (sales, expenses, profit) is not yet '
              'available. Other farm metrics shown here come from recorded '
              'production, activities and stock.',
              style: TextStyle(fontSize: 12, color: Colors.brown),
            ),
          ),
        ],
      ),
    );
  }
}
