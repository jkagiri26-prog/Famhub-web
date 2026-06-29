/// ============================================================
/// REPORTS CENTER (ENTERPRISE PHASE 8)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/reports/presentation/pages/ = reports center
///
/// ✅ Responsibilities:
///   - Reports aggregated from all ReportDescriptors
///   - Each module contributes its own report types
///   - No hardcoded report lists
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Reports registered by each module
///   - Categories auto-generated from descriptors
///   - No hardcoded report groups
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/composition/contributions/contribution_models.dart';
import 'package:famhub_app/core/composition/contributions/runtime_contribution_engine.dart';
import 'package:famhub_app/core/composition/providers/composition_providers.dart';
import 'package:famhub_app/shared/utils/icon_resolver.dart';

/// ============================================================
/// REPORTS CENTER PROVIDER
/// ============================================================
final reportsProvider = FutureProvider<Map<String, List<ReportContribution>>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  return runtimeContributionEngine.reports(enabledModules: modules);
});

/// ============================================================
/// REPORTS CENTER PAGE
/// ============================================================
class ReportsCenterPage extends ConsumerWidget {
  const ReportsCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reportsAsync = ref.watch(reportsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Reports',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.grey.shade600),
            onPressed: () {},
            tooltip: 'Filter',
          ),
        ],
      ),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (categorized) {
          if (categorized.isEmpty) {
            return _buildEmptyState(theme);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: categorized.entries.map((entry) => _ReportCategory(
              category: entry.key,
              reports: entry.value,
              theme: theme,
            )).toList(),
          );
        },
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
            Icon(Icons.description_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No Reports',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('No reports are configured.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// REPORT CATEGORY
/// ============================================================
class _ReportCategory extends StatelessWidget {
  final String category;
  final List<ReportContribution> reports;
  final ThemeData theme;

  const _ReportCategory({
    required this.category,
    required this.reports,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            category.replaceAll('_', ' ').toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...reports.map((report) => _ReportTile(report: report)),
      ],
    );
  }
}

/// ============================================================
/// REPORT TILE
/// ============================================================
class _ReportTile extends StatelessWidget {
  final ReportContribution report;

  const _ReportTile({required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = IconResolver.resolve(report.iconKey);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
        title: Text(
          report.displayName,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: report.description.isNotEmpty
            ? Text(
                report.description,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              )
            : null,
        trailing: Icon(Icons.download_outlined, color: Colors.grey.shade400),
        onTap: () {},
      ),
    );
  }
}
