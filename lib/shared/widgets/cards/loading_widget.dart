/// ============================================================
/// LOADING WIDGET (REUSABLE LOADING INDICATOR)
/// ============================================================
///
/// ?? LOCATION CONTEXT:
///   shared/widgets/cards/ = reusable card widgets
///
/// ? Responsibilities:
///   - Display a loading state
///   - Consistent loading indicator across all modules
///   - Optional message
///
/// ? Does NOT:
///   - Reference registries or providers
///   - Contain business logic
/// ============================================================
library;

import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;
  final double? size;

  const LoadingWidget({
    super.key,
    this.message,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: size ?? 32,
              height: size ?? 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: theme.colorScheme.primary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
