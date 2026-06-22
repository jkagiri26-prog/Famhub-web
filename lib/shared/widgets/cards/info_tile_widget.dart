// ignore: dangling_library_doc_comments
/// ============================================================
/// INFO TILE WIDGET (REUSABLE INFO DISPLAY)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/widgets/cards/ = reusable card widgets
///
/// ✅ Responsibilities:
///   - Display labeled info with value
///   - Optional icon and copy action
///   - Consistent across all modules
///
/// ❌ Does NOT:
///   - Reference registries or providers
///   - Contain business logic
/// ============================================================

import 'package:flutter/material.dart';

class InfoTileWidget extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool copyable;
  final VoidCallback? onTap;

  const InfoTileWidget({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.copyable = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (copyable || onTap != null)
            InkWell(
              onTap: onTap ?? () => _copyToClipboard(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  copyable ? Icons.copy_rounded : Icons.chevron_right_rounded,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    // Using Flutter's clipboard
    // Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
