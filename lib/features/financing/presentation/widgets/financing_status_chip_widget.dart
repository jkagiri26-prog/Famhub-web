/// ============================================================
/// FINANCING — STATUS / VERIFICATION CHIP
/// ============================================================
///
/// Small, non-interactive label for catalogue state. Colours are derived from
/// the existing brand tokens so chips read consistently with the rest of the
/// shell. No new colour values are introduced.
/// ============================================================
library;

import 'package:flutter/material.dart';


enum FinancingStatusTone {
  neutral,
  positive,
  warning,
  negative,
  info,
}

class FinancingStatusChip extends StatelessWidget {
  const FinancingStatusChip({
    super.key,
    required this.label,
    this.tone = FinancingStatusTone.neutral,
    this.icon,
    this.tooltip,
  });

  final String label;
  final FinancingStatusTone tone;
  final IconData? icon;
  final String? tooltip;

  Color get _background => switch (tone) {
        FinancingStatusTone.neutral => const Color(0xFFF1F3F4),
        FinancingStatusTone.positive => const Color(0xFFE6F4EA),
        FinancingStatusTone.warning => const Color(0xFFFFF4E5),
        FinancingStatusTone.negative => const Color(0xFFFDECEA),
        FinancingStatusTone.info => const Color(0xFFE8F0FE),
      };

  Color get _foreground => switch (tone) {
        FinancingStatusTone.neutral => const Color(0xFF5F6368),
        FinancingStatusTone.positive => const Color(0xFF1E7B34),
        FinancingStatusTone.warning => const Color(0xFFB06000),
        FinancingStatusTone.negative => const Color(0xFFB3261E),
        FinancingStatusTone.info => const Color(0xFF1A56C4),
      };

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: _foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _foreground,
            ),
          ),
        ],
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) return chip;
    return Tooltip(message: tooltip!, child: chip);
  }
}

/// Verification chip for a provider row.
FinancingStatusTone verificationTone(String dbValue) => switch (dbValue) {
      'verified' => FinancingStatusTone.positive,
      'rejected' => FinancingStatusTone.negative,
      'suspended' => FinancingStatusTone.negative,
      _ => FinancingStatusTone.warning,
    };

/// Approval chip for a product row.
FinancingStatusTone approvalTone(String dbValue) => switch (dbValue) {
      'approved' => FinancingStatusTone.positive,
      'rejected' => FinancingStatusTone.negative,
      'in_review' => FinancingStatusTone.info,
      _ => FinancingStatusTone.neutral,
    };
