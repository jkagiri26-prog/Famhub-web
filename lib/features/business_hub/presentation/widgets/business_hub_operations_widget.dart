/// ============================================================
/// BUSINESS HUB OPERATIONS WIDGET (FOUNDATION)
/// ============================================================
///
/// Capability-aware foundation for the Business Hub operations area.
///
/// The widget is intentionally NOT business-type driven. It surfaces the
/// business-operation capabilities the current context actually has
/// (from the Capability Framework), so produce traders, agrovets,
/// factories, aggregators, etc. all share this single dashboard
/// foundation. Concrete operational sections (inventory, orders,
/// purchases, payments, listings) land in later phases, each bound to a
/// real backend contract.
///
/// Capability source note: today the profile is derived from the user
/// context role (`core/capabilities`). When a backend capability profile
/// is available it should be swapped in without UI changes.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/capabilities/application/capability_profile_provider.dart';
import 'package:famhub_app/core/capabilities/domain/capability.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/features/business_hub/application/providers/active_business_provider.dart';

/// A single business operation represented in the foundation UI.
class BusinessHubOperation {
  final Capability capability;
  final String label;
  final IconData icon;

  const BusinessHubOperation({
    required this.capability,
    required this.label,
    required this.icon,
  });
}

/// Business operations relevant to a commercial workspace, keyed to
/// existing capability contracts. Each entry will bind to a real data
/// source in a later phase.
const List<BusinessHubOperation> _businessOperations = [
  BusinessHubOperation(
    capability: Capabilities.marketplaceListings,
    label: 'Catalog & Listings',
    icon: Icons.storefront_outlined,
  ),
  BusinessHubOperation(
    capability: Capabilities.inventoryStock,
    label: 'Inventory',
    icon: Icons.inventory_2_outlined,
  ),
  BusinessHubOperation(
    capability: Capabilities.inventoryWarehouse,
    label: 'Warehouse',
    icon: Icons.warehouse_outlined,
  ),
  BusinessHubOperation(
    capability: Capabilities.marketplaceOrders,
    label: 'Orders & Sales',
    icon: Icons.receipt_long_outlined,
  ),
  BusinessHubOperation(
    capability: Capabilities.financeRecording,
    label: 'Payments',
    icon: Icons.payments_outlined,
  ),
  BusinessHubOperation(
    capability: Capabilities.financeInvoicing,
    label: 'Invoicing',
    icon: Icons.request_quote_outlined,
  ),
  BusinessHubOperation(
    capability: Capabilities.logisticsDispatch,
    label: 'Dispatch & Logistics',
    icon: Icons.local_shipping_outlined,
  ),
  BusinessHubOperation(
    capability: Capabilities.analyticsBasic,
    label: 'Business Reports',
    icon: Icons.bar_chart_outlined,
  ),
];

class BusinessHubOperationsWidget extends ConsumerWidget {
  const BusinessHubOperationsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final business = ref.watch(activeBusinessProvider);
    final profile = ref.watch(capabilityProfileProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    if (business == null) {
      return _messageCard(
        context,
        icon: Icons.business_outlined,
        title: 'No active business',
        message: isAuthenticated
            ? 'Add a business to start managing commercial operations.'
            : 'Sign in to manage your business operations.',
      );
    }

    final enabledOperations = _businessOperations
        .where((op) => profile?.hasCapability(op.capability.id) ?? false)
        .toList();

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
            Text(
              'Operations',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Capability-driven workspace for ${business.name}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            if (enabledOperations.isEmpty)
              _messageCard(
                context,
                compact: true,
                icon: Icons.construction_outlined,
                title: 'No operations enabled yet',
                message: isAuthenticated
                    ? 'Business sections will appear here based on this '
                        'business\'s capabilities and available data.'
                    : 'Sign in to see which operations this business can run.',
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final op in enabledOperations)
                    _operationChip(context, op),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _operationChip(BuildContext context, BusinessHubOperation op) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(op.icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            op.label,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _messageCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: Colors.grey.shade500),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
