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
/// Hierarchy navigation uses the backend `p_parent_id` filter (no second
/// hierarchy model in Flutter).
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
  String? _parentId;
  final List<({String id, String name})> _parentChain = [];
  int _page = 0;
  bool _showFilters = false;

  AdminLocationsQuery get _query => AdminLocationsQuery(
        search: _searchController.text,
        countryId: _countryId,
        levelId: _levelId,
        parentId: _parentId,
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
      setState(() => _page = 0);
    });
  }

  void _navigateInto(AdminLocation location) {
    setState(() {
      _parentId = location.id;
      _parentChain.add((id: location.id, name: location.name));
      // Children are at the next level: drop the level filter.
      _levelId = null;
      _page = 0;
    });
  }

  void _jumpToBreadcrumb(int index) {
    setState(() {
      if (index < 0) {
        _parentChain.clear();
        _parentId = null;
      } else {
        _parentChain.removeRange(index + 1, _parentChain.length);
        _parentId = _parentChain[index].id;
      }
      _page = 0;
    });
  }

  Future<void> _openForm({AdminLocation? location}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _LocationFormDialog(location: location),
    );
    if (saved == true) {
      ref.invalidate(adminLocationsProvider);
    }
  }

  Future<void> _toggleActive(AdminLocation location) async {
    if (location.isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Deactivate location?'),
          content: Text(
            '"${location.name}" will be deactivated. The backend rejects '
            'deactivation when active children exist.',
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
      _showSnack(location.isActive
          ? 'Location deactivated.'
          : 'Location activated.');
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

    final pageAsync = ref.watch(adminLocationsProvider(_query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        _breadcrumb(),
        _toolbar(),
        const SizedBox(height: 8),
        Expanded(
          child: pageAsync.when(
            loading: () =>
                const LoadingStateWidget(message: 'Loading locations...'),
            error: (e, _) => ErrorStateWidget(
              title: 'Failed to load locations',
              message: 'Could not load locations. Please try again.',
              retryLabel: 'Retry',
              onRetry: () => ref.invalidate(adminLocationsProvider(_query)),
              detailedError: e.toString(),
            ),
            data: _buildBody,
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Locations',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        FilledButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Location'),
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

  bool get _hasActiveFilters =>
      _countryId != null || _levelId != null || _isActive != null;

  Widget _breadcrumb() {
    final segments = <Widget>[
      _breadcrumbItem('Locations', active: _parentChain.isEmpty, onTap: () => _jumpToBreadcrumb(-1)),
    ];
    for (var i = 0; i < _parentChain.length; i++) {
      segments.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2),
        child: Icon(Icons.chevron_right, size: 16, color: Colors.grey),
      ));
      final index = i;
      segments.add(_breadcrumbItem(
        _parentChain[i].name,
        active: i == _parentChain.length - 1,
        onTap: () => _jumpToBreadcrumb(index),
      ));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: segments),
      ),
    );
  }

  Widget _breadcrumbItem(String label, {required bool active, required VoidCallback onTap}) {
    return InkWell(
      onTap: active ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
    final countries = ref.watch(adminCountriesProvider).value ?? const [];
    final levels = _countryId == null
        ? const <AdminGeographyLevel>[]
        : ref.watch(adminGeographyLevelsProvider(_countryId)).value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search locations by name',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Filters',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _showFilters = !_showFilters),
              icon: Badge(
                isLabelVisible: _hasActiveFilters,
                child: const Icon(Icons.tune, size: 20),
              ),
            ),
          ],
        ),
        if (_showFilters) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _dropdown<String?>(
                value: _countryId,
                hint: 'All countries',
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All countries'),
                  ),
                  for (final country in countries)
                    DropdownMenuItem(
                      value: country.id,
                      child: Text(country.name),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _countryId = value;
                  _levelId = null;
                  _parentChain.clear();
                  _parentId = null;
                  _page = 0;
                }),
              ),
              _dropdown<String?>(
                value: _levelId,
                hint: 'All levels',
                enabled: _countryId != null && levels.isNotEmpty,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All levels')),
                  for (final level in levels)
                    DropdownMenuItem(value: level.id, child: Text(level.name)),
                ],
                onChanged: (value) => setState(() {
                  _levelId = value;
                  _parentChain.clear();
                  _parentId = null;
                  _page = 0;
                }),
              ),
              for (final option in <(String, bool?)>[
                ('All', null),
                ('Active', true),
                ('Inactive', false),
              ])
                ChoiceChip(
                  label: Text(option.$1),
                  selected: _isActive == option.$2,
                  onSelected: (_) => setState(() {
                    _isActive = option.$2;
                    _page = 0;
                  }),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _dropdown<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T> onChanged,
    bool enabled = true,
  }) {
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
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
        ),
        hint: Text(hint),
        items: enabled ? items : const [],
        onChanged: enabled ? (v) => onChanged(v as T) : null,
      ),
    );
  }

  Widget _buildBody(AdminLocationsPage page) {
    if (page.isEmpty) {
      final filtering = _searchController.text.trim().isNotEmpty ||
          _countryId != null ||
          _levelId != null ||
          _isActive != null ||
          _parentId != null;
      return EmptyStateWidget(
        icon: Icons.place_outlined,
        title: filtering ? 'No locations found' : 'No locations',
        subtitle: filtering
            ? 'No locations match your search or filters.'
            : 'No locations are available yet.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        return Column(
          children: [
            if (wide) const _LocationTableHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                itemCount: page.items.length,
                itemBuilder: (_, index) {
                  final location = page.items[index];
                  return wide
                      ? _LocationTableRow(
                          location: location,
                          onDrill: () => _navigateInto(location),
                          onEdit: () => _openForm(location: location),
                          onToggle: () => _toggleActive(location),
                        )
                      : _LocationCard(
                          location: location,
                          onDrill: () => _navigateInto(location),
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
// TABLE / CARDS
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
          Expanded(flex: 4, child: Text('NAME', style: style)),
          Expanded(flex: 2, child: Text('LEVEL', style: style)),
          Expanded(flex: 3, child: Text('PARENT', style: style)),
          Expanded(flex: 2, child: Text('CODE', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          const SizedBox(width: 120, child: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.3))),
        ],
      ),
    );
  }
}

class _LocationTableRow extends StatelessWidget {
  final AdminLocation location;
  final VoidCallback onDrill;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _LocationTableRow({
    required this.location,
    required this.onDrill,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: onDrill,
              child: Text(
                location.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Expanded(flex: 2, child: _muted(location.levelName)),
          Expanded(flex: 3, child: _muted(location.parentName)),
          Expanded(flex: 2, child: _muted(location.code?.toString())),
          Expanded(flex: 2, child: _ActiveBadge(isActive: location.isActive)),
          SizedBox(
            width: 120,
            child: _actions(location, onDrill, onEdit, onToggle),
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

class _LocationCard extends StatelessWidget {
  final AdminLocation location;
  final VoidCallback onDrill;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _LocationCard({
    required this.location,
    required this.onDrill,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onDrill,
                  child: Text(
                    location.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ActiveBadge(isActive: location.isActive),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (location.levelName != null) location.levelName!,
              if (location.parentName != null) 'in ${location.parentName}',
              if (location.code != null) 'code ${location.code}',
            ].join(' · '),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          _actions(location, onDrill, onEdit, onToggle),
        ],
      ),
    );
  }
}

Widget _actions(
  AdminLocation location,
  VoidCallback onDrill,
  VoidCallback onEdit,
  VoidCallback onToggle,
) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'View children',
        iconSize: 18,
        onPressed: onDrill,
        icon: const Icon(Icons.account_tree_outlined),
      ),
      IconButton(
        tooltip: 'Edit',
        iconSize: 18,
        onPressed: onEdit,
        icon: const Icon(Icons.edit_outlined),
      ),
      IconButton(
        tooltip: location.isActive ? 'Deactivate' : 'Activate',
        iconSize: 18,
        onPressed: onToggle,
        icon: Icon(
          location.isActive
              ? Icons.toggle_on_outlined
              : Icons.toggle_off_outlined,
        ),
      ),
    ],
  );
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

  const _LocationFormDialog({this.location});

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
  String? _parentId;
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
    _countryId = location?.countryId;
    _levelId = location?.levelId;
    _parentId = location?.parentId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countries = ref.watch(adminCountriesProvider).value ?? const [];
    final levels = _countryId == null
        ? const <AdminGeographyLevel>[]
        : ref.watch(adminGeographyLevelsProvider(_countryId)).value ?? const [];

    // Parent candidates = locations at the parent level for the country.
    final parentLevelId = _parentLevelId(levels);
    final parentCandidates = (parentLevelId == null || _countryId == null)
        ? const <AdminLocation>[]
        : ref
                .watch(adminParentCandidatesProvider(
                    (countryId: _countryId, levelId: parentLevelId)))
                .value ??
            const <AdminLocation>[];

    return AlertDialog(
      title: Text(_isEdit ? 'Edit Location' : 'Add Location'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _countryId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Country'),
                  items: [
                    for (final country in countries)
                      DropdownMenuItem(
                        value: country.id,
                        child: Text(country.name),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _countryId = value;
                    _levelId = null;
                    _parentId = null;
                  }),
                  validator: (v) => v == null ? 'Country is required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _levelId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Geography Level'),
                  items: [
                    for (final level in levels)
                      DropdownMenuItem(value: level.id, child: Text(level.name)),
                  ],
                  onChanged: (value) => setState(() {
                    _levelId = value;
                    _parentId = null;
                  }),
                  validator: (v) =>
                      v == null ? 'Geography level is required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: _parentId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Parent (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None (top level)')),
                    for (final parent in parentCandidates)
                      DropdownMenuItem(
                        value: parent.id,
                        child: Text(parent.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _parentId = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Code (optional)'),
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
              : Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  String? _parentLevelId(List<AdminGeographyLevel> levels) {
    if (_levelId == null) return null;
    final selected = levels.where((l) => l.id == _levelId).toList();
    if (selected.isEmpty) return null;
    final order = selected.first.order;
    final parents = levels.where((l) => l.order == order - 1).toList();
    return parents.isEmpty ? null : parents.first.id;
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
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
          levelId: _levelId!,
          parentId: _parentId,
          countryId: _countryId!,
          code: code,
        );
      } else {
        await actions.create(
          name: _nameController.text.trim(),
          levelId: _levelId!,
          countryId: _countryId!,
          parentId: _parentId,
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
