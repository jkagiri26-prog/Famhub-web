/// ============================================================
/// REPORTS PAGE — Drill-Down Hierarchy Reports
/// ============================================================
///
/// 🏗️ OFFICIAL HIERARCHY:
///   Farm / Entity → Field / Block → Crop or Livestock → Activity → **Report**
///
/// Reports must be drill-down capable:
///   Farm-level → Field-level → Crop/Livestock-level → Activity-level
///
/// Reports aggregate data from Activities, grouped by:
///   - Crop/Livestock
///   - Field/Block
///   - Farm/Entity
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';

import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';

/// ============================================================
/// REPORTS PROVIDER — Hierarchy-Aware Report Data
/// ============================================================
///
/// Aggregates all activities and production data grouped by
/// hierarchy level. Supports drill-down:
///   Farm-level → Field-level → Crop/Livestock-level
/// ============================================================
final hierarchyReportsProvider =
    FutureProvider.family<Map<String, dynamic>, String?>(
  (ref, _) async {
    final farmId = ref.watch(farmContextProvider).farmId;
    if (farmId == null) return {};

    final repository = ref.read(farmRepositoryProvider);

    // Fetch activity report — hierarchy filtering is client-side
    final activityReport = await repository.getActivityReport(
      farmId: farmId,
    );

    // Fetch production report — hierarchy filtering is client-side
    final productionReport = await repository.getProductionReport(
      farmId: farmId,
    );

    return {
      'activity_report': activityReport,
      'production_report': productionReport,
    };
  },
);

/// ============================================================
/// REPORTS PAGE
/// ============================================================
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  /// Current drill-down level: 'farm', 'field', 'crop_livestock', 'activity'
  String _drillLevel = 'farm';

  /// Selected field for drill-down
  String? _selectedFieldId;

  /// Selected crop/livestock for drill-down
  String? _selectedCropOrLivestockId;

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(farmContextProvider).farmId;
    final hierarchy = ref.watch(hierarchyProvider);

    if (farmId == null) {
      return const ShellPageContent(
        title: 'Reports',
        subtitle: 'Select a farm to view reports',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.description_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Select a farm to generate reports',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Determine drill level based on hierarchy
    final effectiveLevel = hierarchy.hasCropOrLivestock
        ? 'activity'
        : hierarchy.hasField
            ? 'crop_livestock'
            : hierarchy.hasEntity
                ? 'field'
                : 'farm';

    if (effectiveLevel != _drillLevel) {
      // Reset drill selections when hierarchy changes
      _drillLevel = effectiveLevel;
    }

    return _buildDrillDownReport(context, effectiveLevel, hierarchy);
  }

  /// ============================================================
  /// DRILL-DOWN REPORT BUILDER
  /// ============================================================
  ///
  /// Renders reports at the appropriate hierarchy level:
  ///   - Farm-level: Overview of all fields, crops, activities
  ///   - Field-level: Details for a specific field/block
  ///   - Crop/Livestock-level: Details for a specific production unit
  ///   - Activity-level: Individual activity records
  /// ============================================================
  Widget _buildDrillDownReport(
    BuildContext context,
    String level,
    HierarchySelectionState hierarchy,
  ) {
    final theme = Theme.of(context);

    return ShellPageContent(
      title: _getReportTitle(level),
      subtitle: _getReportSubtitle(level, hierarchy),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drill Navigation ──
            _buildDrillNavigation(theme, level, hierarchy),
            const SizedBox(height: 20),

            // ── Report Content by Level ──
            switch (level) {
              'farm' => _buildFarmLevelReport(theme, hierarchy),
              'field' => _buildFieldLevelReport(theme, hierarchy),
              'crop_livestock' => _buildCropLivestockLevelReport(theme, hierarchy),
              'activity' => _buildActivityLevelReport(theme, hierarchy),
              _ => _buildFarmLevelReport(theme, hierarchy),
            },
          ],
        ),
      ),
    );
  }

  String _getReportTitle(String level) {
    switch (level) {
      case 'farm':
        return 'Farm-Level Report';
      case 'field':
        return 'Field-Level Report';
      case 'crop_livestock':
        return 'Crop / Livestock Report';
      case 'activity':
        return 'Activity Report';
      default:
        return 'Reports';
    }
  }

  String _getReportSubtitle(String level, HierarchySelectionState hierarchy) {
    switch (level) {
      case 'farm':
        return 'Overview of all agricultural operations';
      case 'field':
        return '${hierarchy.field?.fieldName ?? 'Field'} — Detailed analysis';
      case 'crop_livestock':
        final name = hierarchy.cropOrLivestockType == 'crop'
            ? (hierarchy.cropOrLivestock as dynamic?)?.cropName ?? 'Crop'
            : (hierarchy.cropOrLivestock as dynamic?)?.species ?? 'Livestock';
        return '$name — Production unit report';
      case 'activity':
        return 'Individual activity records and metrics';
      default:
        return 'Farm management reports';
    }
  }

  /// ============================================================
  /// DRILL NAVIGATION
  /// ============================================================
  Widget _buildDrillNavigation(
    ThemeData theme,
    String currentLevel,
    HierarchySelectionState hierarchy,
  ) {
    final levels = ['farm', 'field', 'crop_livestock', 'activity'];
    final labels = ['Farm', 'Field', 'Crop/Livestock', 'Activity'];

    // Determine which levels are accessible
    final canDrillTo = <String, bool>{
      'farm': true,
      'field': hierarchy.hasEntity,
      'crop_livestock': hierarchy.hasField,
      'activity': hierarchy.hasCropOrLivestock,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: List.generate(levels.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Icon(Icons.arrow_forward, size: 14, color: Colors.grey.shade400);
          }
          final levelIndex = index ~/ 2;
          final level = levels[levelIndex];
          final isActive = currentLevel == level;
          final canAccess = canDrillTo[level] ?? false;

          return GestureDetector(
            onTap: canAccess ? () => setState(() => _drillLevel = level) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                    : canAccess
                        ? Colors.white
                        : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive
                      ? theme.colorScheme.primary
                      : Colors.grey.shade300,
                ),
              ),
              child: Text(
                labels[levelIndex],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? theme.colorScheme.primary
                      : canAccess
                          ? Colors.black87
                          : Colors.grey.shade500,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// ============================================================
  /// FARM-LEVEL REPORT
  /// ============================================================
  Widget _buildFarmLevelReport(ThemeData theme, HierarchySelectionState hierarchy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Cards
        _ReportSummaryCard(
          icon: Icons.agriculture,
          title: 'Farm Overview',
          value: hierarchy.entity?.farmName ?? 'Farm',
          subtitle: '${hierarchy.entity?.size?.toStringAsFixed(1) ?? 'N/A'} ha',
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),

        // Field Summary
        Text(
          'Fields / Blocks Summary',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _DrillDownHint(
          message: 'Select a field from the Fields/Blocks tab, '
              'then return to Reports for field-level drill-down.',
          icon: Icons.terrain,
        ),

        const SizedBox(height: 20),

        // Activity Summary
        Text(
          'Activity Summary',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _DrillDownHint(
          message: 'Navigate to a specific field and crop/livestock '
              'to see detailed activity reports.',
          icon: Icons.list_alt,
        ),
      ],
    );
  }

  /// ============================================================
  /// FIELD-LEVEL REPORT
  /// ============================================================
  Widget _buildFieldLevelReport(ThemeData theme, HierarchySelectionState hierarchy) {
    final field = hierarchy.field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReportSummaryCard(
          icon: Icons.terrain,
          title: 'Field Report',
          value: field?.fieldName ?? 'Selected Field',
          subtitle: '${field?.acreage?.toStringAsFixed(1) ?? 'N/A'} ha | ${field?.soilType ?? 'N/A'} soil',
          color: Colors.brown,
        ),
        const SizedBox(height: 16),

        // Field details
        _ReportDetailRow('Status', field?.statusLabel ?? 'N/A'),
        _ReportDetailRow('Soil Type', field?.soilType ?? 'N/A'),
        _ReportDetailRow('Current Crop', field?.currentCrop ?? 'None'),
        if (field?.acreage != null)
          _ReportDetailRow('Acreage', '${field!.acreage!.toStringAsFixed(1)} ha'),
        const SizedBox(height: 16),

        // Crops in this field
        Text(
          'Crops in this Field',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _DrillDownHint(
          message: 'Select a crop from the Crops tab, '
              'then return here for crop-level drill-down.',
          icon: Icons.eco,
        ),
      ],
    );
  }

  /// ============================================================
  /// CROP/LIVESTOCK-LEVEL REPORT
  /// ============================================================
  Widget _buildCropLivestockLevelReport(
    ThemeData theme,
    HierarchySelectionState hierarchy,
  ) {
    final isLivestock = hierarchy.cropOrLivestockType == 'livestock';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReportSummaryCard(
          icon: isLivestock ? Icons.pets : Icons.eco,
          title: isLivestock ? 'Livestock Report' : 'Crop Report',
          value: isLivestock
              ? (hierarchy.cropOrLivestock as dynamic?)?.species ?? 'Livestock'
              : (hierarchy.cropOrLivestock as dynamic?)?.cropName ?? 'Crop',
          subtitle: isLivestock
              ? '${(hierarchy.cropOrLivestock as dynamic?)?.count ?? 0} head'
              : '${(hierarchy.cropOrLivestock as dynamic?)?.statusLabel ?? 'N/A'}',
          color: isLivestock ? Colors.orange : Colors.green,
        ),
        const SizedBox(height: 16),

        if (isLivestock) ...[
          _ReportDetailRow('Breed', (hierarchy.cropOrLivestock as dynamic?)?.breed ?? 'N/A'),
          _ReportDetailRow('Count', '${(hierarchy.cropOrLivestock as dynamic?)?.count ?? 0}'),
          _ReportDetailRow('Health', (hierarchy.cropOrLivestock as dynamic?)?.healthLabel ?? 'N/A'),
          _ReportDetailRow('Purpose', (hierarchy.cropOrLivestock as dynamic?)?.purposeLabel ?? 'N/A'),
        ] else ...[
          _ReportDetailRow('Variety', (hierarchy.cropOrLivestock as dynamic?)?.variety ?? 'N/A'),
          _ReportDetailRow('Status', (hierarchy.cropOrLivestock as dynamic?)?.statusLabel ?? 'N/A'),
          _ReportDetailRow('Area Planted',
              '${(hierarchy.cropOrLivestock as dynamic?)?.areaPlanted?.toStringAsFixed(1) ?? 'N/A'} ha'),
          _ReportDetailRow('Days Since Planting',
              '${(hierarchy.cropOrLivestock as dynamic?)?.daysSincePlanting?.inDays ?? 0} days'),
        ],

        const SizedBox(height: 20),

        // Activities for this crop/livestock
        Text(
          'Related Activities',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _DrillDownHint(
          message: isLivestock
              ? 'View activities for this livestock in the Activities tab.'
              : 'View activities for this crop in the Activities tab.',
          icon: Icons.list_alt,
        ),
      ],
    );
  }

  /// ============================================================
  /// ACTIVITY-LEVEL REPORT
  /// ============================================================
  Widget _buildActivityLevelReport(
    ThemeData theme,
    HierarchySelectionState hierarchy,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReportSummaryCard(
          icon: Icons.list_alt,
          title: 'Activity Report',
          value: 'Detailed Activity Records',
          subtitle: 'For the current selection in the hierarchy',
          color: Colors.blue,
        ),
        const SizedBox(height: 16),

        Text(
          'Hierarchy Path',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PathRow('Farm', hierarchy.entity?.farmName ?? 'N/A'),
              _PathRow('Field', hierarchy.field?.fieldName ?? 'N/A'),
              _PathRow(
                hierarchy.cropOrLivestockType == 'livestock'
                    ? 'Livestock'
                    : 'Crop',
                hierarchy.cropOrLivestockType == 'livestock'
                    ? (hierarchy.cropOrLivestock as dynamic?)?.species ?? 'N/A'
                    : (hierarchy.cropOrLivestock as dynamic?)?.cropName ?? 'N/A',
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'Activity Records',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        // Activity records loaded from provider
        _ActivityReportList(farmId: hierarchy.entityId),

        const SizedBox(height: 20),

        // Navigation hint
        _DrillDownHint(
          message: 'View the full activity timeline in the Activities tab.',
          icon: Icons.open_in_new,
        ),
      ],
    );
  }
}

/// ============================================================
/// ACTIVITY REPORT LIST
/// ============================================================
class _ActivityReportList extends ConsumerWidget {
  final String? farmId;

  const _ActivityReportList({this.farmId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = this.farmId ?? ref.watch(farmContextProvider).farmId;
    if (farmId == null) {
      return const Text('No farm selected');
    }

    final activitiesAsync = ref.watch(
      hierarchyReportsProvider('activity_list'),
    );

    return activitiesAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Unable to load activity data.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ),
      data: (report) {
        final activities = report['activity_report'] as Map<String, dynamic>? ?? {};
        if (activities.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No activities recorded yet.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          );
        }

        return Column(
          children: activities.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.blue.shade300),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.value}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// ============================================================
/// UI COMPONENTS
/// ============================================================

class _ReportSummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _ReportSummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReportDetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrillDownHint extends StatelessWidget {
  final String message;
  final IconData icon;

  const _DrillDownHint({
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PathRow extends StatelessWidget {
  final String label;
  final String value;

  const _PathRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.arrow_right, size: 16, color: Colors.blue.shade300),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }
}