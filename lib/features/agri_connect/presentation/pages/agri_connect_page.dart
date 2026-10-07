/// ============================================================
/// AGRI CONNECT — MODULE ENTRY PAGE
/// ============================================================
///
/// Top-level shell for the module:
///
///   Home | Communities | Forum | Messages
///
/// Home is a public discussion feed (the dominant experience),
/// Forum is the full public discussion browser, Communities is the
/// organised group area and Messages holds conversations.
///
/// Centered on:
///   Person → Farm/Business → Community → Discussion/Chat → FAMHUB modules
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';

import '../widgets/agri_connect_tab_selector_widget.dart';
import 'communities_tab.dart';
import 'create_community_page.dart';
import 'create_discussion_page.dart';
import 'forum_tab.dart';
import 'home_tab.dart';
import 'messages_tab.dart';
import 'new_conversation_page.dart';

class AgriConnectPage extends ConsumerStatefulWidget {
  const AgriConnectPage({super.key});

  @override
  ConsumerState<AgriConnectPage> createState() => _AgriConnectPageState();
}

class _AgriConnectPageState extends ConsumerState<AgriConnectPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const List<String> _tabLabels = [
    'Home',
    'Communities',
    'Forum',
    'Messages',
  ];

  int _activeTab = 0;

  // Tabs are built on first visit and then kept alive so their state
  // (and loaded data) survives switching.
  final Set<int> _visited = {0};

  void _selectTab(int index) {
    if (index < 0 || index >= _tabLabels.length) return;
    if (index == _activeTab && _visited.contains(index)) return;
    setState(() {
      _activeTab = index;
      _visited.add(index);
    });
  }

  Widget _tabContent(int index) {
    if (!_visited.contains(index)) return const SizedBox.shrink();
    switch (index) {
      case 0:
        return HomeTab(onNavigate: _selectTab);
      case 1:
        return const CommunitiesTab();
      case 2:
        return const ForumTab();
      default:
        return const MessagesTab();
    }
  }

  String get _subtitle => switch (_activeTab) {
    0 => "What's happening in farming?",
    1 => 'Find and join farming groups',
    2 => 'Agricultural discussions',
    _ => 'Your conversations',
  };

  void _onTrailingTap() {
    switch (_activeTab) {
      case 1:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CreateCommunityPage()));
      case 3:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NewConversationPage()));
      default:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CreateDiscussionPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ModuleHeaderWidget(
            title: 'AgriConnect',
            subtitle: _subtitle,
            trailingIcon: _activeTab == 3
                ? Icons.add_comment_outlined
                : Icons.add_circle_outline,
            onTrailingTap: _onTrailingTap,
          ),
          const SizedBox(height: 14),
          AgriConnectTabSelectorWidget(
            tabs: _tabLabels,
            activeTab: _activeTab,
            onTabSelected: _selectTab,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: IndexedStack(
              index: _activeTab,
              children: [
                for (var i = 0; i < _tabLabels.length; i++) _tabContent(i),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
