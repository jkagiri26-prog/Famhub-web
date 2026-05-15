import 'package:flutter/material.dart';

class AgriConnectTabSelectorWidget extends StatelessWidget {
  final List<String> tabs;
  final int activeTab;
  final ValueChanged<int> onTabSelected;

  const AgriConnectTabSelectorWidget({
    super.key,
    required this.tabs,
    required this.activeTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(
          tabs.length,
          (index) {
            final isActive = index == activeTab;

            return GestureDetector(
              onTap: () => onTabSelected(index),
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? primary.withOpacity(0.10)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? primary
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: isActive
                        ? primary
                        : Colors.grey,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}