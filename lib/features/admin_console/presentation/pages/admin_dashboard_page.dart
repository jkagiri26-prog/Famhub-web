import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/workspace/application/active_workspace_provider.dart';
import 'package:famhub_app/features/admin_console/application/providers/admin_capability_provider.dart';
import 'package:famhub_app/features/admin_console/application/providers/admin_drill_provider.dart';
import 'package:famhub_app/features/admin_console/domain/models/admin_capability.dart';
import 'package:famhub_app/features/admin_console/presentation/widgets/admin_capability_card_widget.dart';
import 'package:famhub_app/features/admin_console/presentation/widgets/admin_overview_dashboard.dart';
import 'package:famhub_app/features/admin_console/presentation/widgets/admin_section.dart';
import 'package:famhub_app/features/admin_console/presentation/widgets/admin_sections.dart';
import 'package:famhub_app/shared/layouts/adaptive_content_grid.dart';
import 'package:famhub_app/shared/layouts/dashboard_section_widget.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/states.dart';

/// ============================================================
/// ADMIN DASHBOARD — Workspace landing page
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/presentation/pages/ = Admin landing
///
/// The Administration workspace landing page, organised into top-level
/// domains, each with its own internal sub-tabs:
///
///   Overview | Users | Entities | Modules | Access | System
///
/// ✅ Architecture:
///   - Rendered through the existing `UnifiedDashboardHost` /
///     `ModulePageRegistry` (module key `admin_console`).
///   - Overview is the existing capability-driven dashboard.
///   - Sub-tabs reuse `AdminSectionScaffold` (single navigation pattern).
///   - Authorization stays with the existing permission runtime.
///
/// ❌ Does NOT:
///   - Create a parallel admin architecture.
///   - Show fabricated statistics or backend data.
/// ============================================================
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  static const List<String> _topTabs = [
    'Overview',
    'Users',
    'Entities',
    'Modules',
    'Access',
    'System',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(adminDashboardAccessProvider);

    return DefaultTabController(
      length: _topTabs.length,
      child: _AdminDrillBackGate(
        systemTabIndex: _topTabs.indexOf('System'),
        child: ResponsiveWrapper(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ModuleHeaderWidget(
              title: 'Administration',
              subtitle: 'Platform and organisation administration',
              trailingIcon: Icons.admin_panel_settings_outlined,
            ),
            const SizedBox(height: 8),
            const AdminSubTabBar(tabs: _topTabs),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  _AdminOverviewTab(access: access),
                  const AdminUsersSection(),
                  const AdminEntitiesSection(),
                  const AdminModulesSection(),
                  const AdminAccessSection(),
                  const AdminSystemSection(),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _AdminDrillBackGate extends ConsumerStatefulWidget {
  const _AdminDrillBackGate({
    required this.systemTabIndex,
    required this.child,
  });

  final int systemTabIndex;
  final Widget child;

  @override
  ConsumerState<_AdminDrillBackGate> createState() =>
      _AdminDrillBackGateState();
}

class _AdminDrillBackGateState extends ConsumerState<_AdminDrillBackGate> {
  TabController? _controller;
  GoRouter? _router;
  bool _clearScheduled = false;
  bool _historyReady = false;
  bool _restoringHistory = false;
  bool _historyRecordScheduled = false;
  int _historyRestoreGeneration = 0;
  int? _lastTopTab;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final TabController controller = DefaultTabController.of(context);
    if (!identical(controller, _controller)) {
      _controller?.removeListener(_onTabChanged);
      _controller = controller;
      controller.addListener(_onTabChanged);
    }
    final router = GoRouter.of(context);
    if (!identical(router, _router)) {
      _router?.routerDelegate.removeListener(_onRouterChanged);
      _router = router;
      router.routerDelegate.addListener(_onRouterChanged);
    }
    if (_historyReady) return;
    _historyReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restoreFromRoute();
    });
  }

  @override
  void dispose() {
    _historyRestoreGeneration++;
    _controller?.removeListener(_onTabChanged);
    _router?.routerDelegate.removeListener(_onRouterChanged);
    super.dispose();
  }

  void _onRouterChanged() => _restoreFromRoute();

  void _onTabChanged() {
    final TabController? controller = _controller;
    if (controller == null || controller.indexIsChanging) return;
    _scheduleBrowserHistoryRecord();
    if (controller.index == widget.systemTabIndex) return;
    if (_clearScheduled) return;
    _clearScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _clearScheduled = false;
      if (!mounted) return;
      ref.read(adminDrillProvider.notifier).clearAll();
    });
  }

  void _scheduleBrowserHistoryRecord() {
    if (!kIsWeb ||
        !_historyReady ||
        _restoringHistory ||
        _historyRecordScheduled) {
      return;
    }
    _historyRecordScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _historyRecordScheduled = false;
      if (!mounted || _restoringHistory) return;
      _writeBrowserHistory();
    });
  }

  void _writeBrowserHistory({bool replace = false}) {
    final router = _router;
    final controller = _controller;
    if (!kIsWeb ||
        !_historyReady ||
        router == null ||
        controller == null ||
        router.routerDelegate.currentConfiguration.uri.path != '/admin') {
      return;
    }
    final tabIndex = controller.index;
    if (!replace && _lastTopTab == tabIndex) return;
    final configuration = router.routerDelegate.currentConfiguration;
    final extra = updateAdminTabHistoryExtra(
      configuration.extra,
      workspaceId: ref.read(activeWorkspaceProvider).workspaceId,
      topTabIndex: tabIndex,
    );
    _lastTopTab = tabIndex;
    final uri = configuration.uri;
    if (replace) {
      Router.neglect(context, () => router.go(uri.toString(), extra: extra));
    } else {
      Router.navigate(context, () => router.go(uri.toString(), extra: extra));
    }
  }

  void _restoreFromRoute() {
    final router = _router;
    final controller = _controller;
    if (!kIsWeb ||
        !_historyReady ||
        !mounted ||
        router == null ||
        controller == null ||
        router.routerDelegate.currentConfiguration.uri.path != '/admin') {
      return;
    }
    final configuration = router.routerDelegate.currentConfiguration;
    final history = adminDrillHistoryFromExtra(configuration.extra);
    if (history['workspaceId'] !=
        ref.read(activeWorkspaceProvider).workspaceId) {
      return;
    }
    final targetTab = history['topTabIndex'] is int
        ? history['topTabIndex']! as int
        : 0;
    if (targetTab < 0 || targetTab >= AdminDashboardPage._topTabs.length) return;
    if (targetTab == controller.index) {
      _lastTopTab = targetTab;
      return;
    }
    final generation = ++_historyRestoreGeneration;
    _restoringHistory = true;
    _lastTopTab = targetTab;
    controller.animateTo(targetTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _historyRestoreGeneration) return;
      _restoringHistory = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AdminDrillState drill = ref.watch(adminDrillProvider);
    final TabController controller = DefaultTabController.of(context);
    if (kIsWeb) return widget.child;
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        final bool hasDrill = controller.index == widget.systemTabIndex &&
            drill.hasActiveDrill;
        return PopScope(
          canPop: !hasDrill,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (didPop) return;
            ref.read(adminDrillProvider.notifier).unwindActive();
          },
          child: widget.child,
        );
      },
    );
  }
}

/// ============================================================
/// OVERVIEW TAB — existing Admin Overview + capability sections
/// ============================================================
class _AdminOverviewTab extends StatelessWidget {
  final AdminDashboardAccess access;

  const _AdminOverviewTab({required this.access});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      child: _buildBody(access),
    );
  }

  Widget _buildBody(AdminDashboardAccess access) {
    if (access.isLoading) {
      return const LoadingStateWidget(
        message: 'Resolving administration access...',
      );
    }

    if (!access.isAllowed) {
      return PermissionDeniedWidget(
        title: 'Administration locked',
        message: access.reason ??
            'Administration is not available for this context.',
      );
    }

    if (!access.hasAnyCapability) {
      return const EmptyStateWidget(
        icon: Icons.verified_user_outlined,
        title: 'No administration capabilities',
        subtitle:
            'No administration capabilities are enabled for your role and '
            'organisation. Capabilities appear here once granted by the '
            'backend.',
      );
    }

    final hasPlatform = access.platformCapabilities.isNotEmpty;
    final hasEntity = access.entityCapabilities.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Admin Overview (platform control center) ──
        const AdminOverviewDashboard(),
        const SizedBox(height: 28),

        if (hasPlatform)
          _CapabilitySection(
            title: 'Platform administration',
            subtitle: 'Manage FAMHUB itself',
            capabilities: access.platformCapabilities,
          ),
        if (hasPlatform && hasEntity) const SizedBox(height: 28),
        if (hasEntity)
          _CapabilitySection(
            title: 'Organisation administration',
            subtitle: 'Manage your active organisation/entity',
            capabilities: access.entityCapabilities,
          ),
      ],
    );
  }
}

class _CapabilitySection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<AdminCapability> capabilities;

  const _CapabilitySection({
    required this.title,
    required this.subtitle,
    required this.capabilities,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardSectionWidget(
      title: title,
      subtitle: subtitle,
      padding: EdgeInsets.zero,
      children: [
        AdaptiveContentGrid(
          items: [
            for (final capability in capabilities)
              AdminCapabilityCardWidget(capability: capability),
          ],
        ),
      ],
    );
  }
}
