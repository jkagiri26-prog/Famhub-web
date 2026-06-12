/// ============================================================
/// PERMISSION DENIED WIDGET (STANDARDIZED UX)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/widgets/states/ = reusable UX states
///
/// ✅ Standardized permission denied state:
///   - Lock icon
///   - Message about insufficient permissions
///   - Optional contact support action
/// ============================================================

import 'package:flutter/material.dart';

class PermissionDeniedWidget extends StatelessWidget {
  final String? title;
  final String? message;
  final String? contactLabel;
  final VoidCallback? onContact;

  const PermissionDeniedWidget({
    super.key,
    this.title,
    this.message,
    this.contactLabel,
    this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 36,
                color: Colors.orange.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title ?? 'Access Restricted',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'You do not have the required permissions to access this feature.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (contactLabel != null && onContact != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onContact,
                icon: const Icon(Icons.support_agent_outlined, size: 18),
                label: Text(contactLabel!),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
