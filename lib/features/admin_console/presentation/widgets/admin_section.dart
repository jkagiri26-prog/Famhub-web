/// ============================================================
/// ADMIN SECTION — REUSABLE SUB-TAB NAVIGATION
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/presentation/widgets/ = presentation
///
/// Reusable, compact navigation pattern shared by every Administration
/// domain so sub-tabs are implemented once (not per section):
///
///   AdminSectionScaffold : header + AdminSubTabBar + per-sub-tab body
///   AdminSubTabBar       : scrollable tab bar (mobile/tablet/desktop)
///   AdminPlaceholder     : honest planned/empty state (no fake data)
///
/// ❌ Does NOT:
///   - Contain business logic, providers or backend access.
/// ============================================================
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/workspace/application/active_workspace_provider.dart';
import 'package:famhub_app/features/admin_console/application/providers/admin_drill_provider.dart';
import 'package:famhub_app/shared/widgets/states/states.dart';

/// Compact, horizontally scrollable admin tab bar. Reused for both the
/// top-level Administration tabs and every domain's sub-tabs.
class AdminSubTabBar extends StatelessWidget {
  final List<String> tabs;

  const AdminSubTabBar({super.key, required this.tabs});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      indicatorColor: primary,
      labelColor: primary,
      unselectedLabelColor: Colors.grey.shade600,
      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      tabs: [for (final tab in tabs) Tab(height: 34, text: tab)],
    );
  }
}

/// A domain section: compact header, sub-tab bar and the body for the
/// selected sub-tab. Nested inside the top-level Administration tabs.
class AdminSectionScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> tabs;
  final List<Widget> children;

  const AdminSectionScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tabs,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    assert(
      tabs.length == children.length,
      'AdminSectionScaffold: tabs and children must have equal length',
    );

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          AdminSubTabBar(tabs: tabs),
          const Divider(height: 1),
          Expanded(
            child: _AdminSectionTabHistory(
              sectionKey: title,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}


Map<String, Object?> _stringKeyedMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

class _AdminSectionTabHistory extends ConsumerStatefulWidget {
  const _AdminSectionTabHistory({
    required this.sectionKey,
    required this.children,
  });

  final String sectionKey;
  final List<Widget> children;

  @override
  ConsumerState<_AdminSectionTabHistory> createState() =>
      _AdminSectionTabHistoryState();
}

class _AdminSectionTabHistoryState
    extends ConsumerState<_AdminSectionTabHistory> {
  TabController? _controller;
  GoRouter? _router;
  bool _historyReady = false;
  bool _restoringHistory = false;
  bool _historyRecordScheduled = false;
  int _historyRestoreGeneration = 0;
  int? _lastSectionTab;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.of(context);
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
      _restoreFromRoute(initial: true);
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
    final controller = _controller;
    if (controller == null || controller.indexIsChanging) return;
    _scheduleBrowserHistoryRecord();
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
    if (!replace && _lastSectionTab == tabIndex) return;
    final configuration = router.routerDelegate.currentConfiguration;
    final extra = updateAdminTabHistoryExtra(
      configuration.extra,
      workspaceId: ref.read(activeWorkspaceProvider).workspaceId,
      sectionKey: widget.sectionKey,
      sectionTabIndex: tabIndex,
    );
    _lastSectionTab = tabIndex;
    final uri = configuration.uri;
    if (replace) {
      Router.neglect(context, () => router.go(uri.toString(), extra: extra));
    } else {
      Router.navigate(context, () => router.go(uri.toString(), extra: extra));
    }
  }

  void _restoreFromRoute({bool initial = false}) {
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
    final sectionTabs = _stringKeyedMap(history['sectionTabs']);
    final targetTab = sectionTabs[widget.sectionKey] is int
        ? sectionTabs[widget.sectionKey]! as int
        : 0;
    if (targetTab < 0 || targetTab >= widget.children.length) return;
    if (targetTab == controller.index) {
      _lastSectionTab = targetTab;
      return;
    }
    final generation = ++_historyRestoreGeneration;
    _restoringHistory = true;
    _lastSectionTab = targetTab;
    controller.animateTo(targetTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _historyRestoreGeneration) return;
      _restoringHistory = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TabBarView(children: widget.children);
  }
}

/// Honest planned/empty state for a sub-tab whose backend source is not
/// confirmed yet. Never shows fabricated data.
class AdminPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const AdminPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 24, bottom: 80),
      child: EmptyStateWidget(
        icon: icon,
        title: title,
        subtitle: message,
      ),
    );
  }
}
