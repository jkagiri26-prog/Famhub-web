/// ============================================================
/// WORKSPACE SELECTION PAGE — Choose ecosystem workspaces
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/auth/presentation/pages/ = auth page layer
///
/// ✅ Responsibilities:
///   - Present available workspaces/functional areas in FAMHUB
///   - Let user select which workspaces they want to use
///   - Multiple selection allowed (e.g., Farm Management + Marketplace)
///   - Call onContinue when user is done
///
/// ❌ Does NOT:
///   - Handle navigation
///   - Save to backend directly
/// ============================================================
library famhub_app.features.auth.presentation.pages.workspace_selection_page;

import 'package:flutter/material.dart';

/// Available workspaces the user can choose from.
/// These define which functional areas of FAMHUB the user will use.
class _WorkspaceOption {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  const _WorkspaceOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

const List<_WorkspaceOption> _availableWorkspaces = [
  _WorkspaceOption(
    id: 'farm_management',
    title: 'Farm Management',
    subtitle: 'Track crops, livestock, inventory, and operations',
    icon: Icons.agriculture_outlined,
  ),
  _WorkspaceOption(
    id: 'marketplace',
    title: 'Marketplace',
    subtitle: 'Buy and sell produce, inputs, and equipment',
    icon: Icons.store_outlined,
  ),
  _WorkspaceOption(
    id: 'finance',
    title: 'Finance',
    subtitle: 'Access loans, insurance, and financial tools',
    icon: Icons.account_balance_outlined,
  ),
  _WorkspaceOption(
    id: 'logistics',
    title: 'Logistics',
    subtitle: 'Manage transport, storage, and supply chains',
    icon: Icons.local_shipping_outlined,
  ),
  _WorkspaceOption(
    id: 'agribusiness',
    title: 'Agribusiness',
    subtitle: 'Manage business operations and enterprise analytics',
    icon: Icons.business_outlined,
  ),
  _WorkspaceOption(
    id: 'knowledge',
    title: 'Knowledge',
    subtitle: 'Agricultural guides, best practices, and training',
    icon: Icons.school_outlined,
  ),
  _WorkspaceOption(
    id: 'community',
    title: 'Community',
    subtitle: 'Connect with ecosystem participants and experts',
    icon: Icons.people_outline,
  ),
  _WorkspaceOption(
    id: 'analytics',
    title: 'Analytics',
    subtitle: 'Data analysis, reporting, and business intelligence',
    icon: Icons.analytics_outlined,
  ),
  _WorkspaceOption(
    id: 'ai_assistant',
    title: 'AI Assistant',
    subtitle: 'Intelligent recommendations and insights',
    icon: Icons.auto_awesome_outlined,
  ),
];

class WorkspaceSelectionPage extends StatefulWidget {
  /// Callback when the selected workspaces change.
  final void Function(List<String> workspaces)? onWorkspacesChanged;

  /// Callback when the user taps Continue.
  final VoidCallback onContinue;

  const WorkspaceSelectionPage({
    super.key,
    this.onWorkspacesChanged,
    required this.onContinue,
  });

  @override
  State<WorkspaceSelectionPage> createState() => _WorkspaceSelectionPageState();
}

class _WorkspaceSelectionPageState extends State<WorkspaceSelectionPage> {
  final Set<String> _selectedIds = {};

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canContinue = _selectedIds.isNotEmpty;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Scrollable Content ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Icon ──
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.dashboard_customize_outlined,
                          size: 36,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Title ──
                    Text(
                      'Select Your Workspaces',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose the areas you want to work with. '
                      'You can always add or remove workspaces later.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Workspace Options ──
                    ..._availableWorkspaces.map((workspace) {
                      final isSelected =
                          _selectedIds.contains(workspace.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _WorkspaceCard(
                          workspace: workspace,
                          isSelected: isSelected,
                          colorScheme: colorScheme,
                          theme: theme,
                          onTap: () => _toggleWorkspace(workspace.id),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // ── Bottom Bar ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: canContinue ? widget.onContinue : null,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        canContinue
                            ? 'Continue with ${_selectedIds.length} workspace${_selectedIds.length > 1 ? 's' : ''}'
                            : 'Select at least one workspace',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// WORKSPACE CARD
/// ─────────────────────────────────────────────────────────────
class _WorkspaceCard extends StatelessWidget {
  final _WorkspaceOption workspace;
  final bool isSelected;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final VoidCallback onTap;

  const _WorkspaceCard({
    required this.workspace,
    required this.isSelected,
    required this.colorScheme,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? colorScheme.primary.withValues(alpha: 0.06)
          : colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // ── Icon ──
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary.withValues(alpha: 0.12)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  workspace.icon,
                  size: 24,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),

              // ── Text Content ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workspace.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      workspace.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Checkbox ──
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? colorScheme.primary
                      : Colors.transparent,
                  border: isSelected
                      ? null
                      : Border.all(color: colorScheme.outline),
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
