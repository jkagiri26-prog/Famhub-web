/// ============================================================
/// COMMAND PALETTE (ENTERPRISE PHASE 6)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/command_palette/presentation/pages/ = command palette
///
/// ✅ Responsibilities:
///   - Ctrl+K / Cmd+K overlay for rapid navigation and actions
///   - Actions aggregated from all CommandPaletteActionDescriptors
///   - No hardcoded commands
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Commands come from descriptors of enabled modules
///   - Each module registers its own commands
///   - Supports: Go-to, Quick Action, AI commands
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/composition/contributions/contribution_models.dart';
import 'package:famhub_app/core/composition/contributions/runtime_contribution_engine.dart';
import 'package:famhub_app/core/composition/providers/composition_providers.dart';
import 'package:famhub_app/core/composition/providers/descriptor_providers.dart';
import 'package:famhub_app/shared/utils/icon_resolver.dart';

/// ============================================================
/// COMMAND PALETTE PROVIDER
/// ============================================================
final commandPaletteActionsProvider = FutureProvider<Map<String, List<CommandPaletteActionContribution>>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  return runtimeContributionEngine.commandPaletteActions(
    enabledModules: modules,
  );
});

/// ============================================================
/// COMMAND PALETTE OVERLAY
/// ============================================================
class CommandPaletteOverlay extends ConsumerStatefulWidget {
  const CommandPaletteOverlay({super.key});

  @override
  ConsumerState<CommandPaletteOverlay> createState() => _CommandPaletteOverlayState();
}

class _CommandPaletteOverlayState extends ConsumerState<CommandPaletteOverlay> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionsAsync = ref.watch(commandPaletteActionsProvider);

    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Search Input ──
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Type a command...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey.shade500),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: theme.textTheme.bodyLarge,
                ),
              ),

              const Divider(height: 1),

              // ── Results List ──
              Flexible(
                child: actionsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: Text('Error: $err')),
                  ),
                  data: (categorized) {
                    if (categorized.isEmpty) {
                      return _buildEmptyState(theme);
                    }

                    // Filter by search query
                    final filtered = <String, List<CommandPaletteActionContribution>>{};
                    for (final entry in categorized.entries) {
                      final matching = entry.value.where((action) =>
                        action.label.toLowerCase().contains(_query) ||
                        action.description.toLowerCase().contains(_query) ||
                        action.keywords.any((k) => k.contains(_query)) ||
                        action.moduleId?.toLowerCase().contains(_query) == true
                      ).toList();

                      if (matching.isNotEmpty) {
                        filtered[entry.key] = matching;
                      }
                    }

                    if (filtered.isEmpty) {
                      return _buildNoResults(theme);
                    }

                    return ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: filtered.entries.expand((entry) => [
                        // Category Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            entry.key,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        // Actions
                        ...entry.value.map((action) => _CommandItem(
                          action: action,
                          query: _query,
                          onTap: () {
                            Navigator.of(context).pop(action);
                          },
                        )),
                      ]).toList(),
                    );
                  },
                ),
              ),

              // ── Footer ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    _buildKeyHint('↑↓', 'Navigate', theme),
                    const SizedBox(width: 12),
                    _buildKeyHint('↵', 'Select', theme),
                    const SizedBox(width: 12),
                    _buildKeyHint('Esc', 'Close', theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyHint(String keys, String label, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            keys,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.terminal, size: 36, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No commands available',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text('Enable services to see their commands',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildNoResults(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 36, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No results for "$_query"',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

/// ============================================================
/// COMMAND ITEM
/// ============================================================
class _CommandItem extends StatelessWidget {
  final CommandPaletteActionContribution action;
  final String query;
  final VoidCallback onTap;

  const _CommandItem({
    required this.action,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = IconResolver.resolve(action.iconKey);

    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18, color: Colors.grey.shade600),
      title: Text(
        action.label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: action.description.isNotEmpty
          ? Text(
              action.description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          action.category,
          style: TextStyle(
            fontSize: 10,
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}
