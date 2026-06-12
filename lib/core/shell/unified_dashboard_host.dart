import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/providers/module_provider.dart';
import 'package:famhub_app/core/modules/domain/models/system_module.dart';
import 'package:famhub_app/system/registry/module_registry.dart';
import 'package:famhub_app/shared/utils/icon_resolver.dart';
import 'package:famhub_app/core/dashboard_engine/application/validation/dashboard_runtime_validator.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/dashboard_runtime_validator_provider.dart';
import 'package:famhub_app/core/dashboard_engine/domain/models/composition_node.dart';

/// ============================================================
/// UNIFIED DASHBOARD HOST (PRIMARY RUNTIME SHELL)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/ = OS-level shell layer
///
/// ✅ CORRECT FLOW:
///   Registry → ModuleService → moduleProvider → Dashboard UI
///
/// ✅ Responsibilities:
///   - Responsive shell layout
///   - Render dashboard regions
///   - Consume moduleProvider only
///   - Show loading/error/empty states
///   - Render module tiles dynamically
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - FULLY metadata-driven
///   - FULLY registry-driven
///   - FULLY plugin-safe
///   - NO switch statements on module IDs
///   - NO hardcoded route maps
///   - NO hardcoded descriptions
///   - NO conditional module metadata logic
///
/// ❌ Does NOT:
///   - Call Supabase directly
///   - Hardcode module lists
///   - Import registry into UI for business logic
///   - Perform access evaluation in widgets
///   - Place business logic in UI
///   - Bypass providers
///   - Know module IDs for icon/route/description resolution
/// ============================================================
class UnifiedDashboardHost extends ConsumerWidget {
  const UnifiedDashboardHost({super.key});

    @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moduleAsync = ref.watch(moduleProvider);

    return moduleAsync.when(
      loading: () => const _DashboardLoadingLayout(),
      error: (error, stack) => _DashboardErrorLayout(
        message: error.toString(),
        onRetry: () => ref.invalidate(moduleProvider),
      ),
      data: (modules) {
        final validator = ref.read(dashboardRuntimeValidatorProvider);
        final visibleModules = _filterVisibleModules(modules, validator);
        if (visibleModules.isEmpty) {
          return const _DashboardEmptyLayout();
        }
        return _DashboardModulesGrid(modules: visibleModules);
      },
    );
  }

  /// Pure filter with runtime validation.
  /// Uses SystemModule runtime fields + DashboardRuntimeValidator.
  List<SystemModule> _filterVisibleModules(
    List<SystemModule> modules,
    DashboardRuntimeValidator validator,
  ) {
    return modules
        .where((m) {
          // ── Basic runtime checks (from SystemModule) ──
          if (!m.isEnabled) return false;
          if (!m.dashboardVisible) return false;
          if (m.maintenanceMode) return false;

          // ── Structural validation (from registries) ──
          final node = CompositionNode(
            id: m.moduleKey,
            moduleKey: m.moduleKey,
            widgetKey: m.moduleKey, // module-level validation
            zone: 'dashboard',
            order: m.displayOrder,
          );

          final result = validator.validateNode(node);
          return result.isValid;
        })
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }
}

// =================================================================
// PRIVATE SUB-WIDGETS (SCOPED TO THIS FILE ONLY)
// =================================================================

/// Loading skeleton layout
class _DashboardLoadingLayout extends StatelessWidget {
  const _DashboardLoadingLayout();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header skeleton ──
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 200,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 280,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            // ── Module grid skeleton ──
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 900
                      ? 3
                      : constraints.maxWidth > 600
                          ? 2
                          : 1;

                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 1.4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return _buildSkeletonCard(theme);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 120,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 140,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const Spacer(),
            Container(
              width: 80,
              height: 10,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state layout with retry action
class _DashboardErrorLayout extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DashboardErrorLayout({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Unable to Load Modules',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state when no modules are visible
class _DashboardEmptyLayout extends StatelessWidget {
  const _DashboardEmptyLayout();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.dashboard_customize_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Modules Available',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Your dashboard is ready but no modules are currently '
              'available. Please check back later or contact support.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Responsive grid of module tiles
///
/// 🧠 FULLY METADATA-DRIVEN
/// This widget consumes SystemModule data ONLY.
/// NO switch statements, NO hardcoded maps, NO conditional logic.
/// Icon, route, description, and display name come from registry metadata.
class _DashboardModulesGrid extends StatelessWidget {
  final List<SystemModule> modules;

  const _DashboardModulesGrid({required this.modules});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 900
              ? 3
              : constraints.maxWidth > 600
                  ? 2
                  : 1;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Dashboard header ──
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${modules.length} module${modules.length == 1 ? '' : 's'} available',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Module grid ──
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 1.4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: modules.length,
                    itemBuilder: (context, index) {
                      final module = modules[index];

                      // Resolve iconKey from registry blueprint
                      final def = ModuleRegistry.byId(module.moduleKey);
                      final iconKey = def?.iconKey ?? 'widgets';
                      final iconData = IconResolver.resolve(iconKey);

                      // Resolve description from registry blueprint
                      final description =
                          def?.description ?? module.displayName;

                      // Resolve route from registry blueprint
                      final route = def?.entryRoute;

                      return _ModuleTile(
                        icon: iconData,
                        title: module.displayName,
                        description: description,
                        route: route,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Individual module tile card
///
/// 🧠 FULLY GENERIC — consumes props only, knows nothing about modules.
/// No registry references, no switch statements, no hardcoded data.
class _ModuleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? route;

  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.description,
    this.route,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: route != null ? () => _navigateToModule(context) : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Icon ──
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                // ── Title ──
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // ── Description (from registry metadata) ──
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // ── Entry indicator ──
                Row(
                  children: [
                    Text(
                      'Open',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 10,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

    void _navigateToModule(BuildContext context) {
    if (route != null) {
      context.go(route!);
    }
  }
}