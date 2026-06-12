import 'package:flutter/material.dart';

class ModuleHeaderWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;

  const ModuleHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailingIcon,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        /// Left Content
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),

        /// Right Action
        if (trailingIcon != null)
          IconButton(
            onPressed: onTrailingTap ?? () {},
            icon: Icon(
              trailingIcon,
              color: primary,
            ),
          ),
      ],
    );
  }
}