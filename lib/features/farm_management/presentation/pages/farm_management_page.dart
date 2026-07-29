/// ============================================================
/// FARM MANAGEMENT PAGE (ORCHESTRATION LAYER)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/presentation/pages/ = page layer
///
/// ✅ Responsibilities (ONLY):
///   1. Initialize module lifecycle via bootstrap coordinator
///   2. Bootstrap providers
///   3. Load farm context
///   4. Decide which UI state to display:
///      - Loading → skeleton
///      - No farms → onboarding empty state
///      - Farms loaded → dashboard with registered widgets
///      - Error → error state with retry
///      - Offline → offline state
///   5. Render dashboard widgets through the dashboard engine
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Contain large hardcoded UI implementations
///   - Import widget implementations directly
///   - Bypass the Widget Registry
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Uses Module Bootstrap Coordinator for initialization
///   - Renders widgets exclusively through WidgetRegistry
///   - No manual KPI cards, Weather, Production, etc.
///   - Shell-compliant: no Scaffold, no AppBar
///   - Every state has a meaningful UI (loading/empty/error/offline/data)
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_registry.dart';
import 'package:famhub_app/core/composition/providers/descriptor_providers.dart';
import 'package:famhub_app/core/composition/domain/models/module_descriptor.dart';
import 'package:famhub_app/core/navigation/resize_optimizer.dart';

import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/shared/layouts/dashboard_section_widget.dart';
import 'package:famhub_app/shared/layouts/app_spacing_widget.dart';
import 'package:famhub_app/shared/widgets/module_error_boundary.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/offline_state_widget.dart';
import 'package:famhub_app/shared/demo/demo_banner_widget.dart' show ExploreBanner;

import 'package:famhub_app/features/farm_management/application/bootstrap/farm_module_bootstrap.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_selector_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_onboarding_provider.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/add_farm_page.dart';
import 'package:famhub_app/features/farm_management/presentation/widgets/farm_setup_guide_widget.dart';
import 'package:famhub_app/features/farm_management/presentation/widgets/farm_onboarding_checklist_widget.dart';
import 'package:famhub_app/features/farm_management/presentation/widgets/farm_created_success_dialog.dart';

/// ============================================================
/// FARM MANAGEMENT PAGE (PRIMARY MODULE ENTRY POINT)
/// ============================================================
///
/// Lightweight orchestration page that:
///   1. Calls bootstrapModule() on first build
///   2. Resolves farm selector state
///   3. Decides which state to render
///   4. Delegates rendering to dashboard engine
///
/// INITIALIZATION FLOW:
///   Open Module
///     ↓
///   Bootstrap Coordinator
///     ↓
///   Load Farms (auto-select default)
///     ↓
///   Resolve Farm Context
///     ↓
///   Dashboard Renderer
///     ├── Farm Selector
///     ├── Farm KPIs
///     ├── Farm Summary
///     ├── Weather
///     ├── Activities
///     ├── Production
///     ├── Stock
///     ├── Alerts
///     ├── Quick Actions
///     └── Future Widgets
/// ============================================================
class FarmManagementPage extends ConsumerStatefulWidget {
  const FarmManagementPage({super.key});

  @override
  ConsumerState<FarmManagementPage> createState() => _FarmManagementPageState();
}

class _FarmManagementPageState extends ConsumerState<FarmManagementPage> {
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _initializeModule();
  }

  /// Initialize the module through the bootstrap coordinator.
  /// This happens automatically — the module never depends on
  /// another page having called loadFarms(), initializeDashboard(),
  /// or restoreContext().
  Future<void> _initializeModule() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    // Bootstrap the entire module lifecycle
    final coordinator = ref.read(farmModuleBootstrapCoordinatorProvider);
    await coordinator.bootstrapModule();
  }

  @override
  Widget build(BuildContext context) {
    final selectorState = ref.watch(farmSelectorProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return ShellPageContent(
      title: 'Farm Management',
      subtitle: 'Manage your farms, fields, crops, and livestock',
      scrollable: true,
      child: _buildContent(context, selectorState, isAuthenticated),
    );
  }

  /// Decides the correct UI state based on the farm selector state.
  ///
  /// States:
  ///   - Loading: Animated skeleton
  ///   - Error: Error message + retry
  ///   - Empty (no farms): Onboarding + CTA
  ///   - Data (farms loaded): Dashboard with registered widgets
  Widget _buildContent(
    BuildContext context,
    FarmSelectorState selectorState,
    bool isAuthenticated,
  ) {
    // ── State 1: Loading ──
    if (selectorState.isLoading) {
      return _buildLoadingState();
    }

    // ── State 2: Error ──
    if (selectorState.errorMessage != null) {
      return _buildErrorState(context, selectorState.errorMessage!);
    }

    // ── State 3: Empty / No Farms ──
    if (selectorState.farms.isEmpty) {
      return _buildEmptyState(context, isAuthenticated);
    }

    // ── State 4: Data — Dashboard with registered widgets ──
    return _buildDashboard(context);
  }

  /// ============================================================
  /// STATE: LOADING
  /// ============================================================
  ///
  /// Animated skeleton loader that gives the user visual feedback
  /// while farms are being loaded.
  /// ============================================================
  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Skeleton row 1
          _SkeletonBlock(width: 180, height: 20),
          SizedBox(height: 16),
          _SkeletonBlock(width: double.infinity, height: 80),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SkeletonBlock(width: double.infinity, height: 100)),
              SizedBox(width: 12),
              Expanded(child: _SkeletonBlock(width: double.infinity, height: 100)),
            ],
          ),
          SizedBox(height: 12),
          _SkeletonBlock(width: double.infinity, height: 60),
        ],
      ),
    );
  }

  /// ============================================================
  /// STATE: ERROR
  /// ============================================================
  ///
  /// Error message with a retry action.
  /// ============================================================
  Widget _buildErrorState(BuildContext context, String error) {
    return ErrorStateWidget(
      title: 'Unable to Load Farms',
      message: 'We encountered a problem loading your farm data. '
          'Please check your connection and try again.',
      retryLabel: 'Retry',
      onRetry: () {
        ref.read(farmSelectorProvider.notifier).loadFarms();
      },
      detailedError: error,
    );
  }

  /// ============================================================
  /// STATE: EMPTY (No Farms)
  /// ============================================================
  ///
  /// Professional onboarding experience for users with no farms.
  ///
  /// Includes:
  ///   - Welcome message
  ///   - Create Farm button
  ///   - Demo farm preview (guest mode)
  ///   - Quick Actions
  ///   - Marketplace shortcut
  /// ============================================================
  Widget _buildEmptyState(BuildContext context, bool isAuthenticated) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),

          // ── Guest Mode Banner ──
          if (!isAuthenticated)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: ExploreBanner(
                onSignIn: () {
                  // Navigate to sign in — handled by session gate
                },
              ),
            ),

          // ── Welcome Icon ──
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.agriculture_rounded,
              size: 40,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),

          // ── Welcome Title ──
          Text(
            'Welcome to Farm Management',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // ── Welcome Subtitle ──
          Text(
            'Get started by creating your first farm. '
            'Manage fields, track crops, monitor livestock, '
            'and record all your farming activities in one place.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // ── Create Farm Button ──
          SizedBox(
            width: 240,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddFarmPage(),
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text('Create Your First Farm'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // ── Quick Start Guide ──
          _buildQuickStartSection(context, theme),

          const SizedBox(height: 24),

          // ── Marketplace Shortcut ──
          _buildMarketplaceShortcut(context, theme),
        ],
      ),
    );
  }

  Widget _buildQuickStartSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Start Guide',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _QuickStartStep(
          icon: Icons.add_circle,
          title: 'Create a Farm',
          description: 'Add your farm with name, location, and size',
          color: Colors.green,
        ),
        const SizedBox(height: 12),
        _QuickStartStep(
          icon: Icons.terrain,
          title: 'Add Fields',
          description: 'Define your farm fields and growing areas',
          color: Colors.brown,
        ),
        const SizedBox(height: 12),
        _QuickStartStep(
          icon: Icons.eco,
          title: 'Plant Crops',
          description: 'Track what you plant and when',
          color: Colors.teal,
        ),
        const SizedBox(height: 12),
        _QuickStartStep(
          icon: Icons.pets,
          title: 'Add Livestock',
          description: 'Manage your animals and their health',
          color: Colors.orange,
        ),
        const SizedBox(height: 12),
        _QuickStartStep(
          icon: Icons.edit_note,
          title: 'Record Activities',
          description: 'Log daily farming operations',
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildMarketplaceShortcut(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.06),
            theme.colorScheme.secondary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.store_rounded,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Explore the Marketplace',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Buy inputs, sell produce, and connect with other farmers',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // Navigate to marketplace
              // Context.go('/marketplace');
            },
            icon: Icon(
              Icons.arrow_forward_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  bool _successDialogShown = false;

  /// ============================================================
  /// STATE: DATA — DASHBOARD
  /// ============================================================
  ///
  /// Renders farm management dashboard widgets through the
  /// Widget Registry. Prepends onboarding widgets (setup guide,
  /// checklist) at the top when applicable.
  ///
  /// Also shows the one-time success dialog after farm creation.
  /// ============================================================
  Widget _buildDashboard(BuildContext context) {
    // Show success dialog if farm was just created (one-time)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSuccessDialogIfNeeded(context);
    });

    // Resolve farm management widget descriptors from the runtime engine
    final descriptorsAsync = ref.watch(
      moduleWidgetDescriptorsProvider('farm_management'),
    );

    return descriptorsAsync.when(
      loading: () => _buildLoadingState(),
      error: (err, _) => _buildDashboardFromRegistry(context),
      data: (descriptors) {
        if (descriptors.isEmpty) {
          return _buildDashboardFromRegistry(context);
        }
        return _buildDashboardFromDescriptors(context, descriptors);
      },
    );
  }

  /// Show the one-time success dialog if the farm was just created.
  void _showSuccessDialogIfNeeded(BuildContext context) {
    if (_successDialogShown) return;

    final onboardingState = ref.read(farmOnboardingProvider);
    final hierarchy = ref.read(hierarchyProvider);

    if (!onboardingState.showSuccessCard) return;
    if (hierarchy.entity == null || hierarchy.field == null) return;

    _successDialogShown = true;

    FarmCreatedSuccessDialog.show(
      context: context,
      farmName: hierarchy.entity!.farmName,
      fieldName: hierarchy.field!.fieldName,
      farmSize: hierarchy.entity!.size,
      onContinueSetup: () {
        // Keep the setup guide visible — user wants guided flow
        // The success card is dismissed, but setup guide stays
        ref.read(farmOnboardingProvider.notifier).dismissSuccessCard();
      },
      onGoToDashboard: () {
        // Dismiss both success card and setup guide
        ref.read(farmOnboardingProvider.notifier).dismissSuccessCard();
        ref.read(farmOnboardingProvider.notifier).dismissSetupGuide();
      },
    );
  }

  /// Build the onboarding widgets (setup guide + checklist)
  /// that appear at the top of the dashboard for new farms.
  Widget _buildOnboardingSection(BuildContext context) {
    final hierarchy = ref.watch(hierarchyProvider);

    // Only show onboarding when a farm is selected
    if (!hierarchy.hasEntity) return const SizedBox.shrink();

    return Column(
      children: [
        // ── Guided Setup Card (shown when farm has no crops/livestock) ──
        const FarmSetupGuideWidget(),

        // ── Onboarding Checklist ──
        const FarmOnboardingChecklistWidget(),
      ],
    );
  }

  /// Build dashboard using runtime descriptors (preferred path).
  Widget _buildDashboardFromDescriptors(
    BuildContext context,
    List<DashboardWidgetDescriptor> descriptors,
  ) {
    final theme = Theme.of(context);
    final breakpoint = ref.watch(breakpointProvider);
    final isMobile = breakpoint.deviceType == 'compactXs' || breakpoint.deviceType == 'mobile';

    // Resolve widgets from registry
    final widgetEntries = <_WidgetEntry>[];
    for (final desc in descriptors) {
      final builder = WidgetRegistry.resolve(desc.widgetKey);
      if (builder != null) {
        widgetEntries.add(_WidgetEntry(
          descriptor: desc,
          widget: ModuleErrorBoundary(
            moduleKey: desc.widgetKey,
            displayName: desc.displayName,
            child: builder(),
          ),
        ));
      }
    }

    // Sort by display order
    widgetEntries.sort(
      (a, b) => a.descriptor.displayOrder.compareTo(b.descriptor.displayOrder),
    );

    if (widgetEntries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.agriculture, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Dashboard widgets are being prepared',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

        // 🐛 FIXED: No SingleChildScrollView — ShellPageContent handles scrolling.
    // Just return the Column of widgets.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Guest mode banner
        if (!ref.watch(isAuthenticatedProvider))
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ExploreBanner(),
          ),

        // ── Onboarding Section (setup guide + checklist) ──
        _buildOnboardingSection(context),

        const SizedBox(height: 4),
        // Widget flow — single Column on mobile, Wrap on tablet/desktop
        if (isMobile)
          ...widgetEntries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DashboardWidgetCard(
              descriptor: entry.descriptor,
              child: entry.widget,
            ),
          ))
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: widgetEntries.map((entry) {
              final width = breakpoint.deviceType == 'tablet'
                  ? (MediaQuery.of(context).size.width - 44) / 2
                  : (MediaQuery.of(context).size.width - 56) / 3;
              return SizedBox(
                width: width,
                child: _DashboardWidgetCard(
                  descriptor: entry.descriptor,
                  child: entry.widget,
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Fallback: Build dashboard directly from WidgetRegistry
  Widget _buildDashboardFromRegistry(BuildContext context) {
    final farmWidgetKeys = <String>[
      'farm_lifecycle_stage',
      'farm_farm_selector',
      'farm_recommendations',
      'farm_kpis',
      'farm_summary',
      'farm_activity_timeline',
      'farm_production_summary',
      'farm_alerts',
      'farm_stock_summary',
      'farm_livestock',
      'farm_weather',
      'farm_quick_actions',
    ];

    final resolvedWidgets = <Widget>[];
    for (final key in farmWidgetKeys) {
      final builder = WidgetRegistry.resolve(key);
      if (builder != null) {
        resolvedWidgets.add(builder());
      }
    }

    if (resolvedWidgets.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.agriculture,
        title: 'Farm Dashboard',
        subtitle: 'Farm management widgets are not available. '
            'Please check your connection and try again.',
      );
    }

    final breakpoint = ref.watch(breakpointProvider);
    final isMobile = breakpoint.deviceType == 'compactXs' || breakpoint.deviceType == 'mobile';

    // 🐛 FIXED: No SingleChildScrollView — ShellPageContent handles scrolling.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Guest mode banner
        if (!ref.watch(isAuthenticatedProvider))
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ExploreBanner(),
          ),

        // ── Onboarding Section (setup guide + checklist) ──
        _buildOnboardingSection(context),

        const SizedBox(height: 4),
        if (isMobile)
          ...resolvedWidgets.map((w) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DashboardWidgetCardFallback(child: w),
          ))
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: resolvedWidgets.map((w) {
              final width = breakpoint.deviceType == 'tablet'
                  ? (MediaQuery.of(context).size.width - 44) / 2
                  : (MediaQuery.of(context).size.width - 56) / 3;
              return SizedBox(
                width: width,
                child: _DashboardWidgetCardFallback(child: w),
              );
            }).toList(),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// ============================================================
/// DASHBOARD WIDGET CARD WRAPPER (DESCRIPTOR-BASED)
/// ============================================================
class _DashboardWidgetCard extends StatelessWidget {
  final DashboardWidgetDescriptor descriptor;
  final Widget child;

  const _DashboardWidgetCard({
    required this.descriptor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// ============================================================
/// DASHBOARD WIDGET CARD WRAPPER (FALLBACK)
/// ============================================================
class _DashboardWidgetCardFallback extends StatelessWidget {
  final Widget child;

  const _DashboardWidgetCardFallback({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// ============================================================
/// SKELETON LOADING BLOCK
/// ============================================================
class _SkeletonBlock extends StatelessWidget {
  final double width;
  final double height;

  const _SkeletonBlock({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// ============================================================
/// QUICK START STEP TILE
/// ============================================================
class _QuickStartStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _QuickStartStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// INTERNAL DATA MODEL
/// ============================================================
class _WidgetEntry {
  final DashboardWidgetDescriptor descriptor;
  final Widget widget;

  const _WidgetEntry({
    required this.descriptor,
    required this.widget,
  });
}

/// @deprecated Use [FarmManagementPage] instead.
typedef FarmDashboardPage = FarmManagementPage;
