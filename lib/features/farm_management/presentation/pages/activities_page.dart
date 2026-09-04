import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';

import 'package:famhub_app/features/farm_management/application/providers/activities_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/activity_creation_page.dart';

/// Activity Logs tab — the user's GLOBAL activity journal.
///
/// By default it lists activities for ALL authorized crop/livestock assets
/// across every farm and field (newest first). When the user arrives from a
/// crop/livestock detail ("Activities"), the journal enters contextual mode
/// and shows only that asset's activities, with a breadcrumb + "View All".
class ActivitiesPage extends ConsumerStatefulWidget {
  /// Switch to the Crops tab.
  final VoidCallback? onOpenCrops;

  /// Switch to the Livestock tab.
  final VoidCallback? onOpenLivestock;

  const ActivitiesPage({
    super.key,
    this.onOpenCrops,
    this.onOpenLivestock,
  });

  @override
  ConsumerState<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends ConsumerState<ActivitiesPage> {
  /// 'all' | 'crop' | 'livestock'
  String _typeFilter = 'all';
  String? _farmFilter;

  /// Entry currently open in the in-tab detail view.
  GlobalActivityEntry? _selected;

  /// When true, ignore the contextual asset filter (user pressed View All).
  bool _showAllContext = false;

  void _openDetail(GlobalActivityEntry entry) {
    setState(() => _selected = entry);
  }

  void _backToList() {
    setState(() => _selected = null);
  }

  void _viewAllActivities() {
    setState(() => _showAllContext = true);
  }

  void _openAsset(GlobalActivityEntry entry) {
    final notifier = ref.read(hierarchyProvider.notifier);
    notifier.selectEntity(entry.farm);
    if (entry.field != null) notifier.selectField(entry.field!);
    if (entry.assetType == 'crop') {
      notifier.selectCrop(entry.asset as CropEntity);
      widget.onOpenCrops?.call();
    } else {
      notifier.selectLivestock(entry.asset as LivestockEntity);
      widget.onOpenLivestock?.call();
    }
  }

  void _recordActivity() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ActivityCreationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hierarchy = ref.watch(hierarchyProvider);
    final contextualAssetId =
        (hierarchy.cropOrLivestock != null && !_showAllContext)
            ? hierarchy.cropOrLivestockId
            : null;

    if (_selected != null) {
      return _buildDetail(context, _selected!);
    }
    return _buildJournal(context, contextualAssetId);
  }

  // ─────────────────────────────────────────────────────────────
  // GLOBAL / CONTEXTUAL JOURNAL
  // ─────────────────────────────────────────────────────────────
  Widget _buildJournal(BuildContext context, String? contextualAssetId) {
    final hierarchy = ref.watch(hierarchyProvider);
    final journalAsync = ref.watch(allUserActivitiesProvider);
    final query = _typeFilter == 'all' ? null : _typeFilter;

    final contextualEntry = contextualAssetId == null
        ? null
        : hierarchy.cropOrLivestock;

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Activity Logs',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              // Record activity uses the already-selected asset context.
              if (hierarchy.cropOrLivestock != null)
                IconButton(
                  onPressed: _recordActivity,
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Record Activity',
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'All crop & livestock activities across your farms',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),

          // ── Contextual filter header ──
          if (contextualAssetId != null) ...[
            const SizedBox(height: 10),
            _ContextBanner(
              assetLabel: contextualEntry is CropEntity
                  ? contextualEntry.cropName
                  : contextualEntry is LivestockEntity
                      ? contextualEntry.species
                      : 'Selected asset',
              onViewAll: _viewAllActivities,
            ),
          ],
          const SizedBox(height: 12),

          Expanded(
            child: journalAsync.when(
              loading: () => const LoadingStateWidget(useSkeleton: true),
              error: (err, _) => ErrorStateWidget(
                title: 'Could not load activities',
                message: 'We encountered a problem loading your activities.',
                retryLabel: 'Retry',
                onRetry: () => ref.invalidate(allUserActivitiesProvider),
              ),
              data: (entries) {
                final filtered = _applyFilters(
                    entries, contextualAssetId, query, _farmFilter);

                if (contextualAssetId != null && filtered.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.list_alt,
                    title: 'No activities found',
                    subtitle: 'No activities for this asset yet.',
                    actionLabel: 'View All Activities',
                    onAction: _viewAllActivities,
                  );
                }
                if (entries.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.history,
                    title: 'No activities recorded yet',
                    subtitle:
                        'Add your first activity from a crop or livestock asset.',
                    actionLabel: 'View Crops',
                    onAction: widget.onOpenCrops,
                  );
                }
                if (filtered.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.search_off,
                    title: 'No Activities Match',
                    subtitle: 'Try changing the filters.',
                  );
                }
                return _buildList(context, entries, filtered);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<GlobalActivityEntry> all,
    List<GlobalActivityEntry> filtered,
  ) {
    final farmNames = <String>{
      for (final e in all) e.farmName,
    }.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Filters: All | Crops | Livestock + farm ──
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                children: [
                  _filterChip('All', _typeFilter == 'all', () {
                    setState(() => _typeFilter = 'all');
                  }),
                  _filterChip('Crops', _typeFilter == 'crop', () {
                    setState(() => _typeFilter = 'crop');
                  }),
                  _filterChip('Livestock', _typeFilter == 'livestock', () {
                    setState(() => _typeFilter = 'livestock');
                  }),
                ],
              ),
            ),
            if (farmNames.length > 1)
              PopupMenuButton<String>(
                tooltip: 'Filter by farm',
                onSelected: (value) => setState(() {
                  _farmFilter = value == 'all' ? null : value;
                }),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'all',
                    child: Text('All farms'),
                  ),
                  ...farmNames
                      .map((name) => PopupMenuItem(
                            value: name,
                            child: Text(name),
                          )),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_alt_outlined,
                          size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Text(
                        _farmFilter ?? 'All farms',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = filtered[index];
              return _ActivityRow(
                entry: entry,
                onTap: () => _openDetail(entry),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    );
  }

  List<GlobalActivityEntry> _applyFilters(
    List<GlobalActivityEntry> entries,
    String? contextualAssetId,
    String? typeFilter,
    String? farmFilter,
  ) {
    return entries.where((e) {
      if (contextualAssetId != null && e.assetId != contextualAssetId) {
        return false;
      }
      if (typeFilter != null && e.assetType != typeFilter) return false;
      if (farmFilter != null && e.farmName != farmFilter) return false;
      return true;
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // ACTIVITY DETAIL (in-tab)
  // ─────────────────────────────────────────────────────────────
  Widget _buildDetail(BuildContext context, GlobalActivityEntry entry) {
    final theme = Theme.of(context);
    final activity = entry.activity;

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: _backToList,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('All Activities'),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),

          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: (entry.assetType == 'crop'
                            ? Colors.green
                            : Colors.orange)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (entry.assetType == 'crop'
                              ? Colors.green
                              : Colors.orange)
                          .withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.typeName,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.assetLabel,
                        style: TextStyle(
                            fontSize: 15, color: Colors.grey.shade800),
                      ),
                    ],
                  ),
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
                        _InfoRow(label: 'Farm', value: entry.farmName),
                        _InfoRow(
                            label: 'Field',
                            value: entry.fieldName ?? '—'),
                        _InfoRow(label: 'Asset', value: entry.assetLabel),
                        _InfoRow(
                            label: 'Performed',
                            value: _formatFull(activity.performedAt)),
                        if (activity.notes != null &&
                            activity.notes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('Notes',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600)),
                          const SizedBox(height: 2),
                          Text(
                            activity.notes!,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (entry.field != null)
                  FilledButton.icon(
                    onPressed: () => _openAsset(entry),
                    icon: Icon(
                      entry.assetType == 'crop' ? Icons.eco : Icons.pets,
                    ),
                    label: Text(entry.assetType == 'crop'
                        ? 'View Crop Details'
                        : 'View Livestock Details'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFull(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    String two(int v) => v.toString().padLeft(2, '0');
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final suffix = dt.hour < 12 ? 'AM' : 'PM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · '
        '${two(hour12)}:${two(dt.minute)} $suffix';
  }
}

class _ActivityRow extends StatelessWidget {
  final GlobalActivityEntry entry;
  final VoidCallback onTap;

  const _ActivityRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCrop = entry.assetType == 'crop';
    final color = isCrop ? Colors.green : Colors.orange;
    final activity = entry.activity;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isCrop ? Icons.eco : Icons.pets,
                      size: 20,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.typeName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.assetLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _shortDate(activity.performedAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${entry.fieldName ?? '—'} · ${entry.farmName}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (activity.notes != null && activity.notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  activity.notes!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _shortDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    String two(int v) => v.toString().padLeft(2, '0');
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final suffix = dt.hour < 12 ? 'AM' : 'PM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · '
        '${two(hour12)}:${two(dt.minute)} $suffix';
  }
}

class _ContextBanner extends StatelessWidget {
  final String assetLabel;
  final VoidCallback onViewAll;

  const _ContextBanner({
    required this.assetLabel,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              assetLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onViewAll,
            child: const Text('View All Activities'),
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
            width: 90,
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
