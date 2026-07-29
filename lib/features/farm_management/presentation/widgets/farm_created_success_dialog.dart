/// ============================================================
/// FARM CREATED SUCCESS DIALOG
/// ============================================================
///
/// 🏗️ POST-CREATION EXPERIENCE:
///   Displayed immediately after a new farm is created.
///   Only appears once — dismissed by tapping Continue or Go to Dashboard.
/// ============================================================
library;

import 'package:flutter/material.dart';

/// Shows a success dialog after farm creation.
///
/// This is a one-time experience that guides the user to either:
///   - Continue Setup (guided onboarding)
///   - Go to Dashboard (skip ahead)
class FarmCreatedSuccessDialog extends StatelessWidget {
  final String farmName;
  final String fieldName;
  final double? farmSize;
  final VoidCallback onContinueSetup;
  final VoidCallback onGoToDashboard;

  const FarmCreatedSuccessDialog({
    super.key,
    required this.farmName,
    required this.fieldName,
    this.farmSize,
    required this.onContinueSetup,
    required this.onGoToDashboard,
  });

  /// Show the dialog from any context
  static Future<void> show({
    required BuildContext context,
    required String farmName,
    required String fieldName,
    double? farmSize,
    required VoidCallback onContinueSetup,
    required VoidCallback onGoToDashboard,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FarmCreatedSuccessDialog(
        farmName: farmName,
        fieldName: fieldName,
        farmSize: farmSize,
        onContinueSetup: () {
          Navigator.of(ctx).pop();
          onContinueSetup();
        },
        onGoToDashboard: () {
          Navigator.of(ctx).pop();
          onGoToDashboard();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Success Icon ──
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 36,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 16),

            // ── Title ──
            Text(
              'Farm Created Successfully!',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // ── Farm summary ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryRow('Farm', farmName),
                  const SizedBox(height: 6),
                  _summaryRow('Main Field', fieldName),
                  if (farmSize != null) ...[const SizedBox(height: 6), _summaryRow('Total Area', '$farmSize ha')],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Description ──
            Text(
              'To help you get started, FAMHUB has automatically created a Main Field using your farm\'s total area. You can begin recording crops or livestock immediately, or later divide your farm into multiple fields.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // ── Continue Setup Button ──
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: onContinueSetup,
                icon: const Icon(Icons.rocket_launch, size: 18),
                label: const Text('Continue Setup'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Go to Dashboard Button ──
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: onGoToDashboard,
                icon: const Icon(Icons.dashboard, size: 18),
                label: const Text('Go to Dashboard'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ],
    );
  }
}
