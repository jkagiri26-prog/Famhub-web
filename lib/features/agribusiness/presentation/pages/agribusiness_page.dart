import 'package:flutter/material.dart';

import '../../../../shared/widgets/layout/responsive_wrapper_widget.dart';
import '../../../../shared/widgets/headers/module_header_widget.dart';
import '../../../../shared/widgets/headers/section_header_widget.dart';
import '../../../../shared/widgets/cards/action_card_widget.dart';

class AgribusinessPage extends StatelessWidget {
  const AgribusinessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveWrapperWidget(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          /// MODULE HEADER (SHARED)
          ModuleHeaderWidget(
            title: "Agribusiness Hub",
            subtitle: "Farm Finance • Planning • Profitability",
            trailingIcon: Icons.analytics_outlined,
            onTrailingTap: () {},
          ),

          const SizedBox(height: 18),

          /// SECTION HEADER (SHARED)
          const SectionHeaderWidget(
            title: "Farm Business Operations",
          ),

          const SizedBox(height: 12),

          /// ACTION CARDS (SHARED GENERIC CARD)
          ActionCardWidget(
            title: "Farm Enterprise Management",
            description: "Plan and track your farming as a business.",
            icon: Icons.assignment_outlined,
            onTap: () {},
          ),

          const SizedBox(height: 12),

          ActionCardWidget(
            title: "Financial Ledger",
            description: "Record expenses, sales, and profit margins.",
            icon: Icons.account_balance_wallet_outlined,
            onTap: () {},
          ),

          const SizedBox(height: 12),

          ActionCardWidget(
            title: "Input & Cost Planning",
            description:
                "Plan fertilizer, feed, and input costs efficiently.",
            icon: Icons.shopping_cart_outlined,
            onTap: () {},
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}