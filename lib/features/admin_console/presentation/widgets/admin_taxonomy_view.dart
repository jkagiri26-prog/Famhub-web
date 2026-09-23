/// ============================================================
/// ADMIN CONSOLE → TAXONOMY MANAGEMENT
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/presentation/widgets/ = presentation
///
/// Canonical taxonomy administration (domains → categories → items →
/// variants). All reads/writes go through the admin taxonomy RPCs. Search,
/// status filter and pagination are server-side.
///
/// Uses the same permanent cascading-container concept as Locations: every
/// level owns a visible container; selecting a row in a container sets the
/// parent context for the container below it and deterministically clears
/// all descendant selections.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/admin_console/application/providers/admin_capability_provider.dart';
import 'package:famhub_app/features/admin_console/application/providers/admin_taxonomy_provider.dart';
import 'package:famhub_app/features/admin_console/domain/models/admin_taxonomy.dart';
import 'package:famhub_app/features/admin_console/domain/permissions/permissions.dart';
import 'package:famhub_app/features/admin_console/presentation/widgets/admin_user_list_widgets.dart';
import 'package:famhub_app/shared/widgets/states/states.dart';

String _displaySource(String? source) {
  if (source == null || source.isEmpty) return '—';
  return source[0].toUpperCase() + source.substring(1);
}

String _pluralOf(String singular) {
  final lower = singular.toLowerCase();
  if (lower.endsWith('y') && !lower.endsWith('ay') && !lower.endsWith('ey')) {
    return '${singular.substring(0, singular.length - 1)}ies';
  }
  return '${singular}s';
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

AdminTaxonomyNode _withName(AdminTaxonomyNode node, String name) =>
    AdminTaxonomyNode(
      id: node.id,
      name: name,
      isActive: node.isActive,
      source: node.source,
    );

AdminTaxonomyNode _withActive(AdminTaxonomyNode node, bool isActive) =>
    AdminTaxonomyNode(
      id: node.id,
      name: node.name,
      isActive: isActive,
      source: node.source,
    );

// ============================================================
// TAXONOMY VIEW
// ============================================================

class AdminTaxonomyView extends ConsumerStatefulWidget {
  const AdminTaxonomyView({super.key});

  @override
  ConsumerState<AdminTaxonomyView> createState() => _AdminTaxonomyViewState();
}

class _AdminTaxonomyViewState extends ConsumerState<AdminTaxonomyView> {
  AdminTaxonomyNode? _domain;
  AdminTaxonomyNode? _category;
  AdminTaxonomyNode? _item;

  @override
  Widget build(BuildContext context) {
    final view =
        ref.watch(adminCapabilityStatusProvider(AdminPermissions.taxonomyView));

    return view.when(
      data: (status) {
        if (!status.isAllowed) {
          return PermissionDeniedWidget(
            title: 'Taxonomy access denied',
            message: status.reason ??
                'You do not have permission to view taxonomy.',
          );
        }
        return _buildBody();
      },
      loading: () =>
          const LoadingStateWidget(message: 'Checking taxonomy access...'),
      error: (_, __) => const PermissionDeniedWidget(
        title: 'Taxonomy access denied',
        message: 'Taxonomy permissions are not available right now.',
      ),
    );
  }

  Widget _buildBody() {
    final manageStatus =
        ref.watch(adminCapabilityStatusProvider(AdminPermissions.taxonomyManage));
    final canManage = manageStatus.value?.isAllowed ?? false;

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        _pageHeader(),
        const SizedBox(height: 4),
        _TaxonomyContainer(
          key: const ValueKey('taxonomy:domain'),
          level: TaxonomyLevel.domain,
          title: 'Domains',
          singular: 'Domain',
          parentId: null,
          contextLabel: null,
          contextRows: const [],
          canLoad: true,
          emptyHint: null,
          showSource: false,
          manage: canManage,
          selected: _domain,
          onSelect: (node) => setState(() {
            _domain = node;
            _category = null;
            _item = null;
          }),
        ),
        _TaxonomyContainer(
          key: ValueKey('taxonomy:category:${_domain?.id}'),
          level: TaxonomyLevel.category,
          title: 'Categories',
          singular: 'Category',
          parentId: _domain?.id,
          contextLabel: _domain?.name,
          contextRows: [
            if (_domain != null) (label: 'Domain', value: _domain!.name)
          ],
          canLoad: _domain != null,
          emptyHint: 'Select a domain to view categories.',
          showSource: false,
          manage: canManage,
          selected: _category,
          onSelect: (node) => setState(() {
            _category = node;
            _item = null;
          }),
        ),
        _TaxonomyContainer(
          key: ValueKey('taxonomy:item:${_category?.id}'),
          level: TaxonomyLevel.item,
          title: 'Items',
          singular: 'Item',
          parentId: _category?.id,
          contextLabel: _itemContextLabel,
          contextRows: [
            if (_domain != null) (label: 'Domain', value: _domain!.name),
            if (_category != null) (label: 'Category', value: _category!.name),
          ],
          canLoad: _category != null,
          emptyHint: 'Select a category to view items.',
          showSource: false,
          manage: canManage,
          selected: _item,
          onSelect: (node) => setState(() {
            _item = node;
          }),
        ),
        _TaxonomyContainer(
          key: ValueKey('taxonomy:variant:${_item?.id}'),
          level: TaxonomyLevel.variant,
          title: 'Variants',
          singular: 'Variant',
          parentId: _item?.id,
          contextLabel: _variantContextLabel,
          contextRows: [
            if (_domain != null) (label: 'Domain', value: _domain!.name),
            if (_category != null) (label: 'Category', value: _category!.name),
            if (_item != null) (label: 'Item', value: _item!.name),
          ],
          canLoad: _item != null,
          emptyHint: 'Select an item to view variants.',
          showSource: true,
          manage: canManage,
          selected: null,
          onSelect: (_) {},
        ),
      ],
    );
  }

  String? get _itemContextLabel {
    if (_domain == null) return null;
    if (_category == null) return _domain!.name;
    return '${_domain!.name} / ${_category!.name}';
  }

  String? get _variantContextLabel {
    if (_domain == null) return null;
    if (_category == null) return _domain!.name;
    if (_item == null) return '${_domain!.name} / ${_category!.name}';
    return '${_domain!.name} / ${_category!.name} / ${_item!.name}';
  }

  Widget _pageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Taxonomy',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 1),
        Text(
          'Manage the platform product taxonomy: domains, categories, items '
          'and variants.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

// ============================================================
// TAXONOMY LEVEL CONTAINER
// ============================================================

class _TaxonomyContainer extends ConsumerStatefulWidget {
  final TaxonomyLevel level;
  final String title;
  final String singular;
  final String? parentId;
  final String? contextLabel;
  final List<({String label, String value})> contextRows;
  final bool canLoad;
  final String? emptyHint;
  final bool showSource;
  final bool manage;
  final AdminTaxonomyNode? selected;
  final ValueChanged<AdminTaxonomyNode?> onSelect;

  const _TaxonomyContainer({
    super.key,
    required this.level,
    required this.title,
    required this.singular,
    required this.parentId,
    required this.contextLabel,
    required this.contextRows,
    required this.canLoad,
    required this.emptyHint,
    required this.showSource,
    required this.manage,
    required this.selected,
    required this.onSelect,
  });

  @override
  ConsumerState<_TaxonomyContainer> createState() =>
      _TaxonomyContainerState();
}

class _TaxonomyContainerState extends ConsumerState<_TaxonomyContainer> {
  static const int _pageSize = 25;

  final _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';
  bool? _isActive;
  int _page = 0;

  AdminTaxonomyListKey get _key => AdminTaxonomyListKey(
        level: widget.level,
        parentId: widget.parentId,
        query: AdminTaxonomyQuery(
          search: _search,
          isActive: _isActive,
          page: _page,
          pageSize: _pageSize,
        ),
      );

  bool get _canAdd => widget.manage && widget.canLoad;

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

  Future<void> _openForm({AdminTaxonomyNode? existing}) async {
    final result = await showDialog<({String name})>(
      context: context,
      builder: (_) => _TaxonomyFormDialog(
        level: widget.level,
        singular: widget.singular,
        parentId: widget.parentId,
        contextRows: widget.contextRows,
        existing: existing,
      ),
    );
    if (result == null) return;

    ref.invalidate(adminTaxonomyListProvider(_key));

    if (existing != null && widget.selected?.id == existing.id) {
      widget.onSelect(_withName(widget.selected!, result.name));
    }
  }

  Future<void> _toggleActive(AdminTaxonomyNode node) async {
    if (node.isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Deactivate "${node.name}"?'),
          content: const Text(
            'This will make it unavailable for new taxonomy selections. '
            'Existing records are not deleted.',
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
      await ref
          .read(adminTaxonomyActionsProvider)
          .setActive(widget.level, node.id, !node.isActive);
      if (!mounted) return;
      _showSnack(node.isActive ? 'Deactivated.' : 'Activated.');
      ref.invalidate(adminTaxonomyListProvider(_key));
      if (widget.selected?.id == node.id) {
        widget.onSelect(_withActive(widget.selected!, !node.isActive));
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
    return _ContainerShell(
      title: widget.title,
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
    final enabled = widget.canLoad;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            enabled: enabled,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: _searchDecoration(
              'Search ${_pluralOf(widget.singular).toLowerCase()}...',
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
    if (!widget.canLoad) {
      return _ContainerHint(message: widget.emptyHint ?? '');
    }

    return ref.watch(adminTaxonomyListProvider(_key)).when(
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
                  'Could not load ${widget.title.toLowerCase()}.',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.invalidate(adminTaxonomyListProvider(_key)),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (page) => _list(page),
        );
  }

  Widget _list(AdminTaxonomyPage page) {
    if (page.isEmpty) {
      final message = _search.isNotEmpty
          ? 'No ${widget.title.toLowerCase()} match your search.'
          : 'No ${widget.title.toLowerCase()} found.';
      return _ContainerHint(message: message);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        return Column(
          children: [
            if (wide)
              _TaxonomyTableHeader(showSource: widget.showSource),
            for (final node in page.items)
              wide
                  ? _TaxonomyTableRow(
                      node: node,
                      showSource: widget.showSource,
                      showMenu: widget.manage,
                      selected: widget.selected?.id == node.id,
                      onTap: () => widget.onSelect(node),
                      onEdit: () => _openForm(existing: node),
                      onToggle: () => _toggleActive(node),
                    )
                  : _TaxonomyListRow(
                      node: node,
                      showSource: widget.showSource,
                      showMenu: widget.manage,
                      selected: widget.selected?.id == node.id,
                      onTap: () => widget.onSelect(node),
                      onEdit: () => _openForm(existing: node),
                      onToggle: () => _toggleActive(node),
                    ),
          ],
        );
      },
    );
  }

  Widget _footer() {
    final page = widget.canLoad
        ? ref.watch(adminTaxonomyListProvider(_key)).value
        : null;

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
        if (_canAdd)
          TextButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add, size: 18),
            label: Text('Add ${widget.singular}'),
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

class _TaxonomyTableHeader extends StatelessWidget {
  final bool showSource;

  const _TaxonomyTableHeader({required this.showSource});

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
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          if (showSource)
            Expanded(flex: 2, child: Text('SOURCE', style: style)),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _TaxonomyTableRow extends StatelessWidget {
  final AdminTaxonomyNode node;
  final bool showSource;
  final bool showMenu;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _TaxonomyTableRow({
    required this.node,
    required this.showSource,
    required this.showMenu,
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
                  node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: _ActiveBadge(isActive: node.isActive),
              ),
              if (showSource)
                Expanded(
                  flex: 2,
                  child: Text(
                    _displaySource(node.source),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              SizedBox(
                width: 44,
                child: showMenu
                    ? _RowMenu(
                        isActive: node.isActive,
                        onEdit: onEdit,
                        onToggle: onToggle,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaxonomyListRow extends StatelessWidget {
  final AdminTaxonomyNode node;
  final bool showSource;
  final bool showMenu;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _TaxonomyListRow({
    required this.node,
    required this.showSource,
    required this.showMenu,
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
                      node.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    if (showSource && node.source != null)
                      Text(
                        'Source: ${_displaySource(node.source)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ActiveBadge(isActive: node.isActive),
              if (showMenu)
                _RowMenu(
                  isActive: node.isActive,
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
  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _RowMenu({
    required this.isActive,
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
                isActive ? Icons.toggle_off_outlined : Icons.toggle_on_outlined,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(isActive ? 'Deactivate' : 'Activate'),
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

/// Context-scoped form. Only the name is editable; the parent is fixed by
/// the container the action was invoked from. The backend remains
/// authoritative for hierarchy and duplicate validation.
class _TaxonomyFormDialog extends ConsumerStatefulWidget {
  final TaxonomyLevel level;
  final String singular;
  final String? parentId;
  final List<({String label, String value})> contextRows;
  final AdminTaxonomyNode? existing;

  const _TaxonomyFormDialog({
    required this.level,
    required this.singular,
    required this.parentId,
    required this.contextRows,
    this.existing,
  });

  @override
  ConsumerState<_TaxonomyFormDialog> createState() =>
      _TaxonomyFormDialogState();
}

class _TaxonomyFormDialogState extends ConsumerState<_TaxonomyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEdit ? 'Edit ${widget.singular}' : 'Add ${widget.singular}',
      ),
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
                if (widget.contextRows.isNotEmpty) ...[
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
                        for (final row in widget.contextRows)
                          _contextRow(row.label, row.value),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText:
                        widget.level == TaxonomyLevel.variant
                            ? 'Variant name'
                            : 'Name',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Name is required'
                      : null,
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
              : Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Widget _contextRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    final name = _nameController.text.trim();
    final actions = ref.read(adminTaxonomyActionsProvider);

    // Similarity check for new variants (the backend's normalized uniqueness
    // remains the authoritative duplicate protection).
    if (widget.level == TaxonomyLevel.variant &&
        !_isEdit &&
        widget.parentId != null) {
      List<String> similar;
      try {
        similar = await actions.suggestSimilar(widget.parentId!, name);
      } catch (_) {
        similar = const [];
      }
      if (similar.isNotEmpty) {
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (_) => _SimilarVariantsDialog(names: similar),
        );
        if (proceed != true) return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await actions.update(widget.level, widget.existing!.id, name);
      } else {
        await actions.create(widget.level, name, parentId: widget.parentId);
      }
      if (!mounted) return;
      Navigator.pop(context, (name: name));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }
}

class _SimilarVariantsDialog extends StatelessWidget {
  final List<String> names;

  const _SimilarVariantsDialog({required this.names});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Similar variants already exist'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The following similar variants were found:',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          for (final name in names)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '•  $name',
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Use existing'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Create anyway'),
        ),
      ],
    );
  }
}
