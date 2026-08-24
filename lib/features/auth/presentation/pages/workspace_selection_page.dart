/// ============================================================
/// WORKSPACE SELECTION PAGE — Choose ecosystem workspaces
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/auth/presentation/pages/ = auth page layer
///
/// ✅ Responsibilities:
///   - Present available workspaces from `system.workspaces` (backend-driven)
///   - Let the user select which workspaces they want to use
///   - Multiple selection allowed
///   - Premium, responsive layout consistent with the FAMHUB login experience
///   - Loading / error / empty states
///   - Call onContinue(selectedIds) → Future<bool> so the caller can persist
///     via the select-workspaces Edge Function and surface failures here
///
/// ❌ Does NOT:
///   - Handle navigation
///   - Save to the backend directly
///   - Hardcode a workspace catalog (always from system.workspaces)
/// ============================================================
library famhub_app.features.auth.presentation.pages.workspace_selection_page;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:famhub_app/core/workspace/application/workspace_catalog_provider.dart';
import 'package:famhub_app/core/workspace/domain/workspace_catalog_item.dart';
import 'package:famhub_app/shared/utils/icon_resolver.dart';

class WorkspaceSelectionPage extends ConsumerStatefulWidget {
  /// Callback when the selected workspaces change.
  final void Function(List<String> workspaces)? onWorkspacesChanged;

  /// Called with the selected system.workspaces.id values.
  /// Must persist selections and return true on success, false on failure.
  final Future<bool> Function(List<String> workspaceIds)? onContinue;

  const WorkspaceSelectionPage({
    super.key,
    this.onWorkspacesChanged,
    this.onContinue,
  });

  @override
  ConsumerState<WorkspaceSelectionPage> createState() =>
      _WorkspaceSelectionPageState();
}

class _WorkspaceSelectionPageState
    extends ConsumerState<WorkspaceSelectionPage> {
  final Set<String> _selectedIds = {};
  bool _saving = false;
  String? _saveError;

  void _toggleWorkspace(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
    widget.onWorkspacesChanged?.call(_selectedIds.toList());
  }

  Future<void> _continue() async {
    if (_selectedIds.isEmpty || _saving) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    final ok = await widget.onContinue?.call(_selectedIds.toList()) ?? false;

    if (!mounted) return;

    if (ok) {
      // The SessionGate swaps this subtree for the dashboard; nothing
      // else to do here.
      return;
    }

    setState(() {
      _saving = false;
      _saveError =
          'We could not save your workspaces. Please check your connection and try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withValues(alpha: 0.06),
              cs.primary.withValues(alpha: 0.02),
              cs.surface,
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: 920),
                      child: _buildBody(cs, theme),
                    ),
                  ),
                ),
              ),
            ),
            _buildBottomBar(cs, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, ThemeData theme) {
    final catalog = ref.watch(workspaceCatalogProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header icon ──
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.dashboard_customize_outlined,
              size: 34,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Heading ──
        Center(
          child: Text(
            'Select Your Workspaces',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Pick the areas you work in — you can always add or '
            'remove them later.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // ── Content states ──
        ...catalog.when(
          loading: () => const [_CatalogLoading()],
          error: (err, stack) => [
            _CatalogError(
              message: 'We could not load the available workspaces.',
              onRetry: () => ref.invalidate(workspaceCatalogProvider),
            ),
          ],
          data: (value) => _buildCatalog(cs, theme, value),
        ),
      ],
    );
  }

  List<Widget> _buildCatalog(
    ColorScheme cs,
    ThemeData theme,
    List<WorkspaceCatalogItem> workspaces,
  ) {
    if (workspaces.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined,
                  size: 32, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                'No workspaces are available yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    // ── Group by category (backend-driven) ──
    final grouped = <String, List<WorkspaceCatalogItem>>{};
    for (final w in workspaces) {
      final key = w.category?.isNotEmpty == true ? w.category! : 'Workspaces';
      grouped.putIfAbsent(key, () => []).add(w);
    }

    final categories = grouped.keys.toList();
    final columnCount = _columnCount(
      MediaQuery.of(context).size.width,
    );

    final widgets = <Widget>[];
    for (final category in categories) {
      final items = grouped[category]!;
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          category,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: cs.primary,
          ),
        ),
      ));

      // Grid on wide screens, comfortable list on narrow screens.
      final cards = items
          .map((w) => _WorkspaceCard(
                workspace: w,
                isSelected: _selectedIds.contains(w.id),
                onTap: () => _toggleWorkspace(w.id),
              ))
          .toList();

      if (columnCount > 1) {
        widgets.add(GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: 116,
          ),
          children: cards,
        ));
      } else {
        widgets.add(Column(
          children: [
            for (final c in cards)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: c,
              ),
          ],
        ));
      }
      widgets.add(const SizedBox(height: 24));
    }

    if (_saveError != null) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.error.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: cs.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _saveError!,
                  style: GoogleFonts.inter(
                    color: cs.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
    }

    return widgets;
  }

  /// Column count based on available width: 1 / 2 / 3.
  int _columnCount(double width) {
    if (width >= 900) return 3;
    if (width >= 560) return 2;
    return 1;
  }

  Widget _buildBottomBar(ColorScheme cs, ThemeData theme) {
    final canContinue = _selectedIds.isNotEmpty && !_saving;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: canContinue ? _continue : null,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _selectedIds.isEmpty
                              ? 'Select at least one workspace'
                              : 'Continue with ${_selectedIds.length} workspace${_selectedIds.length > 1 ? 's' : ''}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// WORKSPACE CARD
/// ─────────────────────────────────────────────────────────────
class _WorkspaceCard extends StatelessWidget {
  final WorkspaceCatalogItem workspace;
  final bool isSelected;
  final VoidCallback onTap;

  const _WorkspaceCard({
    required this.workspace,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final icon = workspace.iconKey != null
        ? IconResolver.resolve(workspace.iconKey!)
        : Icons.workspaces_outlined;

    return Material(
      color: isSelected
          ? cs.primary.withValues(alpha: 0.06)
          : cs.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? cs.primary : cs.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Icon ──
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? cs.primary.withValues(alpha: 0.12)
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),

              // ── Text ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workspace.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? cs.primary : cs.onSurface,
                      ),
                    ),
                    if (workspace.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        workspace.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // ── Check ──
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? cs.primary : Colors.transparent,
                  border: isSelected
                      ? null
                      : Border.all(color: cs.outline),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
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

/// ─────────────────────────────────────────────────────────────
/// LOADING STATE
/// ─────────────────────────────────────────────────────────────
class _CatalogLoading extends StatelessWidget {
  const _CatalogLoading();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading workspaces…',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// ERROR STATE (with retry)
/// ─────────────────────────────────────────────────────────────
class _CatalogError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CatalogError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 36, color: cs.error),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
