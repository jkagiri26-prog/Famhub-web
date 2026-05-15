import 'package:flutter/material.dart';

import '../../../../shared/widgets/cards/empty_state_card_widget.dart';

class CalculatorTabWidget extends StatelessWidget {
  const CalculatorTabWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyStateCardWidget(
      icon: Icons.calculate_outlined,
      title: 'Carbon Calculator',
      subtitle:
          'Carbon footprint and sequestration calculator will appear here.',
    );
  }
}