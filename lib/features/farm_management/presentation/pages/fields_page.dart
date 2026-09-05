import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/cards/kpi_card.dart';
import 'package:famhub_app/shared/layouts/adaptive_content_grid.dart';

import 'package:famhub_app/features/farm_management/application/providers/fields_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/add_field_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/add_crop_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/add_livestock_page.dart';

class FieldsPage extends ConsumerStatefulWidget {
  const FieldsPage({super.key});

  @override
  ConsumerState<FieldsPage> createState() => _FieldsPageState();
}

class _FieldsPageState extends ConsumerState<FieldsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadFields());
  }

  Future<void> _loadFields() async {
    final farmId = ref.read(farmContextProvider).farmId;
    if (farmId != null) {
      ref.read(fieldsProvider.notifier).loadFields(farmId: farmId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(farmContextProvider).farmId;
    final hierarchy = ref.watch(hierarchyProvider);

    if (farmId == null) {
      return const ShellPageContent(
        title: 'Fields',
        subtitle: 'Select a farm to view fields',
        child: SizedBox.shrink(),
      );
    }

    final fieldState = ref.watch(fieldsProvider);

    if (fieldState.isLoading) {
      return const ShellPageContent(
        title: 'Fields',
        subtitle: 'Loading field registry...',
        child: LoadingStateWidget(useSkeleton: true),
      );
    }

    if (fieldState.errorMessage != null) {
      return ShellPageContent(
        title: 'Fields',
        subtitle: 'Failed to load field data',
        child: ErrorStateWidget(
          title: 'Error Loading Fields',
          message: fieldState.errorMessage!,
          retryLabel: 'Retry',
          onRetry: _loadFields,
        ),
      );
    }

    final fields = fieldState.fields;
    final totalAcreage = fieldState.totalAcreage;
    final cultivated = fields.where((f) => f.isCultivated).length;
    final fallow = fields.where((f) => !f.isCultivated).length;

    return ShellPageContent(
      title: 'Fields',
      subtitle: hierarchy.hasField
          ? 'Selected: ${hierarchy.field!.fieldName}'
          : '${fields.length} field${fields.length == 1 ? '' : 's'}',
      actions: [
        // âœ… CONTEXT: Add Field visible ONLY when a Farm/Entity is selected
        if (hierarchy.hasEntity)
          IconButton(
            onPressed: () => _navigateToAddField(context),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Field / Block',
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // â”€â”€ KPIs â”€â”€
          AdaptiveContentGrid(
            items: [
              KPICard(
                label: 'Total Fields',
                value: '${fields.length}',
                icon: Icons.landscape,
                iconColor: Colors.green,
              ),
              KPICard(
                label: 'Total Acreage',
                value: '${totalAcreage.toStringAsFixed(1)} ha',
                icon: Icons.straighten,
                iconColor: Colors.blue,
              ),
              KPICard(
                label: 'Cultivated',
                value: '$cultivated',
                icon: Icons.eco,
                iconColor: Colors.teal,
              ),
              KPICard(
                label: 'Fallow',
                value: '$fallow',
                icon: Icons.restore,
                iconColor: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // â”€â”€ Field List â”€â”€
          if (fields.isEmpty)
            const Expanded(
              child: EmptyStateWidget(
                icon: Icons.map,
                title: 'No Fields Registered',
                subtitle: 'Add field information to start tracking.',
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: fields.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final field = fields[index];
                  return FieldCard(
                    field: field,
                    onAddCrop: () => _addCrop(field),
                    onAddLivestock: () => _addLivestock(field),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToAddField(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddFieldPage()));
  }

  /// Selects [field] in the hierarchy so the add form is scoped to it, then
  /// opens the Add Crop flow.
  void _addCrop(FieldEntity field) {
    if (!_ensureFieldContext(field)) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddCropPage()));
  }

  /// Selects [field] in the hierarchy so the add form is scoped to it, then
  /// opens the Add Livestock flow.
  void _addLivestock(FieldEntity field) {
    if (!_ensureFieldContext(field)) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddLivestockPage()));
  }

  /// Ensures a farm/entity is selected and selects [field] as the active
  /// field/block before opening a field-scoped form.
  bool _ensureFieldContext(FieldEntity field) {
    final hierarchy = ref.read(hierarchyProvider);
    if (hierarchy.entity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a farm first, then add crops or livestock.'),
        ),
      );
      return false;
    }
    ref.read(hierarchyProvider.notifier).selectField(field);
    return true;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'active':
      return Colors.green;
    case 'fallow':
      return Colors.orange;
    case 'resting':
      return Colors.blue;
    case 'leased':
      return Colors.purple;
    default:
      return Colors.grey;
  }
}

class FieldCard extends StatelessWidget {
  final FieldEntity field;

  /// Opens the Add Crop flow scoped to this field (optional).
  final VoidCallback? onAddCrop;

  /// Opens the Add Livestock flow scoped to this field (optional).
  final VoidCallback? onAddLivestock;

  const FieldCard({
    super.key,
    required this.field,
    this.onAddCrop,
    this.onAddLivestock,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(field.status);

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
                  child: Icon(Icons.landscape, size: 20, color: statusColor),
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
                      if (field.soilType != null)
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
                    field.statusLabel,
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
                if (field.acreage != null)
                  InfoChip(
                    icon: Icons.straighten,
                    label: '${field.acreage!.toStringAsFixed(1)} ha',
                  ),
                if (field.acreage != null) const SizedBox(width: 12),
                if (field.currentCrop != null)
                  InfoChip(icon: Icons.grass, label: field.currentCrop!),
                if (field.currentCrop != null) const SizedBox(width: 12),
                InfoChip(icon: Icons.circle, label: field.statusLabel),
              ],
            ),
            if (onAddCrop != null || onAddLivestock != null) ...[
              const SizedBox(height: 12),
              Row(
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
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'fallow':
        return Colors.orange;
      case 'resting':
        return Colors.blue;
      case 'leased':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const InfoChip({super.key, required this.icon, required this.label});

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
