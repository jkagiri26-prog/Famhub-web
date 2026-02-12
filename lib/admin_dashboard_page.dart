import 'package:flutter/material.dart';

/// FAMHUB Admin Dashboard Module
/// Constraints: No Scaffold, No AppBar, width: double.infinity
class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8.0), // Betpawa spacing rule
            Text(
              'Admin Overview',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            
            // Metrics Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _buildMetricCard(context, 'Users', '1.2k', Icons.people_outline, colorScheme.primary),
                _buildMetricCard(context, 'Revenue', 'KSh 45k', Icons.account_balance_wallet_outlined, Colors.blue),
                _buildMetricCard(context, 'Security', 'Optimal', Icons.shield_outlined, Colors.teal),
                _buildMetricCard(context, 'Logs', '12 New', Icons.list_alt_outlined, Colors.orange),
              ],
            ),
            
            const SizedBox(height: 24),
            Text(
              'Management Actions',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            _buildAdminAction(context, 'User Permissions', Icons.lock_person_outlined),
            _buildAdminAction(context, 'Database Backups', Icons.storage_outlined),
            _buildAdminAction(context, 'Push Notifications', Icons.notification_add_outlined),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildAdminAction(BuildContext context, String title, IconData icon) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).dividerColor.withOpacity(0.05),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        trailing: const Icon(Icons.arrow_right),
        onTap: () {},
      ),
    );
  }
}