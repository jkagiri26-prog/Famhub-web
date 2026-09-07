/// ============================================================
/// BUSINESS HUB SECTION BOUNDARY (TAB CONTENT)
/// ============================================================
///
/// Placeholder boundary for a Business Hub operational tab that has not
/// been implemented yet.
///
/// Rules:
///   - ESTABLISHES THE BOUNDARY ONLY — no inventory / procurement /
///     sales / payments backend operations are implemented here.
///   - Capability-aware: when the current business context lacks the
///     tab's capability (Capability Framework), the section renders as
///     unavailable instead of fabricating data.
///   - Real section widgets replace this boundary in later phases; each
///     future metric must bind to a real backend contract.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/capabilities/application/capability_profile_provider.dart';
import 'package:famhub_app/core/capabilities/domain/capability.dart';

class BusinessHubSectionBoundary extends ConsumerWidget {
  final String title;
  final IconData icon;
  final Capability? capability;

  /// Copy describing what this section will surface when implemented.
  final String blurb;

  const BusinessHubSectionBoundary({
    super.key,
    required this.title,
    required this.icon,
    this.capability,
    required this.blurb,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(capabilityProfileProvider);
    final enabled = capability == null ||
        (profile?.hasCapability(capability!.id) ?? false);

    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        enabled
                            ? 'Section boundary'
                            : 'Not available for this business',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: enabled
                              ? Colors.grey.shade600
                              : Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  enabled ? Icons.construction_outlined : Icons.lock_outline,
                  size: 20,
                  color: enabled
                      ? Colors.grey.shade400
                      : Colors.orange.shade300,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              enabled ? blurb : _unavailableMessage(),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: enabled
                    ? Colors.blueGrey.withValues(alpha: 0.06)
                    : Colors.orange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                enabled
                    ? 'This section is a boundary and will be implemented '
                        'in a later phase.'
                    : 'Enable this capability for the business to unlock '
                        'this section.',
                style: TextStyle(
                  fontSize: 11,
                  color: enabled ? Colors.blueGrey.shade600 : Colors.orange.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _unavailableMessage() {
    final cap = capability;
    if (cap == null) return 'This section is not available for this business.';
    return '${cap.name} (${cap.id}) is not enabled for the current '
        'business context. Sections appear based on business capabilities '
        'and available data — not business type.';
  }
}
