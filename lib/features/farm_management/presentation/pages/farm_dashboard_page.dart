import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/presentation/dashboard/farm_operational_dashboard.dart';
/// FARM DASHBOARD ENTRY POINT
///
/// 🧠 This page renders the live FarmOperationalDashboard that
///     composes all 7+ live provider widgets into a responsive
///     layout showing production, revenue, inventory, health,
///     alerts, marketplace, activity, and runtime status.
///
/// ✅ Consumes:
///   - FarmOperationalDashboard (composer widget)
///   - All underlying providers via individual widgets
///
/// ❌ Does NOT:
///   - Bypass repository/providers
///   - Call Supabase directly
///   - Duplicate business logic
///
class FarmDashboardPage extends ConsumerWidget {
  const FarmDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const FarmOperationalDashboard();
  }
}