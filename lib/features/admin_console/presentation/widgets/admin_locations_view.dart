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
/// The screen is a permanent vertical hierarchy of level containers
/// derived from `core.geography_levels` (ordered by `level_order`):
///
///   Country (active-country selector)
///      ↓
///   Counties in that country
///      ↓
///   Sub-counties in the selected county
///      ↓
///   Wards in the selected sub-county
///
/// Every container is always rendered. Selecting a row in a container
/// sets the parent context for the container below it; changing a
/// selection deterministically clears all descendant selections.
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

// ============================================================
// SHARED HELPERS
// ============================================================

List<AdminGeographyLevel> _sortedLevels(List<AdminGeographyLevel> levels) {
  final copy = [...levels];
  copy.sort((a, b) => a.order.compareTo(b.order));
  return copy;
}

/// The level that represents the country itself (e.g. "Country "). This
/// is represented by the active-country selector, so it is not rendered
/// as a separate management container.
bool _isCountryLevel(AdminGeographyLevel level) {
  final name = level.name.trim().toLowerCase();
  return name == 'country' || name == 'countries';
}

String _levelName(AdminGeographyLevel level) => level.name.trim();

String _plural(String name) {
  final trimmed = name.trim();
  final lower = trimmed.toLowerCase();
  final endsConsonantY = lower.endsWith('y') &&
      !lower.endsWith('ay') &&
      !lower.endsWith('ey') &&
      !lower.endsWith('oy') &&
      !lower.endsWith('uy');
  if (endsConsonantY) {
    return '${trimmed.substring(0, trimmed.length - 1)}ies';
  }
  return '${trimmed}s';
}

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

AdminLocation _withLocationFields(
  AdminLocation location, {
  String? name,
  int? code,
  bool? isActive,
}) {
  return AdminLocation(
    id: location.id,
    name: name ?? location.name,
    levelId: location.levelId,
    levelName: location.levelName,
    parentId: location.parentId,
    parentName: location.parentName,
    countryId: location.countryId,
    countryName: location.countryName,
    code: code ?? location.code,
    isActive: isActive ?? location.isActive,
    createdAt: location.createdAt,
    updatedAt: location.updatedAt,
  );
}

// ============================================================
// LOCATIONS VIEW
// ============================================================

class AdminLocationsView extends ConsumerStatefulWidget {
  const AdminLocationsView({super.key});

  @override
  ConsumerState<AdminLocationsView> createState() => _AdminLocationsViewState();
}

class _AdminLocationsViewState extends ConsumerState<AdminLocationsView> {
  String? _countryId;

  /// levelId → the location selected in that container.
  final Map<String, AdminLocation> _selected = {};

  void _onCountrySelected(AdminCountry country) {
    setState(() {
      _countryId = country.id;
      // Changing the active country invalidates the whole hierarchy below.
      _selected.clear();
    });
  }

  void _onLevelSelected(AdminGeographyLevel level, AdminLocation? location) {
    setState(() {
      if (location == null) {
        _selected.remove(level.id);
      } else {
        _selected[level.id] = location;
      }
      // Deterministically clear every deeper selection.
      final allLevels =
          ref.read(adminGeographyLevelsProvider(_countryId)).value ??
              const <AdminGeographyLevel>[];
      for (final candidate in allLevels) {
        if (candidate.order > level.order) _selected.remove(candidate.id);
      }
    });
  }

  AdminCountry? _countryById(List<AdminCountry> countries, String? id) {
    if (id == null) return null;
    for (final country in countries) {
      if (country.id == id) return country;
    }
    return null;
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
    final sortedLevels = _sortedLevels(levels);
    final country = _countryById(countries, _countryId);
    final hasCountryLevel =
        sortedLevels.isNotEmpty && _isCountryLevel(sortedLevels.first);
    final manageLevels =
        hasCountryLevel ? sortedLevels.sublist(1) : sortedLevels;
    final countryLevel = hasCountryLevel ? sortedLevels.first : null;

    // Resolve the country-level location (e.g. the KENYA row) which is the
    // implicit parent of the first management level.
    final countryLocationAsync =
        (countryLevel != null && _countryId != null)
            ? ref.watch(adminParentCandidatesProvider((
                countryId: _countryId,
                levelId: countryLevel.id,
                parentId: null,
              )))
            : null;
    final countryLocation = (countryLocationAsync?.value?.isNotEmpty ?? false)
        ? countryLocationAsync!.value!.first
        : null;
    final countryLocationLoading = countryLocationAsync?.isLoading ?? false;

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        _pageHeader(),
        const SizedBox(height: 6),
        _CountryContainer(
          countries: countries,
          selectedId: _countryId,
          onSelect: _onCountrySelected,
        ),
        for (var i = 0; i < manageLevels.length; i++)
          _buildLevelContainer(
            manageLevels: manageLevels,
            index: i,
            country: country,
            countryLocation: countryLocation,
            countryLocationLoading: countryLocationLoading,
            hasCountryLevel: hasCountryLevel,
          ),
      ],
    );
  }

  Widget _buildLevelContainer({
    required List<AdminGeographyLevel> manageLevels,
    required int index,
    required AdminCountry? country,
    required AdminLocation? countryLocation,
    required bool countryLocationLoading,
    required bool hasCountryLevel,
  }) {
    final level = manageLevels[index];
    final isFirst = index == 0;
    final previousLevel = isFirst ? null : manageLevels[index - 1];
    final parent =
        isFirst ? countryLocation : _selected[previousLevel!.id];
    final contextLabel = isFirst
        ? (country != null ? 'Country: ${country.name}' : null)
        : (parent != null ? 'Parent: ${parent.name}' : null);

    return _LocationLevelContainer(
      key: ValueKey(level.id),
      level: level,
      countryId: _countryId,
      countryName: country?.name,
      parent: parent,
      parentLevelName: previousLevel == null ? null : _levelName(previousLevel),
      contextLabel: contextLabel,
      parentLoading: isFirst && countryLocationLoading,
      isRootLevel: isFirst && !hasCountryLevel,
      selected: _selected[level.id],
      onSelect: (location) => _onLevelSelected(level, location),
    );
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
}

// ============================================================
// COUNTRY CONTAINER (active-country selector)
// ============================================================

class _CountryContainer extends StatefulWidget {
  final List<AdminCountry> countries;
  final String? selectedId;
  final ValueChanged<AdminCountry> onSelect;

  const _CountryContainer({
    required this.countries,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  State<_CountryContainer> createState() => _CountryContainerState();
}

class _CountryContainerState extends State<_CountryContainer> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.trim().toLowerCase();
    final visible = query.isEmpty
        ? widget.countries
        : widget.countries
            .where((c) => c.name.toLowerCase().contains(query))
            .toList();

    return _ContainerShell(
      title: 'Country',
      contextLabel: widget.selectedId == null ? null : 'Active country',
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _search = value),
          decoration: _searchDecoration('Search countries...'),
        ),
        const SizedBox(height: 6),
        if (visible.isEmpty)
          const _ContainerHint(message: 'No countries match your search.')
        else
          for (final country in visible)
            _SelectableRow(
              selected: country.id == widget.selectedId,
              onTap: () => widget.onSelect(country),
              title: country.name,
              trailingText: country.isoAlpha2,
            ),
      ],
    );
  }
}

// ============================================================
// LEVEL CONTAINER
// ============================================================

class _LocationLevelContainer extends ConsumerStatefulWidget {
  final AdminGeographyLevel level;
  final String? countryId;
  final String? countryName;
  final AdminLocation? parent;
  final String? parentLevelName;
  final String? contextLabel;
  final bool parentLoading;
  final bool isRootLevel;
  final AdminLocation? selected;
  final ValueChanged<AdminLocation?> onSelect;

  const _LocationLevelContainer({
    super.key,
    required this.level,
    required this.countryId,
    required this.countryName,
    required this.parent,
    required this.parentLevelName,
    required this.contextLabel,
    required this.parentLoading,
    required this.isRootLevel,
    required this.selected,
    required this.onSelect,
  });

  @override
  ConsumerState<_LocationLevelContainer> createState() =>
      _LocationLevelContainerState();
}

class _LocationLevelContainerState
    extends ConsumerState<_LocationLevelContainer> {
  static const int _pageSize = 25;

  final _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';
  bool? _isActive;
  int _page = 0;

  bool get _canLoad => widget.parent != null || widget.isRootLevel;

  AdminLocationsQuery get _query => AdminLocationsQuery(
        search: _search,
        countryId: widget.countryId,
        levelId: widget.level.id,
        parentId: widget.parent?.id,
        isActive: _isActive,
        page: _page,
        pageSize: _pageSize,
      );

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
      setState(() {
        _search = _searchController.text.trim();
        _page = 0;
      });
    });
  }

  Future<void> _openForm({AdminLocation? location}) async {
    final result = await showDialog<({String name, int? code})>(
      context: context,
      builder: (_) => _LocationFormDialog(
        level: widget.level,
        parent: widget.parent,
        countryId: widget.countryId,
        countryName: widget.countryName,
        location: location,
      ),
    );
    if (result == null) return;

    ref.invalidate(adminLocationsProvider);
    ref.invalidate(adminParentCandidatesProvider);

    if (location != null && widget.selected?.id == location.id) {
      widget.onSelect(
        _withLocationFields(
          widget.selected!,
          name: result.name,
          code: result.code,
        ),
      );
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
      if (widget.selected?.id == location.id) {
        widget.onSelect(
          _withLocationFields(widget.selected!, isActive: !location.isActive),
        );
      }
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
    final title = _plural(_levelName(widget.level));

    return _ContainerShell(
      title: title,
      contextLabel: widget.contextLabel,
      children: [
        _filters(),
        const SizedBox(height: 4),
        _body(),
        _footer(),
      ],
    );
  }

  Widget _filters() {
    final enabled = _canLoad;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            enabled: enabled,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: _searchDecoration(
              'Search ${_plural(_levelName(widget.level)).toLowerCase()}...',
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 124,
          child: DropdownButtonFormField<bool?>(
            value: _isActive,
            isExpanded: true,
            isDense: true,
            decoration: const InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('All')),
              DropdownMenuItem(value: true, child: Text('Active')),
              DropdownMenuItem(value: false, child: Text('Inactive')),
            ],
            onChanged: enabled
                ? (value) => setState(() {
                      _isActive = value;
                      _page = 0;
                    })
                : null,
          ),
        ),
      ],
    );
  }

  Widget _body() {
    if (widget.parentLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!_canLoad) {
      return _contextHint();
    }

    return ref.watch(adminLocationsProvider(_query)).when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not load ${_plural(_levelName(widget.level)).toLowerCase()}.',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.invalidate(adminLocationsProvider(_query)),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (page) => _list(page),
        );
  }

  Widget _contextHint() {
    final title = _plural(_levelName(widget.level)).toLowerCase();
    final message = widget.parentLevelName == null
        ? 'Select a country above to view its $title.'
        : 'Select a ${widget.parentLevelName!.toLowerCase()} above to view its $title.';
    return _ContainerHint(message: message);
  }

  Widget _emptyState() {
    final title = _plural(_levelName(widget.level)).toLowerCase();
    if (_search.isNotEmpty) {
      return const _ContainerHint(message: 'No locations match your search.');
    }
    final label = widget.parent?.name ?? widget.countryName;
    final status = _isActive == null
        ? ''
        : (_isActive! ? 'active ' : 'inactive ');
    return _ContainerHint(
      message: label == null
          ? 'No $status$title are available.'
          : 'No $status$title found in $label.',
    );
  }

  Widget _list(AdminLocationsPage page) {
    if (page.isEmpty) return _emptyState();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        return Column(
          children: [
            if (wide) const _LocationTableHeader(),
            for (final location in page.items)
              wide
                  ? _LocationTableRow(
                      location: location,
                      selected: widget.selected?.id == location.id,
                      onTap: () => widget.onSelect(location),
                      onEdit: () => _openForm(location: location),
                      onToggle: () => _toggleActive(location),
                    )
                  : _LocationListRow(
                      location: location,
                      selected: widget.selected?.id == location.id,
                      onTap: () => widget.onSelect(location),
                      onEdit: () => _openForm(location: location),
                      onToggle: () => _toggleActive(location),
                    ),
          ],
        );
      },
    );
  }

  Widget _footer() {
    final showAdd = _canLoad || widget.isRootLevel;
    final page = _canLoad ? ref.watch(adminLocationsProvider(_query)).value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (page != null && page.items.isNotEmpty)
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
        if (showAdd)
          TextButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add, size: 18),
            label: Text('Add ${_levelName(widget.level)}'),
          ),
      ],
    );
  }
}

// ============================================================
// CONTAINER CHROME
// ============================================================

class _ContainerShell extends StatelessWidget {
  final String title;
  final String? contextLabel;
  final List<Widget> children;

  const _ContainerShell({
    required this.title,
    required this.contextLabel,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
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
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: primary,
                ),
              ),
              if (contextLabel != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    contextLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _ContainerHint extends StatelessWidget {
  final String message;

  const _ContainerHint({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
      child: Text(
        message,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
    );
  }
}

// ============================================================
// ROWS
// ============================================================

/// Simple selectable row used by the Country container.
class _SelectableRow extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String? trailingText;

  const _SelectableRow({
    required this.selected,
    required this.onTap,
    required this.title,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? primary.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: selected
                    ? Icon(Icons.check_circle, size: 16, color: primary)
                    : null,
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (trailingText != null)
                Text(
                  trailingText!,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
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
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _LocationTableRow({
    required this.location,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? primary.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: selected
                    ? Icon(Icons.check_circle, size: 16, color: primary)
                    : null,
              ),
              Expanded(
                flex: 5,
                child: Text(
                  location.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
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
        ),
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
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _LocationListRow({
    required this.location,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? primary.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: selected
                    ? Icon(Icons.check_circle, size: 16, color: primary)
                    : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      location.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    if (location.code != null)
                      Text(
                        'Code ${location.code}',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
        ),
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

/// Context-scoped form. Level and parent are fixed by the container the
/// action was invoked from; only Name and Code are editable. The backend
/// remains authoritative for hierarchy validation.
class _LocationFormDialog extends ConsumerStatefulWidget {
  final AdminGeographyLevel level;
  final AdminLocation? parent;
  final String? countryId;
  final String? countryName;
  final AdminLocation? location;

  const _LocationFormDialog({
    required this.level,
    required this.parent,
    required this.countryId,
    required this.countryName,
    this.location,
  });

  @override
  ConsumerState<_LocationFormDialog> createState() =>
      _LocationFormDialogState();
}

class _LocationFormDialogState extends ConsumerState<_LocationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.location != null;

  String? get _effectiveCountryId =>
      widget.parent?.countryId ?? widget.countryId;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.location?.name ?? '');
    _codeController = TextEditingController(
      text: widget.location?.code?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final levelName = _levelName(widget.level);
    final parentLabel = widget.parent?.name ?? 'Top-level';

    return AlertDialog(
      title: Text(_isEdit ? 'Edit $levelName' : 'Add $levelName'),
      content: SizedBox(
        width: 400,
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
                      style:
                          TextStyle(fontSize: 12, color: Colors.red.shade700),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _contextRow('Country',
                          widget.parent?.countryName ?? widget.countryName),
                      const SizedBox(height: 2),
                      _contextRow('Level', levelName),
                      const SizedBox(height: 2),
                      _contextRow('Parent', parentLabel),
                    ],
                  ),
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
          onPressed: _saving ? null : () => Navigator.pop(context),
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
              : Text(_isEdit ? 'Save' : 'Create $levelName'),
        ),
      ],
    );
  }

  Widget _contextRow(String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            (value == null || value.isEmpty) ? '—' : value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    final name = _nameController.text.trim();
    final codeText = _codeController.text.trim();
    final code = codeText.isEmpty ? null : int.tryParse(codeText);
    final actions = ref.read(adminLocationsActionsProvider);

    final countryId =
        widget.location?.countryId ?? _effectiveCountryId;
    if (countryId == null || countryId.isEmpty) {
      setState(() => _error = 'A country is required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await actions.update(
          locationId: widget.location!.id,
          name: name,
          levelId: widget.location!.levelId ?? widget.level.id,
          parentId: widget.location!.parentId,
          countryId: countryId,
          code: code,
        );
      } else {
        await actions.create(
          name: name,
          levelId: widget.level.id,
          countryId: countryId,
          parentId: widget.parent?.id,
          code: code,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, (name: name, code: code));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }
}
