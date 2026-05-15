import '../models/dashboard_descriptor.dart';

/// ============================================================
/// DASHBOARD REPOSITORY CONTRACT (SYSTEM CORE v2)
/// ============================================================
///
/// Domain layer abstraction for dashboard data access.
///
/// Supports:
/// - real-time streaming (UI reactive updates)
/// - snapshot fetch (initial load / refresh)
/// - cache warmup (performance optimization hook)
/// ============================================================

abstract class DashboardRepository {
  /// ------------------------------------------------------------
  /// LIVE STREAM (REAL-TIME UI)
  /// ------------------------------------------------------------
  Stream<List<DashboardDescriptor>> watchDescriptors(
    String moduleKey,
  );

  /// ------------------------------------------------------------
  /// SNAPSHOT FETCH (INITIAL LOAD / MANUAL REFRESH)
  /// ------------------------------------------------------------
  Future<List<DashboardDescriptor>> getDescriptors(
    String moduleKey,
  );

  /// ------------------------------------------------------------
  /// CACHE WARMUP (OPTIONAL PERFORMANCE HOOK)
  /// ------------------------------------------------------------
  ///
  /// Used for:
  /// - preloading dashboard data before UI request
  /// - improving perceived performance
  /// - background hydration
  ///
  /// Can be NO-OP in infrastructure if not needed.
  Future<void> warmCache(String moduleKey);
}