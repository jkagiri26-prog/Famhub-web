/// ============================================================
/// FLOATING ACTION BUTTON HOST (ENTERPRISE PHASE 9)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/presentation/renderer/ = FAB host
///
/// ✅ Responsibilities:
///   - Renders FABs from FloatingActionButtonDescriptors
///   - Each module contributes its own FABs
///   - FABs are screen-aware (appear only on their target screen)
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - FAB contributions from each module's descriptor
///   - No hardcoded FAB lists
///   - Screen-scoped visibility
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/composition/contributions/contribution_models.dart';
import 'package:famhub_app/core/composition/contributions/runtime_contribution_engine.dart';
import 'package:famhub_app/core/composition/providers/composition_providers.dart';
import 'package:famhub_app/shared/utils/icon_resolver.dart';

/// ============================================================
/// FLOATING ACTION BUTTON PROVIDER
/// ============================================================
final floatingActionButtonsProvider = FutureProvider.family<List<FloatingActionButtonContribution>, String?>((ref, forScreen) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  return runtimeContributionEngine.floatingActionButtons(
    enabledModules: modules,
    forScreen: forScreen,
  );
});

/// ============================================================
/// FLOATING ACTION BUTTON HOST
/// ============================================================
///
/// Renders the appropriate FABs for the current screen route.
/// Attach this to your scaffold's floatingActionButton parameter.
/// ============================================================
class FloatingActionButtonHost extends ConsumerWidget {
  /// The current route path (e.g., '/farm', '/marketplace')
  final String? currentRoute;

  const FloatingActionButtonHost({
    super.key,
    this.currentRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fabsAsync = ref.watch(floatingActionButtonsProvider(currentRoute));

    return fabsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (fabs) {
        if (fabs.isEmpty) return const SizedBox.shrink();

        // Single FAB
        if (fabs.length == 1) {
          final fab = fabs.first;
          return FloatingActionButton(
            heroTag: fab.actionKey,
            onPressed: () {},
            backgroundColor: theme.colorScheme.primary,
            child: Icon(
              IconResolver.resolve(fab.iconKey),
              color: Colors.white,
            ),
          );
        }

        // Multiple FABs → SpeedDial
        return _MultiFAB(fabs: fabs, theme: theme);
      },
    );
  }
}

/// ============================================================
/// MULTI-FAB (SPEED DIAL)
/// ============================================================
class _MultiFAB extends StatelessWidget {
  final List<FloatingActionButtonContribution> fabs;
  final ThemeData theme;

  const _MultiFAB({
    required this.fabs,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Simple: show primary and collapse others
    // Future: expand to SpeedDial
    return FloatingActionButton(
      heroTag: 'multi_fab',
      onPressed: () => _showFabMenu(context),
      backgroundColor: theme.colorScheme.primary,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  void _showFabMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: fabs.map((fab) => ListTile(
              leading: Icon(
                IconResolver.resolve(fab.iconKey),
                color: theme.colorScheme.primary,
              ),
              title: Text(fab.label),
              onTap: () {
                Navigator.pop(ctx);
                // Handle action
              },
            )).toList(),
          ),
        ),
      ),
    );
  }
}
