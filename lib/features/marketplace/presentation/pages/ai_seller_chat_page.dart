// Ensure this matches your file name: lib/pages/ai_seller_chat_page.dart
import 'package:flutter/material.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';

import '../../domain/entities/listing.dart';

/// AI Seller Chat page.
///
/// Placeholder for future AI-powered seller chat integration.
class AiSellerChatPage extends StatelessWidget {
  final Listing product;
  final bool isSellerView;

  const AiSellerChatPage({
    super.key, 
    required this.product, 
    this.isSellerView = false,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ModuleHeaderWidget(
            title: 'AI Seller Chat',
            subtitle: product.title,
          ),
          const Expanded(
            child: EmptyStateWidget(
              icon: Icons.auto_awesome,
              title: 'AI Chat Coming Soon',
              subtitle:
                  'AI-powered seller chat will be available in a future update.',
            ),
          ),
        ],
      ),
    );
  }
}

