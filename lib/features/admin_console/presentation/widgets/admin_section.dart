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

import 'package:flutter/material.dart';

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
          Expanded(child: TabBarView(children: children)),
        ],
      ),
    );
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
