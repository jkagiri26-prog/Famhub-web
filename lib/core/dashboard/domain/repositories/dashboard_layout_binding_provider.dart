import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/dashboard_layout_binding_rule.dart';
import '../../infrastructure/repositories/dashboard_layout_binding_repository.dart';

/// ------------------------------------------------------------
/// REPOSITORY PROVIDER
/// ------------------------------------------------------------
final dashboardLayoutBindingRepositoryProvider =
    Provider<DashboardLayoutBindingRepository>((ref) {
  return DashboardLayoutBindingRepository(
    Supabase.instance.client,
  );
});

/// ------------------------------------------------------------
/// LIVE LAYOUT BINDING RULES STREAM
/// ------------------------------------------------------------
///
/// This is the SINGLE source of truth for:
/// - module layout overrides
/// - role-based layouts
/// - entity-specific layouts
/// - device-based layouts
///
final dashboardLayoutBindingProvider =
    StreamProvider<List<DashboardLayoutBindingRule>>((ref) {
  final repo = ref.read(
    dashboardLayoutBindingRepositoryProvider,
  );

  return repo.watchRules();
});