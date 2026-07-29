/// ============================================================
/// HIERARCHY BREADCRUMB
/// ============================================================
///
/// 🏗️ OFFICIAL HIERARCHY BREADCRUMB:
///   Farm > Field > Crop/Livestock > Activities > Reports
///
/// Displays the current hierarchical navigation path.
/// Each segment is tappable to navigate back up the hierarchy.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';

class HierarchyBreadcrumb extends ConsumerWidget {
  const HierarchyBreadcrumb({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hierarchy = ref.watch(hierarchyProvider);

    // Build breadcrumb segments based on current hierarchy state
    final segments = <_BreadcrumbSegment>[];

    // Segment 1: Farm / Entity
    segments.add(_BreadcrumbSegment(
      label: hierarchy.entity?.farmName ?? 'Farm',
      icon: Icons.agriculture,
      level: 0,
      isActive: hierarchy.hasEntity && !hierarchy.hasField,
      onTap: hierarchy.hasField
          ? () => ref.read(hierarchyProvider.notifier).clearToEntity()
          : null,
    ));

    // Segment 2: Field / Block
    if (hierarchy.hasEntity) {
      segments.add(_BreadcrumbSegment(
        label: hierarchy.field?.fieldName ?? 'Field',
        icon: Icons.terrain,
        level: 1,
        isActive: hierarchy.hasField && !hierarchy.hasCropOrLivestock,
        onTap: hierarchy.hasCropOrLivestock
            ? () => ref.read(hierarchyProvider.notifier).clearToField()
            : null,
      ));
    }

    // Segment 3: Crop or Livestock
    if (hierarchy.hasField) {
      final cropOrLivestockLabel = hierarchy.cropOrLivestockType == 'crop'
          ? (hierarchy.cropOrLivestock != null
              ? (hierarchy.cropOrLivestock as dynamic).cropName ?? 'Crop'
              : 'Crop')
          : hierarchy.cropOrLivestockType == 'livestock'
              ? (hierarchy.cropOrLivestock != null
                  ? (hierarchy.cropOrLivestock as dynamic).species ?? 'Livestock'
                  : 'Livestock')
              : 'Crop / Livestock';

      segments.add(_BreadcrumbSegment(
        label: cropOrLivestockLabel,
        icon: hierarchy.cropOrLivestockType == 'livestock'
            ? Icons.pets
            : Icons.eco,
        level: 2,
        isActive: hierarchy.hasCropOrLivestock,
        onTap: null, // This is the deepest level
      ));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(segments.length * 2 - 1, (index) {
          // Every even index is a segment, odd index is a separator
          if (index.isOdd) {
            final separatorIndex = index ~/ 2;
            return _buildSeparator(theme);
          }
          final segmentIndex = index ~/ 2;
          return _buildSegmentChip(context, theme, segments[segmentIndex], ref);
        }),
      ),
    );
  }

  Widget _buildSegmentChip(
    BuildContext context,
    ThemeData theme,
    _BreadcrumbSegment segment,
    WidgetRef ref,
  ) {
    final isLast = segment.onTap == null && segment.isActive;

    return GestureDetector(
      onTap: segment.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: segment.isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: segment.isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              segment.icon,
              size: 14,
              color: segment.isActive
                  ? theme.colorScheme.primary
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              segment.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: segment.isActive ? FontWeight.w600 : FontWeight.w400,
                color: segment.isActive
                    ? theme.colorScheme.primary
                    : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeparator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.chevron_right,
        size: 16,
        color: Colors.grey.shade400,
      ),
    );
  }
}

class _BreadcrumbSegment {
  final String label;
  final IconData icon;
  final int level;
  final bool isActive;
  final VoidCallback? onTap;

  const _BreadcrumbSegment({
    required this.label,
    required this.icon,
    required this.level,
    required this.isActive,
    this.onTap,
  });
}
