import 'package:flutter/material.dart';

class MarketplaceFilterTabsWidget extends StatelessWidget {
  final String activeTab;
  final ValueChanged<String> onChanged;

  const MarketplaceFilterTabsWidget({
    super.key,
    required this.activeTab,
    required this.onChanged,
  });

  static const List<String> tabs = [
    'ALL',
    'LIVESTOCK',
    'EQUIPMENT',
    'CROPS',
    'INPUTS',
    'OTHER',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isActive = activeTab == tab;
          return GestureDetector(
            onTap: () => onChanged(tab),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tab,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
