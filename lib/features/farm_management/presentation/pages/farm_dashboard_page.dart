import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/shell/unified_dashboard_host.dart';

/// FARM DASHBOARD ENTRY POINT
///
/// This page is a PURE shell entry.
/// It does NOT:
/// - manage state
/// - compose UI
/// - decide layout
/// - handle feature logic
///
/// All responsibilities are delegated to:
/// - UnifiedDashboardHost
/// - Module registry
/// - Dashboard composer system
class FarmDashboardPage extends ConsumerWidget {
  const FarmDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const UnifiedDashboardHost(
      moduleKey: 'farm_management',
    );
  }
}