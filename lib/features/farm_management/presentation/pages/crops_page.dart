import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';

import 'package:famhub_app/features/farm_management/application/providers/crops_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';

/// Crops tab — the user's GLOBAL crop workspace.
///
/// Lists every crop asset across ALL of the user's farms and fields
/// (each row shows crop + farm + field). Selecting a crop sets the
/// hierarchy (farm → field → asset) and shows its details INSIDE this
/// tab. From details the user can jump to the Activity Logs tab with the
/// selected crop context preserved.
class CropsPage extends ConsumerStatefulWidget {
  /// Switch to the Activity Logs tab (selected crop context is in the
  /// hierarchy).
  final VoidCallback? onOpenActivities;

  /// Switch to the My Farms tab (used by the empty state).
  final VoidCallback? onGoToMyFarms;

  const CropsPage({
    super.key,
    this.onOpenActivities,
    this.onGoToMyFarms,
  });

  @override
  ConsumerState<CropsPage> createState() => _CropsPageState();
}

class _CropsPageState extends ConsumerState<CropsPage> {
  String _query = '';

  void _clearSelection() {
    ref.read(hierarchyProvider.notifier).clearToField();
  }

  void _selectCrop(GlobalCropEntry entry) {
    if (entry.farm == null || entry.field == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This crop has no linked farm/field yet.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final notifier = ref.read(hierarchyProvider.notifier);
    notifier.selectEntity(entry.farm!);
    notifier.selectField(entry.field!);
    notifier.selectCrop(entry.crop);
  }

  void _openActivities() {
    widget.onOpenActivities?.call();
  }

  @override
  Widget build(BuildContext context) {
    final hierarchy = ref.watch(hierarchyProvider);
    final hasSelected =
        hierarchy.cropOrLivestockType == 'crop' &&
            hierarchy.cropOrLivestock is CropEntity;

    if (hasSelected) {
      return _buildDetail(context, hierarchy.cropOrLivestock as CropEntity);
    }
    return _buildList(context);
  }

  // ─────────────────────────────────────────────────────────────
  // ALL CROPS LIST
  // ─────────────────────────────────────────────────────────────
  Widget _buildList(BuildContext context) {
    final cropsAsync = ref.watch(allUserCropsProvider);
    final query = _query.trim().toLowerCase();

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Crops',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'All your crops across every farm',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search crops by name, farm or field...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: cropsAsync.when(
              loading: () => const LoadingStateWidget(useSkeleton: true),
              error: (err, _) => ErrorStateWidget(
                title: 'Could not load crops',
                message: err.toString(),
                retryLabel: 'Retry',
                onRetry: () => ref.invalidate(allUserCropsProvider),
              ),
              data: (entries) {
                final filtered = entries.where((e) {
                  if (query.isEmpty) return true;
                  return (e.crop.cropName.toLowerCase().contains(query)) ||
                      (e.crop.variety?.toLowerCase().contains(query) ?? false) ||
                      (e.farmName?.toLowerCase().contains(query) ?? false) ||
                      (e.fieldName?.toLowerCase().contains(query) ?? false);
                }).toList();

                if (entries.isEmpty) {
                  return _buildEmpty(context);
                }
                if (filtered.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.search_off,
                    title: 'No Crops Match',
                    subtitle: 'Try a different search term.',
                  );
                }
                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    return _GlobalCropRow(
                      entry: entry,
                      onOpen: () => _selectCrop(entry),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.grass,
      title: 'No crops have been added yet',
      subtitle: 'Go to My Farms to add your first crop to a field.',
      actionLabel: 'Go to My Farms',
      onAction: widget.onGoToMyFarms,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SELECTED CROP DETAIL
  // ─────────────────────────────────────────────────────────────
  Widget _buildDetail(BuildContext context, CropEntity crop) {
    final hierarchy = ref.watch(hierarchyProvider);
    final theme = Theme.of(context);
    final farmName = hierarchy.entity?.farmName ?? '—';
    final fieldName = hierarchy.field?.fieldName ?? '—';

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: _clearSelection,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('All Crops'),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),

          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                // ── Hierarchy context ──
                _ContextHeader(
                  icon: Icons.eco,
                  color: Colors.green,
                  segments: [farmName, fieldName, crop.cropName],
                ),
                const SizedBox(height: 16),

                // ── Asset card ──
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          crop.cropName,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(label: 'Farm', value: farmName),
                        _InfoRow(label: 'Field', value: fieldName),
                        _InfoRow(label: 'Crop', value: crop.cropName),
                        if (crop.variety != null && crop.variety!.isNotEmpty)
                          _InfoRow(label: 'Type / Variant', value: crop.variety!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Actions ──
                // Record Activity opens the Activity Logs tab with the
                // selected crop context preserved (no standalone push).
                FilledButton.icon(
                  onPressed: _openActivities,
                  icon: const Icon(Icons.event_note),
                  label: const Text('Record Activity'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalCropRow extends StatelessWidget {
  final GlobalCropEntry entry;
  final VoidCallback onOpen;

  const _GlobalCropRow({required this.entry, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final crop = entry.crop;
    final farmName = entry.farmName ?? 'Unknown farm';
    final fieldName = entry.fieldName ?? 'Unknown field';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.eco, size: 22, color: Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crop.cropName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Crop: ${crop.cropName}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Farm: $farmName · Field: $fieldName',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onOpen,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Open'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final List<String> segments;

  const _ContextHeader({
    required this.icon,
    required this.color,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              segments.join('  ›  '),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
