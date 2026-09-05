import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';

import 'package:famhub_app/features/farm_management/application/providers/fields_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/crops_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/livestock_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/domain/enums/crop_status.dart';

import 'package:famhub_app/features/farm_management/presentation/pages/add_field_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/add_crop_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/add_livestock_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/activities_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/production_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/reports_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/crop_livestock_detail_page.dart';

/// Farm Detail Page — the farm workspace.
///
/// The farmer enters a farm first, then works inside its fields:
///   Farm → Field/Block → Crop/Livestock → Activity → Production/Reports
///
/// Shows:
///   - Farm name / location / size
///   - Fields (tapping a field selects it in the hierarchy)
///   - Crops & Livestock for the selected field (+ Add Crop / Add Livestock)
///   - Add Field at the farm level
///
/// The page preserves the selected farm context via hierarchyProvider
/// (the single source of truth). No farmSelector state is used.
class FarmDetailPage extends ConsumerStatefulWidget {
  final String farmId;
  final String farmName;

  const FarmDetailPage({
    super.key,
    required this.farmId,
    required this.farmName,
  });

  @override
  ConsumerState<FarmDetailPage> createState() => _FarmDetailPageState();
}

class _FarmDetailPageState extends ConsumerState<FarmDetailPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_ensureFarmContext);
  }

  /// Ensure the hierarchy entity is this farm, then load its fields.
  void _ensureFarmContext() {
    final hierarchy = ref.read(hierarchyProvider);
    if (hierarchy.entityId != widget.farmId) {
      ref
          .read(hierarchyProvider.notifier)
          .selectEntityById(widget.farmId, entityName: widget.farmName);
    }
    _loadFields();
  }

  void _loadFields() {
    final farmId = ref.read(farmContextProvider).farmId ?? widget.farmId;
    ref.read(fieldsProvider.notifier).loadFields(farmId: farmId);
  }

  void _selectField(FieldEntity field) {
    ref.read(hierarchyProvider.notifier).selectField(field);
  }

  void _openAddField() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddFieldPage())).then((_) {
      if (!mounted) return;
      ref.invalidate(fieldsProvider);
      _loadFields();
    });
  }

  void _openAddCrop() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddCropPage()));
  }

  void _openAddLivestock() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddLivestockPage()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hierarchy = ref.watch(hierarchyProvider);
    final farmContext = ref.watch(farmContextProvider);
    final fieldState = ref.watch(fieldsProvider);

    // Wait until the hierarchy has this farm selected.
    final entity = hierarchy.entity;
    if (entity == null || entity.id != widget.farmId) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.farmName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final farm = farmContext.farm ?? entity;
    final selectedField = hierarchy.field;

    return Scaffold(
      appBar: AppBar(title: const Text('Farm Details')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // ── Farm header ──
          _buildFarmHeader(context, theme, farm),
          const SizedBox(height: 16),

          // ── Fields ──
          _sectionHeader(context, 'Fields', Icons.landscape, Colors.brown),
          const SizedBox(height: 8),
          if (fieldState.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (fieldState.errorMessage != null)
            ErrorStateWidget(
              title: 'Could not load fields',
              message: fieldState.errorMessage!,
              retryLabel: 'Retry',
              onRetry: _loadFields,
            )
          else if (fieldState.fields.isEmpty)
            _buildNoFields(context, theme)
          else
            _buildFieldsList(context, fieldState.fields, selectedField),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _openAddField,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Field'),
            ),
          ),
          const SizedBox(height: 20),

          // ── Crops & Livestock for the selected field ──
          _sectionHeader(
            context,
            'Crops & Livestock',
            Icons.eco,
            Colors.green,
            trailing: selectedField?.fieldName,
          ),
          const SizedBox(height: 8),
          _buildFieldContent(context, hierarchy),
          const SizedBox(height: 24),

          // ── Activities / Production / Reports ──
          _sectionHeader(context, 'Records', Icons.edit_note, Colors.blue),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openPage(const ActivitiesPage()),
                icon: const Icon(Icons.list_alt, size: 18),
                label: const Text('Activities'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openPage(const ProductionRecordingPage()),
                icon: const Icon(Icons.shopping_basket, size: 18),
                label: const Text('Production'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openPage(const ReportsPage()),
                icon: const Icon(Icons.description, size: 18),
                label: const Text('Reports'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _openCropDetails(CropEntity crop) {
    ref.read(hierarchyProvider.notifier).selectCrop(crop);
    _openPage(CropLivestockDetailPage.crop(crop: crop));
  }

  void _openLivestockDetails(LivestockEntity animal) {
    ref.read(hierarchyProvider.notifier).selectLivestock(animal);
    _openPage(CropLivestockDetailPage.livestock(livestock: animal));
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildFarmHeader(
    BuildContext context,
    ThemeData theme,
    FarmEntity farm,
  ) {
    final name = farm.farmName;
    final description = farm.description;
    final size = farm.size;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.agriculture,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
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
                if (size != null)
                  _infoChip(
                    Icons.straighten,
                    '${size.toStringAsFixed(1)} ha',
                    Colors.blue,
                  ),
                _infoChip(
                  Icons.check_circle,
                  'You are inside this farm',
                  Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    String title,
    IconData icon,
    Color color, {
    String? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              trailing,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNoFields(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.map, size: 32, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'No fields yet',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add a field to start managing crops and livestock.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFieldsList(
    BuildContext context,
    List<FieldEntity> fields,
    FieldEntity? selectedField,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final field in fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FieldCard(
              field: field,
              isSelected: selectedField?.id == field.id,
              onTap: () => _selectField(field),
              onAddCrop: () {
                _selectField(field);
                _openAddCrop();
              },
              onAddLivestock: () {
                _selectField(field);
                _openAddLivestock();
              },
            ),
          ),
        if (selectedField != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  'Managing: ${selectedField.fieldName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Crops & Livestock for the currently selected field.
  Widget _buildFieldContent(
    BuildContext context,
    HierarchySelectionState hierarchy,
  ) {
    final theme = Theme.of(context);

    if (!hierarchy.hasField) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.touch_app, size: 20, color: Colors.grey.shade400),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Select a field above to manage its crops and livestock.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      );
    }

    final fieldName = hierarchy.field?.fieldName ?? '';
    final cropsAsync = ref.watch(cropsByFieldProvider);
    final livestockAsync = ref.watch(livestockByFieldProvider);

    if (cropsAsync.isLoading || livestockAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (cropsAsync.hasError || livestockAsync.hasError) {
      return ErrorStateWidget(
        title: 'Could not load crops & livestock',
        message:
            cropsAsync.error?.toString() ??
            livestockAsync.error?.toString() ??
            '',
        retryLabel: 'Retry',
        onRetry: () {
          ref.invalidate(cropsByFieldProvider);
          ref.invalidate(livestockByFieldProvider);
        },
      );
    }

    final crops = cropsAsync.value ?? const <CropEntity>[];
    final livestock = livestockAsync.value ?? const <LivestockEntity>[];
    final hasContent = crops.isNotEmpty || livestock.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasContent)
          _buildEmptyFieldState(context, theme, fieldName)
        else ...[
          if (crops.isNotEmpty) ...[
            Text(
              'Crops',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            for (final crop in crops)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _CropTile(
                  crop: crop,
                  onTap: () => _openCropDetails(crop),
                ),
              ),
            const SizedBox(height: 12),
          ],
          if (livestock.isNotEmpty) ...[
            Text(
              'Livestock',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            for (final animal in livestock)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _LivestockTile(
                  animal: animal,
                  onTap: () => _openLivestockDetails(animal),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ],
        // ── Add actions stay available while the field is active ──
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _openAddCrop,
                icon: const Icon(Icons.eco, size: 18),
                label: const Text('Add Crop'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _openAddLivestock,
                icon: const Icon(Icons.pets, size: 18),
                label: const Text('Add Livestock'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyFieldState(
    BuildContext context,
    ThemeData theme,
    String fieldName,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.grass, size: 36, color: Colors.green.shade600),
          const SizedBox(height: 8),
          Text(
            'Start farming in $fieldName',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.green.shade900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'No crops or livestock yet. Add your first one to begin.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.green.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// ────────────────────────────────────────────────────────────
/// FIELD CARD
/// ────────────────────────────────────────────────────────────
class _FieldCard extends StatelessWidget {
  final FieldEntity field;
  final bool isSelected;
  final VoidCallback onTap;

  /// Opens the Add Crop flow scoped to this field.
  final VoidCallback? onAddCrop;

  /// Opens the Add Livestock flow scoped to this field.
  final VoidCallback? onAddLivestock;

  const _FieldCard({
    required this.field,
    required this.isSelected,
    required this.onTap,
    this.onAddCrop,
    this.onAddLivestock,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected ? theme.colorScheme.primary : Colors.brown;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : Colors.grey.shade200,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.landscape, size: 20, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field.fieldName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (field.soilType != null &&
                            field.soilType!.isNotEmpty)
                          Text(
                            field.soilType!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (field.acreage != null)
                    Text(
                      '${field.acreage!.toStringAsFixed(1)} ha',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.chevron_right,
                    size: 20,
                    color: isSelected ? theme.colorScheme.primary : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (onAddCrop != null || onAddLivestock != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  if (onAddCrop != null)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onAddCrop,
                        icon: const Icon(Icons.eco, size: 16),
                        label: const Text('Add Crop'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  if (onAddCrop != null && onAddLivestock != null)
                    const SizedBox(width: 8),
                  if (onAddLivestock != null)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onAddLivestock,
                        icon: const Icon(Icons.pets, size: 16),
                        label: const Text('Add Livestock'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────
/// CROP TILE
/// ────────────────────────────────────────────────────────────
class _CropTile extends StatelessWidget {
  final CropEntity crop;
  final VoidCallback onTap;

  const _CropTile({required this.crop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _cropColor(crop.status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.grass, size: 18, color: statusColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                crop.cropName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              crop.statusLabel,
              style: TextStyle(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _cropColor(CropStatus status) {
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
}

/// ────────────────────────────────────────────────────────────
/// LIVESTOCK TILE
/// ────────────────────────────────────────────────────────────
class _LivestockTile extends StatelessWidget {
  final LivestockEntity animal;
  final VoidCallback onTap;

  const _LivestockTile({required this.animal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.pets, size: 18, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                animal.species,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${animal.count} head',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
