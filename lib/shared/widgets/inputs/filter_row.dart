// ignore: dangling_library_doc_comments
/// ============================================================
/// FILTER ROW (REUSABLE FILTER CHIPS)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/widgets/inputs/ = reusable input widgets
///
/// ✅ Responsibilities:
///   - Consistent filter chip row
///   - Horizontal scrollable filters
///   - Active state management
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Reference registries
/// ============================================================

import 'package:flutter/material.dart';

class FilterRow extends StatelessWidget {
  final List<FilterChipItem> filters;
  final String? selectedValue;
  final ValueChanged<String>? onChanged;
  final bool showAllOption;
  final String allLabel;

  const FilterRow({
    super.key,
    required this.filters,
    this.selectedValue,
    this.onChanged,
    this.showAllOption = true,
    this.allLabel = 'All',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: showAllOption ? filters.length + 1 : filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          String value;
          String label;

          if (showAllOption && index == 0) {
            value = '';
            label = allLabel;
          } else {
            final filter = showAllOption ? filters[index - 1] : filters[index];
            value = filter.value;
            label = filter.label;
          }

          final isSelected = selectedValue == value ||
              (value == '' && (selectedValue == null || selectedValue == ''));

          return FilterChip(
            label: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.grey.shade700,
              ),
            ),
            selected: isSelected,
            onSelected: (_) => onChanged?.call(value),
            selectedColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            checkmarkColor: theme.colorScheme.primary,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : Colors.grey.shade200,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
      ),
    );
  }
}

class FilterChipItem {
  final String value;
  final String label;

  const FilterChipItem({
    required this.value,
    required this.label,
  });
}
