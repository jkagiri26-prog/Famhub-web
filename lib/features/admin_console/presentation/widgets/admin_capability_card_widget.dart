import 'package:flutter/material.dart';

import 'package:famhub_app/features/admin_console/domain/models/admin_capability.dart';
import 'package:famhub_app/shared/utils/icon_resolver.dart';

/// ============================================================
/// ADMIN CAPABILITY CARD
/// ============================================================
///
/// Presentation for a single Admin capability descriptor.
///
/// This card is only ever rendered for capabilities the runtime has
/// explicitly allowed. It contains no statistics or fabricated data.
///
/// The management operation itself is intentionally not wired yet
/// (foundation phase) — the card is informational and non-navigating.
/// ============================================================
class AdminCapabilityCardWidget extends StatelessWidget {
  final AdminCapability capability;

  const AdminCapabilityCardWidget({
    super.key,
    required this.capability,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              IconResolver.resolve(capability.iconKey),
              size: 24,
              color: primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        capability.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ScopeBadge(scope: capability.scope),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  capability.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeBadge extends StatelessWidget {
  final AdminScope scope;

  const _ScopeBadge({required this.scope});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        scope == AdminScope.platform ? 'Platform' : 'Entity',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
      ),
    );
  }
}
