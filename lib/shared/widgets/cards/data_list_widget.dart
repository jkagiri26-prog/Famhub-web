/// ============================================================
/// DATA LIST WIDGET (REUSABLE DATA ROWS)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/widgets/cards/ = reusable card widgets
///
/// ✅ Responsibilities:
///   - Consistent data row display
///   - Label-value pairs
///   - Optional actions per row
///   - Loading/empty states
///
/// ❌ Does NOT:
///   - Reference registries or providers
///   - Contain business logic
/// ============================================================

import 'package:flutter/material.dart';

class DataListWidget extends StatelessWidget {
  final List<DataRowItem> items;
  final bool isLoading;
  final String? emptyMessage;

  const DataListWidget({
    super.key,
    required this.items,
    this.isLoading = false,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            emptyMessage ?? 'No data available',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildRow(context, item);
      },
    );
  }

  Widget _buildRow(BuildContext context, DataRowItem item) {
    final theme = Theme.of(context);

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.leading != null) ...[
            item.leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (item.value != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.value!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (item.trailing != null) item.trailing!,
        ],
      ),
    );

    if (item.onTap != null) {
      return InkWell(
        onTap: item.onTap,
        child: row,
      );
    }

    return row;
  }
}

class DataRowItem {
  final String label;
  final String? value;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  const DataRowItem({
    required this.label,
    this.value,
    this.leading,
    this.trailing,
    this.onTap,
  });
}
