/// ============================================================
/// ERROR STATE WIDGET (STANDARDIZED UX)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/widgets/states/ = reusable UX states
///
/// ✅ Standardized error states:
///   - Error icon + message
///   - Optional retry button
///   - Optional detailed error info
/// ============================================================

import 'package:flutter/material.dart';

class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final String? detailedError;

  const ErrorStateWidget({
    super.key,
    required this.title,
    required this.message,
    this.retryLabel,
    this.onRetry,
    this.detailedError,
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
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (detailedError != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  detailedError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red.shade700,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
            if (retryLabel != null && onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(retryLabel!),
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
