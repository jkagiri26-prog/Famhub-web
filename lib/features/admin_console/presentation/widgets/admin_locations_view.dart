/// ============================================================
/// ADMIN CONSOLE → LOCATIONS MANAGEMENT
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/presentation/widgets/ = presentation
///
/// Canonical `core.locations` administration. All reads/writes go through
/// the admin RPCs (`admin_list_locations`, `admin_create_location`,
/// `admin_update_location`, `admin_set_location_active`). Search, filters
/// and pagination are server-side.
///
/// The hierarchy is controlled by cascading selectors:
///
///   Country → Location level → Parent levels (cascading) → filtered list
///
/// Every level below the top one is narrowed by its parent, so the
/// administrator never manages all locations as one flat collection.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/admin_console/application/providers/admin_capability_provider.dart';
import 'package:famhub_app/features/admin_console/application/providers/admin_locations_provider.dart';
import 'package:famhub_app/features/admin_console/domain/models/admin_location.dart';
import 'package:famhub_app/features/admin_console/presentation/widgets/admin_user_list_widgets.dart';
import 'package:famhub_app/shared/widgets/states/states.dart';

/// One selected ancestor in the current hierarchy chain.
typedef _ParentRef = ({String levelId, String id, String name});

// ============================================================
// SHARED LEVEL HELPERS
// ============================================================

List<AdminGeographyLevel> _sortedLevels(List<AdminGeographyLevel> levels) {
  final copy = [...levels];
  copy.sort((a, b) => a.order.compareTo(b.order));
  return copy;
}

AdminGeographyLevel? _levelById(
  List<AdminGeographyLevel> levels,
  String? id,
) {
  if (id == null) return null;
  for (final level in levels) {
    if (level.id == id) return level;
  }
  return null;
}

/// Levels above the selected one, in ascending order. These become the
/// cascading parent selectors.
List<AdminGeographyLevel> _ancestorLevels(
  List<AdminGeographyLevel> levels,
  AdminGeographyLevel? selected,
) {
  if (selected == null) return const [];
  return _sortedLevels(levels)
      .where((level) => level.order < selected.order)
      .toList();
}

String _plural(String name) {
  final lower = name.toLowerCase();
  final endsConsonantY = lower.endsWith('y') &&
      !lower.endsWith('ay') &&
      !lower.endsWith('ey') &&
      !lower.endsWith('oy') &&
      !lower.endsWith('uy');
  if (endsConsonantY) {
    return '${name.substring(0, name.length - 1)}ies';
  }
  return '${name}s';
}

_ParentRef? _chainEntry(List<_ParentRef> chain, String levelId) {
  for (final entry in chain) {
    if (entry.levelId == levelId) return entry;
  }
  return null;
}

InputDecoration _decoration(String label) => InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );

InputDecoration _searchDecoration(String hint) => InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search, size: 18),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );

// ============================================================
// LOCATIONS VIEW
// ============================================================

class AdminLocationsView extends ConsumerStatefulWidget {
  const AdminLocationsView({super.key});

  @override
  ConsumerState<AdminLocationsView> createState() => _AdminLocationsViewState();
}

class _AdminLocationsViewState extends ConsumerState<AdminLocationsView> {
  static const int _pageSize = 25;

  final _searchController = TextEditingController();
  Timer? _debounce;
  String? _countryId;
  String? _levelId;
  bool? _isActive;
  final List<_ParentRef> _chain = [];
  int _page = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _page = 0);
    });
  }

  void _onCountryChanged(String? value) {
    setState(() {
      _countryId = value;
      _levelId = null;
      _chain.clear();
      _page = 0;
    });
  }

  void _onLevelChanged(String? value, List<AdminGeographyLevel> levels) {
    setState(() {
      _levelId = value;
      final selected = _levelById(levels, value);
      _chain.removeWhere((entry) {
        final level = _levelById(levels, entry.levelId);
        return level == null || selected == null || level.order >= selected.order;
      });
      _page = 0;
    });
  }

  void _onParentChanged(
    AdminGeographyLevel level,
    AdminLocation? location,
    List<AdminGeographyLevel> levels,
  ) {
    setState(() {
      _chain.removeWhere((entry) {
        final entryLevel = _levelById(levels, entry.levelId);
        return entryLevel == null || entryLevel.order >= level.order;
      });
      if (location != null) {
        _chain.add((levelId: level.id, id: location.id, name: location.name));
      }
      _page = 0;
    });
  }

  /// The immediate parent used for the list query. Only applied when the
  /// whole ancestor chain is selected, so a stale/partial parent id is never
  /// submitted.
  String? _resolvedParentId(List<AdminGeographyLevel> ancestors) {
    if (ancestors.isEmpty) return null;
    for (final ancestor in ancestors) {
      if (_chainEntry(_chain, ancestor.id) == null) return null;
    }
    return _chainEntry(_chain, ancestors.last.id)!.id;
  }

  AdminLocationsQuery _queryFor(String? parentId) => AdminLocationsQuery(
        search: _searchController.text,
        countryId: _countryId,
        levelId: _levelId,
        parentId: parentId,
        isActive: _isActive,
        page: _page,
        pageSize: _pageSize,
      );

  Future<void> _openForm({
    AdminLocation? location,
    AdminGeographyLevel? level,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _LocationFormDialog(
        location: location,
        initialCountryId: _countryId,
        initialLevelId: level?.id ?? _levelId,
        initialChain: List.of(_chain),
      ),
    );
    if (saved == true) {
      ref.invalidate(adminLocationsProvider);
      ref.invalidate(adminParentCandidatesProvider);
    }
  }

  Future<void> _toggleActive(AdminLocation location) async {
    if (location.isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Deactivate ${location.name}?'),
          content: const Text(
            'This location will no longer be active for new selections. '
            'The backend rejects deactivation when active children exist.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    try {
      await ref.read(adminLocationsActionsProvider).setActive(
            locationId: location.id,
            isActive: !location.isActive,
          );
      if (!mounted) return;
      _showSnack(
        location.isActive ? 'Location deactivated.' : 'Location activated.',
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString());
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Base admin workspace gate only — the location RPCs enforce
    // authorization server-side (backend authoritative).
    final access = ref.watch(adminWorkspaceAccessProvider);
    if (access.isLoading) {
      return const LoadingStateWidget(message: 'Checking access...');
    }
    if (!access.isAllowed) {
      return PermissionDeniedWidget(
        title: 'Locations access denied',
        message: access.reason ??
            'You do not have permission to manage locations.',
      );
    }

    final countries =
        ref.watch(adminCountriesProvider).value ?? const <AdminCountry>[];
    final levels =
        ref.watch(adminGeographyLevelsProvider(_countryId)).value ??
            const <AdminGeographyLevel>[];

    final selectedLevel = _levelById(levels, _levelId);
    final ancestors = _ancestorLevels(levels, selectedLevel);
    final country = _countryById(countries, _countryId);
    final canQuery = _countryId != null && selectedLevel != null;
    final parentId = _resolvedParentId(ancestors);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader(),
        const SizedBox(height: 10),
        _selectors(countries, levels, selectedLevel),
        _breadcrumb(country),
        const SizedBox(height: 8),
        Expanded(
          child: canQuery
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _listHeader(selectedLevel, country),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ref
                          .watch(adminLocationsProvider(_queryFor(parentId)))
                          .when(
                            loading: () => const LoadingStateWidget(
                              message: 'Loading locations...',
                            ),
                            error: (e, _) => ErrorStateWidget(
                              title: 'Failed to load locations',
                              message:
                                  'Could not load locations. Please try again.',
                              retryLabel: 'Retry',
                              onRetry: () => ref.invalidate(
                                adminLocationsProvider(_queryFor(parentId)),
                              ),
                              detailedError: e.toString(),
                            ),
                            data: (page) =>
                                _buildList(page, selectedLevel, country),
                          ),
                    ),
                  ],
                )
              : _guidanceState(),
        ),
      ],
    );
  }

  AdminCountry? _countryById(List<AdminCountry> countries, String? id) {
    if (id == null) return null;
    for (final country in countries) {
      if (country.id == id) return country;
    }
    return null;
  }

  Widget _pageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Locations',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 1),
        Text(
          'Manage the geographic hierarchy used across FAMHUB.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _selectors(
    List<AdminCountry> countries,
    List<AdminGeographyLevel> levels,
    AdminGeographyLevel? selectedLevel,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final wide = maxWidth >= 720;
        final twoCol = !wide && maxWidth >= 360;
        final halfWidth = twoCol ? (maxWidth - 12) / 2 : maxWidth;
        final fieldWidth = wide ? 200.0 : halfWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HierarchySelectors(
              countryId: _countryId,
              levelId: _levelId,
              chain: _chain,
              countries: countries,
              levels: levels,
              fieldWidth: fieldWidth,
              onCountryChanged: _onCountryChanged,
              onLevelChanged: (value) => _onLevelChanged(value, levels),
              onParentChanged: (level, location) =>
                  _onParentChanged(level, location, levels),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: wide ? 300 : maxWidth,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: _searchDecoration(
                      'Search ${selectedLevel == null ? 'locations' : _plural(selectedLevel.name).toLowerCase()}...',
                    ),
                  ),
                ),
                SizedBox(
                  width: wide ? 160 : (twoCol ? halfWidth : maxWidth),
                  child: DropdownButtonFormField<bool?>(
                    value: _isActive,
                    isExpanded: true,
                    isDense: true,
                    decoration: _decoration('Status'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(value: true, child: Text('Active')),
                      DropdownMenuItem(value: false, child: Text('Inactive')),
                    ],
                    onChanged: (value) => setState(() {
                      _isActive = value;
                      _page = 0;
                    }),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _breadcrumb(AdminCountry? country) {
    final parts = <String>[
      'Locations',
      if (country != null) country.name,
      for (final entry in _chain) entry.name,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Text(
        parts.join('  /  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _listHeader(AdminGeographyLevel level, AdminCountry? country) {
    final label = _chain.isNotEmpty ? _chain.last.name : country?.name;
    final title = label == null
        ? _plural(level.name)
        : '${_plural(level.name)} in $label';
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        FilledButton.icon(
          onPressed: () => _openForm(level: level),
          icon: const Icon(Icons.add, size: 16),
          label: Text('Add ${level.name}'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(0, 34),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _guidanceState() {
    return const EmptyStateWidget(
      icon: Icons.public_outlined,
      title: 'Select a country and level',
      subtitle:
          'Choose a country and a location level to manage its locations.',
    );
  }

  Widget _emptyState(
    AdminGeographyLevel level,
    AdminCountry? country,
  ) {
    final search = _searchController.text.trim();
    if (search.isNotEmpty) {
      return const EmptyStateWidget(
        icon: Icons.search_off,
        title: 'No locations found',
        subtitle: 'No locations match your search.',
      );
    }

    final plural = _plural(level.name).toLowerCase();
    final label = _chain.isNotEmpty ? _chain.last.name : country?.name;
    final status = _isActive == null
        ? ''
        : (_isActive! ? 'active ' : 'inactive ');

    return EmptyStateWidget(
      icon: Icons.place_outlined,
      title: 'No $plural found',
      subtitle: label == null
          ? 'No $status$plural are available.'
          : 'No $status$plural found in $label.',
    );
  }

  Widget _buildList(
    AdminLocationsPage page,
    AdminGeographyLevel level,
    AdminCountry? country,
  ) {
    if (page.isEmpty) {
      return _emptyState(level, country);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        return Column(
          children: [
            if (wide) const _LocationTableHeader(),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(top: 2, bottom: 24),
                itemCount: page.items.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
                itemBuilder: (_, index) {
                  final location = page.items[index];
                  return wide
                      ? _LocationTableRow(
                          location: location,
                          onEdit: () => _openForm(location: location),
                          onToggle: () => _toggleActive(location),
                        )
                      : _LocationListRow(
                          location: location,
                          onEdit: () => _openForm(location: location),
                          onToggle: () => _toggleActive(location),
                        );
                },
              ),
            ),
            AdminUsersPaginationFooter(
              totalCount: page.totalCount,
              itemCount: page.items.length,
              pageIndex: _page,
              pageSize: _pageSize,
              onPrev: _page > 0 ? () => setState(() => _page--) : null,
              onNext: (_page * _pageSize + page.items.length) < page.totalCount
                  ? () => setState(() => _page++)
                  : null,
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// CASCADING HIERARCHY SELECTORS
// ============================================================

/// Renders the Country → Location level → cascading parent selectors.
/// Deeper parent selectors only appear once the level above is chosen, so
/// parent choices are always narrowed by the current hierarchy.
class _HierarchySelectors extends ConsumerWidget {
  final String? countryId;
  final String? levelId;
  final List<_ParentRef> chain;
  final List<AdminCountry> countries;
  final List<AdminGeographyLevel> levels;
  final double fieldWidth;
  final ValueChanged<String?> onCountryChanged;
  final ValueChanged<String?> onLevelChanged;
  final void Function(AdminGeographyLevel level, AdminLocation? location)
      onParentChanged;

  const _HierarchySelectors({
    required this.countryId,
    required this.levelId,
    required this.chain,
    required this.countries,
    required this.levels,
    required this.fieldWidth,
    required this.onCountryChanged,
    required this.onLevelChanged,
    required this.onParentChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = _levelById(levels, levelId);
    final ancestors = _ancestorLevels(levels, selected);

    final fields = <Widget>[_countryField(), _levelField()];
    for (final ancestor in ancestors) {
      fields.add(_parentField(ref, ancestor));
      // Progressive disclosure: don't offer a deeper parent until the
      // current one is chosen.
      if (_chainEntry(chain, ancestor.id) == null) break;
    }

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        for (final field in fields)
          SizedBox(width: fieldWidth, child: field),
      ],
    );
  }

  Widget _countryField() {
    final value = countries.any((c) => c.id == countryId) ? countryId : null;
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      isDense: true,
      decoration: _decoration('Country'),
      hint: const Text('Select country'),
      items: [
        for (final country in countries)
          DropdownMenuItem(
            value: country.id,
            child: Text(country.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onCountryChanged,
    );
  }

  Widget _levelField() {
    final value = _levelById(levels, levelId) != null ? levelId : null;
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      isDense: true,
      decoration: _decoration('Location level'),
      hint: const Text('Select level'),
      items: [
        for (final level in _sortedLevels(levels))
          DropdownMenuItem(value: level.id, child: Text(level.name)),
      ],
      onChanged: countryId == null ? null : onLevelChanged,
    );
  }

  Widget _parentField(WidgetRef ref, AdminGeographyLevel level) {
    final parentFilter = _parentFilterFor(level);
    final candidates = ref
            .watch(adminParentCandidatesProvider((
              countryId: countryId,
              levelId: level.id,
              parentId: parentFilter,
            )))
            .value ??
        const <AdminLocation>[];
    final selectedId = _chainEntry(chain, level.id)?.id;
    final hasSelected =
        selectedId != null && candidates.any((c) => c.id == selectedId);

    return DropdownButtonFormField<String?>(
      value: hasSelected ? selectedId : null,
      isExpanded: true,
      isDense: true,
      decoration: _decoration(level.name),
      hint: Text('All ${_plural(level.name).toLowerCase()}'),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text('All ${_plural(level.name).toLowerCase()}'),
        ),
        for (final candidate in candidates)
          DropdownMenuItem(
            value: candidate.id,
            child: Text(candidate.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) {
        final location = value == null
            ? null
            : candidates.firstWhere((c) => c.id == value);
        onParentChanged(level, location);
      },
    );
  }

  /// The selected parent of the level immediately above [level], used to
  /// constrain its candidate list.
  String? _parentFilterFor(AdminGeographyLevel level) {
    AdminGeographyLevel? previous;
    for (final candidate in _sortedLevels(levels)) {
      if (candidate.order >= level.order) break;
      previous = candidate;
    }
    return previous == null
        ? null
        : _chainEntry(chain, previous.id)?.id;
  }
}

// ============================================================
// LIST / TABLE
// ============================================================

class _LocationTableHeader extends StatelessWidget {
  const _LocationTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Colors.grey.shade600,
      letterSpacing: 0.3,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text('NAME', style: style)),
          Expanded(flex: 2, child: Text('CODE', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _LocationTableRow extends StatelessWidget {
  final AdminLocation location;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _LocationTableRow({
    required this.location,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              location.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(flex: 2, child: _muted(location.code?.toString())),
          Expanded(
            flex: 2,
            child: _ActiveBadge(isActive: location.isActive),
          ),
          SizedBox(
            width: 44,
            child: _RowMenu(
              location: location,
              onEdit: onEdit,
              onToggle: onToggle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _muted(String? value) => Text(
        (value == null || value.isEmpty) ? '—' : value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
      );
}

/// Compact list row for narrow/mobile layouts. Not a card: one tight row
/// per location so many can be scanned quickly.
class _LocationListRow extends StatelessWidget {
  final AdminLocation location;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _LocationListRow({
    required this.location,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  location.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (location.code != null)
                  Text(
                    'Code ${location.code}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ActiveBadge(isActive: location.isActive),
          _RowMenu(
            location: location,
            onEdit: onEdit,
            onToggle: onToggle,
          ),
        ],
      ),
    );
  }
}

class _RowMenu extends StatelessWidget {
  final AdminLocation location;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _RowMenu({
    required this.location,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert, size: 20),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'toggle') onToggle();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 10),
              Text('Edit'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: Row(
            children: [
              Icon(
                location.isActive
                    ? Icons.toggle_off_outlined
                    : Icons.toggle_on_outlined,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(location.isActive ? 'Deactivate' : 'Activate'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  final bool isActive;

  const _ActiveBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.green : Colors.grey;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isActive ? 'Active' : 'Inactive',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ADD / EDIT FORM
// ============================================================

class _LocationFormDialog extends ConsumerStatefulWidget {
  final AdminLocation? location;
  final String? initialCountryId;
  final String? initialLevelId;
  final List<_ParentRef> initialChain;

  const _LocationFormDialog({
    this.location,
    this.initialCountryId,
    this.initialLevelId,
    this.initialChain = const [],
  });

  @override
  ConsumerState<_LocationFormDialog> createState() =>
      _LocationFormDialogState();
}

class _LocationFormDialogState extends ConsumerState<_LocationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  String? _countryId;
  String? _levelId;
  final List<_ParentRef> _chain = [];
  bool _chainInitialized = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.location != null;

  @override
  void initState() {
    super.initState();
    final location = widget.location;
    _nameController = TextEditingController(text: location?.name ?? '');
    _codeController =
        TextEditingController(text: location?.code?.toString() ?? '');
    _countryId = location?.countryId ?? widget.initialCountryId;
    _levelId = location?.levelId ?? widget.initialLevelId;
    _chain.addAll(widget.initialChain);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onCountryChanged(String? value) {
    setState(() {
      _countryId = value;
      _levelId = null;
      _chain.clear();
    });
  }

  void _onLevelChanged(String? value, List<AdminGeographyLevel> levels) {
    setState(() {
      _levelId = value;
      final selected = _levelById(levels, value);
      _chain.removeWhere((entry) {
        final level = _levelById(levels, entry.levelId);
        return level == null ||
            selected == null ||
            level.order >= selected.order;
      });
    });
  }

  void _onParentChanged(
    AdminGeographyLevel level,
    AdminLocation? location,
    List<AdminGeographyLevel> levels,
  ) {
    setState(() {
      _chain.removeWhere((entry) {
        final entryLevel = _levelById(levels, entry.levelId);
        return entryLevel == null || entryLevel.order >= level.order;
      });
      if (location != null) {
        _chain.add((levelId: level.id, id: location.id, name: location.name));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final countries =
        ref.watch(adminCountriesProvider).value ?? const <AdminCountry>[];
    final levels =
        ref.watch(adminGeographyLevelsProvider(_countryId)).value ??
            const <AdminGeographyLevel>[];
    final selectedLevel = _levelById(levels, _levelId);
    final ancestors = _ancestorLevels(levels, selectedLevel);

    _ensureEditChain(levels, ancestors);

    final levelLabel = selectedLevel?.name ?? 'Location';

    return AlertDialog(
      title: Text(_isEdit ? 'Edit $levelLabel' : 'Add $levelLabel'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _HierarchySelectors(
                  countryId: _countryId,
                  levelId: _levelId,
                  chain: _chain,
                  countries: countries,
                  levels: levels,
                  fieldWidth: 340,
                  onCountryChanged: _onCountryChanged,
                  onLevelChanged: (value) => _onLevelChanged(value, levels),
                  onParentChanged: (level, location) =>
                      _onParentChanged(level, location, levels),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration:
                      const InputDecoration(labelText: 'Code (optional)'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'Save' : 'Create $levelLabel'),
        ),
      ],
    );
  }

  /// When editing, make sure the immediate parent reflects the location's
  /// actual parent even if the screen hierarchy did not carry it.
  void _ensureEditChain(
    List<AdminGeographyLevel> levels,
    List<AdminGeographyLevel> ancestors,
  ) {
    if (_isEdit == false || _chainInitialized || levels.isEmpty) return;
    _chainInitialized = true;
    final location = widget.location!;
    if (ancestors.isEmpty || location.parentId == null) return;
    final immediate = ancestors.last;
    _chain.removeWhere((entry) => entry.levelId == immediate.id);
    _chain.add((
      levelId: immediate.id,
      id: location.parentId!,
      name: location.parentName ?? '',
    ));
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    final levels =
        ref.read(adminGeographyLevelsProvider(_countryId)).value ??
            const <AdminGeographyLevel>[];
    final selectedLevel = _levelById(levels, _levelId);
    if (_countryId == null || selectedLevel == null) {
      setState(() => _error = 'Select a country and geography level.');
      return;
    }

    final ancestors = _ancestorLevels(levels, selectedLevel);
    for (final ancestor in ancestors) {
      if (_chainEntry(_chain, ancestor.id) == null) {
        setState(() => _error = 'Select ${ancestor.name}.');
        return;
      }
    }
    final parentId = _chain.isEmpty ? null : _chain.last.id;

    setState(() {
      _saving = true;
      _error = null;
    });

    final codeText = _codeController.text.trim();
    final code = codeText.isEmpty ? null : int.tryParse(codeText);
    final actions = ref.read(adminLocationsActionsProvider);

    try {
      if (_isEdit) {
        await actions.update(
          locationId: widget.location!.id,
          name: _nameController.text.trim(),
          levelId: selectedLevel.id,
          parentId: parentId,
          countryId: _countryId!,
          code: code,
        );
      } else {
        await actions.create(
          name: _nameController.text.trim(),
          levelId: selectedLevel.id,
          countryId: _countryId!,
          parentId: parentId,
          code: code,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }
}
