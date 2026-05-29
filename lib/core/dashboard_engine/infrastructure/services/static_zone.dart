import 'package:flutter/material.dart';
import '../../domain/models/dashboard_zone_model.dart';

class _StaticZone extends StatelessWidget {
  const _StaticZone({
    required this.zone,
  });

  final DashboardZoneModel zone;

  @override
  Widget build(BuildContext context) {
    /// ============================================================
    /// PURE RENDER BOUNDARY
    /// NO SIDE EFFECTS
    /// NO MUTATION
    /// ============================================================

    final widgets = zone.widgets;

    return Column(
      key: ValueKey(zone.id),
      children: List<Widget>.unmodifiable(widgets),
    );
  }
}