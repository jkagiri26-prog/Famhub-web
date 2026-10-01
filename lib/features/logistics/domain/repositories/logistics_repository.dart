/// ============================================================
/// LOGISTICS REPOSITORY (DOMAIN CONTRACT)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/logistics/domain/repositories/ = abstract contract
///
/// ✅ Responsibilities:
///   - Declare the bounded reads the Logistics dashboard needs.
///
/// ❌ Does NOT:
///   - Reference Supabase or any infrastructure type
///   - Contain UI or state
///
/// All results are entity-scoped by the backend RLS. The optional
/// `entityId` argument only narrows reads further using the active
/// entity already derived by the FAMHUB context mechanism — it is
/// never an ownership grant.
/// ============================================================
library;

import '../models/logistics_dashboard_models.dart';

abstract class LogisticsRepository {
  /// One bounded, entity-aware payload for the Logistics dashboard.
  ///
  /// Implementations must cap every list and select only the columns
  /// the dashboard renders (low-data requirement).
  Future<LogisticsDashboardSnapshot> fetchDashboard({String? entityId});
}
