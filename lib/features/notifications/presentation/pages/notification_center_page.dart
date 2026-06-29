/// ============================================================
/// UNIFIED NOTIFICATION CENTER (ENTERPRISE PHASE 5)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/notifications/presentation/pages/ = notification center
///
/// ✅ Responsibilities:
///   - Aggregates notifications from all NotificationProviderDescriptors
///   - No module-specific notification handling
///   - Providers registered by each module
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Notification providers come from descriptors
///   - Context Engine filters by module enabled state
///   - No hardcoded notification groups
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/composition/domain/models/module_descriptor.dart';
import 'package:famhub_app/core/composition/providers/descriptor_providers.dart';

/// ============================================================
/// NOTIFICATION CENTER PROVIDER
/// ============================================================
final notificationProvidersProvider = FutureProvider<List<NotificationProviderDescriptor>>((ref) async {
  return ref.watch(notificationProviderDescriptorsProvider.future);
});

/// ============================================================
/// NOTIFICATION CENTER PAGE
/// ============================================================
class NotificationCenterPage extends ConsumerWidget {
  const NotificationCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final providersAsync = ref.watch(notificationProvidersProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Notifications',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.done_all, color: Colors.grey.shade600),
            onPressed: () {},
            tooltip: 'Mark all as read',
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: Colors.grey.shade600),
            onPressed: () {},
            tooltip: 'Notification settings',
          ),
        ],
      ),
      body: providersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (providers) {
          if (providers.isEmpty) {
            return _buildEmptyState(theme);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: providers.length + 1, // +1 for header
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildHeader(providers, theme);
              }

              final provider = providers[index - 1];
              return _NotificationProviderTile(provider: provider);
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(List<NotificationProviderDescriptor> providers, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(
            '${providers.length} provider${providers.length == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined,
              size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No Notifications',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('No notification providers are configured.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// NOTIFICATION PROVIDER TILE
/// ============================================================
class _NotificationProviderTile extends StatelessWidget {
  final NotificationProviderDescriptor provider;

  const _NotificationProviderTile({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.notifications_outlined,
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
                    provider.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${provider.notificationTypes.length} notification type${provider.notificationTypes.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: provider.notificationTypes.map((type) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
            Switch(
              value: provider.enabledByDefault,
              onChanged: (_) {},
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}
