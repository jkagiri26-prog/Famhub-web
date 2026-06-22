import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';

/// Seller chat view — placeholder for future chat integration.
/// Per architecture rules, chat backend infrastructure is NOT in scope.
class SellerChatView extends ConsumerWidget {
  const SellerChatView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 12),
          ModuleHeaderWidget(
            title: 'Seller Chat',
            subtitle: 'Messaging with sellers',
          ),
          Expanded(
            child: EmptyStateWidget(
              icon: Icons.chat_outlined,
              title: 'Chat Coming Soon',
              subtitle: 'Direct messaging with sellers will be available in a future update.',
            ),
          ),
        ],
      ),
    );
  }
}
