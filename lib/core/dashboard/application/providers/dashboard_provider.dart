import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/dashboard_descriptor.dart';
import '../../infrastructure/repositories/dashboard_repository.dart';

/// ============================================================
/// DASHBOARD PROVIDER (CANONICAL STREAM OWNER)
/// ============================================================
///
/// Architecture Role:
/// - Single source of truth for dashboard descriptors
/// - Delegates all data logic to repository
/// - No business logic inside provider
///
/// Flow:
/// Supabase
///   → Repository (cache + filtering + ordering)
///   → dashboardProvider (state bridge)
///   → UnifiedDashboardHost (UI)
/// ============================================================

final dashboardProvider =
    StreamProvider.family<List<DashboardDescriptor>, String>(
  (ref, moduleKey) {
    final repository = ref.watch(dashboardRepositoryProvider);

    final stream = repository.watchDescriptors(moduleKey);

    /// Optional: auto-dispose safety (prevents memory leaks in dynamic modules)
    ref.onDispose(() {
      // Future extension point: logging / cleanup hooks
    });

    return stream;
  },
);