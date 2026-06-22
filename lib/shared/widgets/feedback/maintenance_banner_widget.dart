// ignore: dangling_library_doc_comments
/// ============================================================
/// MAINTENANCE BANNER WIDGET (REUSABLE BANNER)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/widgets/feedback/ = reusable feedback widgets
///
/// ✅ Responsibilities:
///   - Display maintenance/offline/status banners
///   - Dismissable or persistent
///   - Consistent across all modules
///
/// ❌ Does NOT:
///   - Contain business logic
/// ============================================================

import 'package:flutter/material.dart';

class MaintenanceBannerWidget extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isDismissable;
  final MaintenanceBannerType type;

  const MaintenanceBannerWidget({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isDismissable = false,
    this.type = MaintenanceBannerType.info,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _resolveColors(theme);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderColor),
      ),
      child: Row(
        children: [
          Icon(
            colors.icon,
            size: 20,
            color: colors.iconColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textColor,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.iconColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _BannerColors _resolveColors(ThemeData theme) {
    switch (type) {
      case MaintenanceBannerType.info:
        return _BannerColors(
          backgroundColor: Colors.blue.shade50,
          borderColor: Colors.blue.shade100,
          iconColor: Colors.blue.shade700,
          textColor: Colors.blue.shade900,
          icon: Icons.info_outline_rounded,
        );
      case MaintenanceBannerType.warning:
        return _BannerColors(
          backgroundColor: Colors.orange.shade50,
          borderColor: Colors.orange.shade100,
          iconColor: Colors.orange.shade700,
          textColor: Colors.orange.shade900,
          icon: Icons.warning_amber_rounded,
        );
      case MaintenanceBannerType.error:
        return _BannerColors(
          backgroundColor: Colors.red.shade50,
          borderColor: Colors.red.shade100,
          iconColor: Colors.red.shade700,
          textColor: Colors.red.shade900,
          icon: Icons.error_outline_rounded,
        );
      case MaintenanceBannerType.success:
        return _BannerColors(
          backgroundColor: Colors.green.shade50,
          borderColor: Colors.green.shade100,
          iconColor: Colors.green.shade700,
          textColor: Colors.green.shade900,
          icon: Icons.check_circle_outline_rounded,
        );
    }
  }
}

enum MaintenanceBannerType { info, warning, error, success }

class _BannerColors {
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;
  final IconData icon;

  const _BannerColors({
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.textColor,
    required this.icon,
  });
}
