import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';

import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_selector_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/fields_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/crops_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/livestock_provider.dart';

import 'package:famhub_app/features/farm_management/presentation/pages/add_farm_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/add_field_page.dart';
import 'package:famhub_app/features/farm_management/presentation/widgets/workspace_tab_header.dart';

/// My Farms tab — the Farm → Field → Crop/Livestock hierarchy workspace.
///
/// Everything happens INSIDE this tab (and therefore inside the Farm
/// Homepage). Selecting a farm shows its details + fields; selecting a
/// field shows that field's crops and livestock; selecting an asset
/// updates the hierarchy and asks the parent to open the Crops/Livestock
/// tab. No standalone farm-dashboard page is pushed.
class FarmsPage extends ConsumerStatefulWidget {
  /// Switch to the Crops tab after a crop asset is selected.
  final VoidCallback? onOpenCrops;

  /// Switch to the Livestock tab after a livestock asset is selected.
  final VoidCallback? onOpenLivestock;

  const FarmsPage({
    super.key,
    this.onOpenCrops,
    this.onOpenLivestock,
  });

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
    // Load fields for the currently selected farm whenever it changes.
    ref.listen<FarmContext>(farmContextProvider, (previous, next) {
      final farmId = next.farmId;
      if (farmId == null) return;
      if (previous?.farmId != farmId) {
        ref.read(fieldsProvider.notifier).loadFields(farmId: farmId);
      }
    });
    // A farm may already be selected before this tab mounts (e.g. Overview
    // auto-selects the first farm) — the listener only fires on CHANGE, so
    // ensure fields are loaded for the current farm on first build too.
    Future.microtask(() {
      final farmId = ref.read(farmContextProvider).farmId;
      if (farmId != null) {
        ref.read(fieldsProvider.notifier).loadFields(farmId: farmId);
      }
    });
  }

  void _loadFields() {
    final farmId = ref.read(farmContextProvider).farmId;
    if (farmId != null) {
      ref.read(fieldsProvider.notifier).loadFields(farmId: farmId);
    }
  }

  void _openFarm(FarmEntity farm) {
    ref.read(hierarchyProvider.notifier).selectEntity(farm);
  }

  void _backToFarms() {
    ref.read(hierarchyProvider.notifier).reset();
  }

  void _openField(FieldEntity field) {
    ref.read(hierarchyProvider.notifier).selectField(field);
  }

  void _openCrop(CropEntity crop) {
    ref.read(hierarchyProvider.notifier).selectCrop(crop);
    widget.onOpenCrops?.call();
  }

  void _openLivestock(LivestockEntity animal) {
    ref.read(hierarchyProvider.notifier).selectLivestock(animal);
    widget.onOpenLivestock?.call();
  }

  void _openAddFarm() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddFarmPage()),
    );
  }

  void _openAddField() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddFieldPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final farmState = ref.watch(farmSelectorProvider);
    final hierarchy = ref.watch(hierarchyProvider);

    if (hierarchy.hasEntity) {
      return _buildFarmDetail(context, hierarchy);
    }
    return _buildFarmList(context, farmState);
  }

  // ─────────────────────────────────────────────────────────────
  // FARM LIST
  // ─────────────────────────────────────────────────────────────
  Widget _buildFarmList(BuildContext context, FarmSelectorState farmState) {
    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          WorkspaceTabHeader(
            title: 'My Farms',
            subtitle: 'Select a farm to browse its fields, crops and livestock',
            icon: Icons.agriculture,
            color: Theme.of(context).colorScheme.primary,
            actions: [
              IconButton(
                onPressed: _openAddFarm,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Add Farm',
              ),
            ],
          ),
          const SizedBox(height: 4),

          if (farmState.isLoading)
            const Expanded(
              child: LoadingStateWidget(useSkeleton: true),
            )
          else if (farmState.errorMessage != null)
            Expanded(
              child: ErrorStateWidget(
                title: 'Failed to Load Farms',
                message: farmState.errorMessage!,
                retryLabel: 'Retry',
                onRetry: () =>
                    ref.read(farmSelectorProvider.notifier).loadFarms(),
              ),
            )
          else if (farmState.farms.isEmpty)
            const Expanded(
              child: EmptyStateWidget(
                icon: Icons.agriculture,
                title: 'No Farms Registered',
                subtitle:
                    'Add your first farm to start managing operations.',
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: farmState.farms.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final farm = farmState.farms[index];
                  return _FarmBrowserCard(
                    farm: farm,
                    onOpen: () => _openFarm(farm),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FARM DETAIL (fields + assets)
  // ─────────────────────────────────────────────────────────────
  Widget _buildFarmDetail(
    BuildContext context,
    HierarchySelectionState hierarchy,
  ) {
    final theme = Theme.of(context);
    final farm = hierarchy.entity;
    final selectedField = hierarchy.field;
    final fieldState = ref.watch(fieldsProvider);

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Back / breadcrumb ──
          Row(
            children: [
              TextButton.icon(
                onPressed: _backToFarms,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('My Farms'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  farm?.farmName ?? 'Farm',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                if (farm != null) _buildFarmHeader(theme, farm),
                const SizedBox(height: 20),

                // ── Fields ──
                Row(
                  children: [
                    Text(
                      'Fields',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _openAddField,
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Add Field',
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                if (fieldState.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (fieldState.errorMessage != null)
                  ErrorStateWidget(
                    title: 'Could not load fields',
                    message: fieldState.errorMessage!,
                    retryLabel: 'Retry',
                    onRetry: _loadFields,
                  )
                else if (fieldState.fields.isEmpty)
                  _buildEmptyFields(theme)
                else
                  ...fieldState.fields.map((field) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildFieldSection(
                          theme,
                          field,
                          isOpen: selectedField?.id == field.id,
                        ),
                      )),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmHeader(ThemeData theme, FarmEntity farm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.agriculture,
                    color: theme.colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      farm.farmName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (farm.description != null &&
                        farm.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        farm.description!,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (farm.size != null)
                _chip(Icons.straighten, '${farm.size!.toStringAsFixed(1)} ha',
                    Colors.blue),
              _chip(
                Icons.check_circle,
                farm.isActive ? 'Active' : 'Inactive',
                farm.isActive ? Colors.green : Colors.orange,
              ),
              if (farm.isVerified)
                _chip(Icons.verified, 'Verified', Colors.teal),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFields(ThemeData theme) {
    return EmptyStateWidget(
      icon: Icons.map,
      title: 'No fields yet',
      subtitle: 'Add a field to start managing crops and livestock.',
      actionLabel: 'Add Field',
      onAction: _openAddField,
    );
  }

  /// A field + (when open) its crops & livestock.
  Widget _buildFieldSection(ThemeData theme, FieldEntity field, {required bool isOpen}) {
    final hierarchy = ref.watch(hierarchyProvider);
    final selectedFieldId = hierarchy.fieldId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOpen
              ? theme.colorScheme.primary.withValues(alpha: 0.6)
              : Colors.grey.shade200,
          width: isOpen ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              if (isOpen) {
                ref
                    .read(hierarchyProvider.notifier)
                    .clearToEntity();
              } else {
                _openField(field);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.brown.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.landscape,
                        size: 20, color: Colors.brown),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field.fieldName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (field.acreage != null ||
                            field.soilType != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (field.acreage != null)
                                '${field.acreage!.toStringAsFixed(1)} ha',
                              if (field.soilType != null &&
                                  field.soilType!.isNotEmpty)
                                field.soilType!,
                            ].join(' · '),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    isOpen ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          if (isOpen && selectedFieldId == field.id)
            _FieldAssetsSection(
              field: field,
              onOpenCrop: _openCrop,
              onOpenLivestock: _openLivestock,
            ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style:
              TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FIELD ASSETS (crops + livestock belonging to the field)
// ─────────────────────────────────────────────────────────────
class _FieldAssetsSection extends ConsumerWidget {
  final FieldEntity field;
  final void Function(CropEntity crop) onOpenCrop;
  final void Function(LivestockEntity animal) onOpenLivestock;

  const _FieldAssetsSection({
    required this.field,
    required this.onOpenCrop,
    required this.onOpenLivestock,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cropsAsync = ref.watch(cropsByFieldProvider);
    final livestockAsync = ref.watch(livestockByFieldProvider);

    return Container(
      width: double.infinity,
      color: Colors.grey.shade50,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),

          if (cropsAsync.isLoading || livestockAsync.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            if (cropsAsync.hasError || livestockAsync.hasError) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Could not load field assets.',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade400),
                ),
              ),
            ] else ...[
              _buildAssetGroup(
                theme,
                title: 'Crops',
                icon: Icons.eco,
                color: Colors.green,
                count: (cropsAsync.value ?? const []).length,
                items: (cropsAsync.value ?? const [])
                    .map((c) => AssetRowData(
                          id: c.id,
                          name: c.cropName,
                          detail: c.variety,
                          subtitleIcon: Icons.eco,
                          color: Colors.green,
                          onOpen: () => onOpenCrop(c),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              _buildAssetGroup(
                theme,
                title: 'Livestock',
                icon: Icons.pets,
                color: Colors.orange,
                count: (livestockAsync.value ?? const []).length,
                items: (livestockAsync.value ?? const [])
                    .map((l) => AssetRowData(
                          id: l.id,
                          name: l.species,
                          detail: l.breed,
                          trailing: '${l.count} head',
                          subtitleIcon: Icons.pets,
                          color: Colors.orange,
                          onOpen: () => onOpenLivestock(l),
                        ))
                    .toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAssetGroup(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required Color color,
    required int count,
    required List<AssetRowData> items,
  }) {
    if (count == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _AssetRow(item: item),
            )),
      ],
    );
  }
}

class AssetRowData {
  final String id;
  final String name;
  final String? detail;
  final String? trailing;
  final IconData subtitleIcon;
  final Color color;
  final VoidCallback onOpen;

  const AssetRowData({
    required this.id,
    required this.name,
    this.detail,
    this.trailing,
    required this.subtitleIcon,
    required this.color,
    required this.onOpen,
  });
}

class _AssetRow extends StatelessWidget {
  final AssetRowData item;

  const _AssetRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: item.onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: item.color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(item.subtitleIcon, size: 17, color: item.color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  if (item.detail != null && item.detail!.isNotEmpty)
                    Text(
                      item.detail!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
            if (item.trailing != null)
              Text(
                item.trailing!,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600),
              ),
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: item.onOpen,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
                foregroundColor: theme.colorScheme.primary,
              ),
              child: const Text('Open'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FARM BROWSER CARD
// ─────────────────────────────────────────────────────────────
class _FarmBrowserCard extends StatelessWidget {
  final FarmEntity farm;
  final VoidCallback onOpen;

  const _FarmBrowserCard({required this.farm, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onOpen,
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
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        if (farm.description != null &&
                            farm.description!.isNotEmpty)
                          Text(
                            farm.description!,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: onOpen,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Open'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (farm.size != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.straighten,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${farm.size!.toStringAsFixed(1)} ha',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  if (farm.isVerified)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  if (!farm.isActive)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pause_circle,
                            size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          'Inactive',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange),
                        ),
                      ],
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
