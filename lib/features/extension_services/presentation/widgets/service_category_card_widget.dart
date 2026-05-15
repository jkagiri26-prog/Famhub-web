import 'package:flutter/material.dart';

import '../../../../../shared/widgets/cards/action_card_widget.dart';

class ServiceCategoryCardWidget extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const ServiceCategoryCardWidget({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ActionCardWidget(
      title: title,
      description: description,
      icon: icon,
      onTap: () {},
    );
  }
}