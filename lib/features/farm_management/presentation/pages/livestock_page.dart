import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';

import 'package:famhub_app/features/farm_management/application/providers/livestock_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/activity_creation_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/production_page.dart';
import 'package:famhub_app/features/marketplace/presentation/pages/stock_selection_page.dart';

/// Livestock tab — the user's GLOBAL livestock workspace.
///
/// Lists every livestock asset across ALL of the user's farms and fields
/// (each row shows livestock + farm + field). Selecting a livestock sets
/// the hierarchy (farm → field → asset) and shows its details INSIDE this
/// tab. From details the user can jump to the Activity Logs tab with the
/// selected livestock context preserved.
class LivestockPage extends ConsumerStatefulWidget {
  /// Switch to the Activity Logs tab (selected livestock context is in the
  /// hierarchy).
  final VoidCallback? onOpenActivities;

  /// Switch to the My Farms tab (used by the empty state).
  final VoidCallback? onGoToMyFarms;

  const LivestockPage({
    super.key,
    this.onOpenActivities,
    this.onGoToMyFarms,
  });

  @override
  ConsumerState<LivestockPage> createState() => _LivestockPageState();
}

class _LivestockPageState extends ConsumerState<LivestockPage> {
  String _query = '';

  void _clearSelection() {
    ref.read(hierarchyProvider.notifier).clearToField();
  }

  void _selectLivestock(GlobalLivestockEntry entry) {
    if (entry.farm == null || entry.field == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This livestock has no linked farm/field yet.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final notifier = ref.read(hierarchyProvider.notifier);
    notifier.selectEntity(entry.farm!);
    notifier.selectField(entry.field!);
    notifier.selectLivestock(entry.livestock);
  }

  void _openActivities() {
    widget.onOpenActivities?.call();
  }

  void _openRecordActivity() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ActivityCreationPage()),
    );
  }

  void _openProduction() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProductionRecordingPage()),
    );
  }

  void _openStock(LivestockEntity animal) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockSelectionPage(
          initialVariantId: animal.variantId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hierarchy = ref.watch(hierarchyProvider);
    final hasSelected =
        hierarchy.cropOrLivestockType == 'livestock' &&
            hierarchy.cropOrLivestock is LivestockEntity;

    if (hasSelected) {
      return _buildDetail(
          context, hierarchy.cropOrLivestock as LivestockEntity);
    }
    return _buildList(context);
  }

  // ─────────────────────────────────────────────────────────────
  // ALL LIVESTOCK LIST
  // ─────────────────────────────────────────────────────────────
  Widget _buildList(BuildContext context) {
    final livestockAsync = ref.watch(allUserLivestockProvider);
    final query = _query.trim().toLowerCase();

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Livestock',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'All your livestock across every farm',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search livestock by name, farm or field...',
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
            child: livestockAsync.when(
              loading: () => const LoadingStateWidget(useSkeleton: true),
              error: (err, _) => ErrorStateWidget(
                title: 'Could not load livestock',
                message: err.toString(),
                retryLabel: 'Retry',
                onRetry: () => ref.invalidate(allUserLivestockProvider),
              ),
              data: (entries) {
                final filtered = entries.where((e) {
                  if (query.isEmpty) return true;
                  return (e.livestock.species.toLowerCase().contains(query)) ||
                      (e.livestock.breed?.toLowerCase().contains(query) ??
                          false) ||
                      (e.farmName?.toLowerCase().contains(query) ?? false) ||
                      (e.fieldName?.toLowerCase().contains(query) ?? false);
                }).toList();

                if (entries.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.pets,
                    title: 'No livestock has been added yet',
                    subtitle:
                        'Go to My Farms to add livestock to a field.',
                    actionLabel: 'Go to My Farms',
                    onAction: widget.onGoToMyFarms,
                  );
                }
                if (filtered.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.search_off,
                    title: 'No Livestock Match',
                    subtitle: 'Try a different search term.',
                  );
                }
                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    return _GlobalLivestockRow(
                      entry: entry,
                      onOpen: () => _selectLivestock(entry),
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

  // ─────────────────────────────────────────────────────────────
  // SELECTED LIVESTOCK DETAIL
  // ─────────────────────────────────────────────────────────────
  Widget _buildDetail(BuildContext context, LivestockEntity animal) {
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
            label: const Text('All Livestock'),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),

          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                _ContextHeader(
                  icon: Icons.pets,
                  color: Colors.orange,
                  segments: [farmName, fieldName, animal.species],
                ),
                const SizedBox(height: 16),

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
                          animal.species,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(label: 'Farm', value: farmName),
                        _InfoRow(label: 'Field', value: fieldName),
                        _InfoRow(label: 'Livestock', value: animal.species),
                        if (animal.breed != null && animal.breed!.isNotEmpty)
                          _InfoRow(label: 'Breed / Variant', value: animal.breed!),
                        _InfoRow(label: 'Count', value: '${animal.count} head'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                FilledButton.icon(
                  onPressed: _openActivities,
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Activities'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _openRecordActivity,
                  icon: const Icon(Icons.event_note),
                  label: const Text('Record Activity'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _openProduction,
                  icon: const Icon(Icons.factory_outlined),
                  label: const Text('Record Production'),
                ),
                if (animal.variantId != null &&
                    animal.variantId!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _openStock(animal),
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('Sell on Marketplace'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalLivestockRow extends StatelessWidget {
  final GlobalLivestockEntry entry;
  final VoidCallback onOpen;

  const _GlobalLivestockRow({required this.entry, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final animal = entry.livestock;
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
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pets, size: 22, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      animal.species,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Livestock: ${animal.species}',
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
