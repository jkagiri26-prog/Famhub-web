import 'package:flutter/material.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/cards/empty_state_card_widget.dart';

import '../widgets/agri_connect_tab_selector_widget.dart';
import '../widgets/agri_feed_card_placeholder_widget.dart';

class AgriConnectPage extends StatefulWidget {
  const AgriConnectPage({super.key});

  @override
  State<AgriConnectPage> createState() => _AgriConnectPageState();
}

class _AgriConnectPageState extends State<AgriConnectPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int activeTab = 0;

  final List<String> tabs = const [
    'Feed',
    'Groups',
    'Forums',
    'Alerts',
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ResponsiveWrapperWidget(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          /// Shared Universal Header
          const ModuleHeaderWidget(
            title: 'AgriConnect',
            subtitle: 'Community • Knowledge • Farmers Network',
            trailingIcon: Icons.search,
          ),

          const SizedBox(height: 16),

          /// Module-specific Tabs
          AgriConnectTabSelectorWidget(
            tabs: tabs,
            activeTab: activeTab,
            onTabSelected: (index) {
              setState(() {
                activeTab = index;
              });
            },
          ),

          const SizedBox(height: 14),

          Expanded(
            child: _buildActiveView(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveView() {
    switch (activeTab) {
      case 0:
        return _buildFeedPlaceholder();

      case 1:
        return const EmptyStateCardWidget(
          icon: Icons.group_outlined,
          title: 'Groups',
          subtitle: 'Farmer groups will appear here',
        );

      case 2:
        return const EmptyStateCardWidget(
          icon: Icons.forum_outlined,
          title: 'Forums',
          subtitle: 'Discussion forums coming soon',
        );

      case 3:
        return const EmptyStateCardWidget(
          icon: Icons.notifications_active_outlined,
          title: 'Alerts',
          subtitle: 'Pests, prices, and weather alerts',
        );

      default:
        return _buildFeedPlaceholder();
    }
  }

  Widget _buildFeedPlaceholder() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: const [
        SizedBox(height: 8),

        AgriFeedCardPlaceholderWidget(
          title: 'Community Post',
          subtitle: 'Farmer discussions will appear here',
        ),

        AgriFeedCardPlaceholderWidget(
          title: 'Market Insight',
          subtitle: 'Price updates and trade info',
        ),

        SizedBox(height: 80),
      ],
    );
  }
}