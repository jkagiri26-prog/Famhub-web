import 'package:flutter/material.dart';

import '../../../../shared/widgets/cards/empty_state_card_widget.dart';

class CommunityTabWidget extends StatelessWidget {
  const CommunityTabWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyStateCardWidget(
      icon: Icons.groups_outlined,
      title: 'Village Impact',
      subtitle:
          'Community projects and village sustainability insights will appear here.',
    );
  }
}