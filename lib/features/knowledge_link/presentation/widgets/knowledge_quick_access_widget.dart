import 'package:flutter/material.dart';
import 'package:famhub/shared/widgets/cards/action_card_widget.dart';

class KnowledgeQuickAccessWidget extends StatelessWidget {
  const KnowledgeQuickAccessWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        ActionCardWidget(
          title: "AI Extension Support",
          description:
              "Get farming recommendations and advisory support",
          icon: Icons.smart_toy_outlined,
        ),

        SizedBox(height: 12),

        ActionCardWidget(
          title: "Latest Agricultural News",
          description:
              "Market prices, government updates, and seasonal alerts",
          icon: Icons.newspaper_outlined,
        ),

        SizedBox(height: 12),

        ActionCardWidget(
          title: "Farmer Forum",
          description:
              "Join discussions, ask experts, and learn from farmers",
          icon: Icons.forum_outlined,
        ),
      ],
    );
  }
}