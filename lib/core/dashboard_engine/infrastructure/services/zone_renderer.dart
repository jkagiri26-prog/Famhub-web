import 'package:flutter/material.dart';
import '../../domain/models/dashboard_zone_model.dart';

class _ZoneRenderer extends StatelessWidget {
  const _ZoneRenderer({
    required this.zoneId,
    required this.zone,
    required this.isDirty,
  });

  final String zoneId;
  final DashboardZoneModel zone;
  final bool isDirty;

  @override
  Widget build(BuildContext context) {
    /// ============================================================
    /// PURE UI DECISION LAYER
    /// NO SIDE EFFECTS ALLOWED
    /// ============================================================

    final child = _StaticZone(zone: zone);

    if (!isDirty) {
      return child;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: child,
    );
  }
}