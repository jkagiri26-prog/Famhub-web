/// ============================================================
/// WORKSPACE CATALOG PROVIDER — Backend-driven workspace list
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/workspace/application/ = application layer
///
/// ✅ Responsibilities:
///   - Load available workspaces from `system.workspaces`
///   - Present them to the Workspace Selection UI
///   - Expose loading / error / data states via Riverpod
///
/// ❌ Does NOT:
///   - Hardcode a workspace catalog
///   - Contain UI
///   - Persist selections
///
/// The backend is the source of truth. Any workspace record added to
/// `system.workspaces` (Retailer, Trader, Aggregator, Suppliers, Agrovet,
/// Input Supplier, Manufacturer, Financial Institution, Insurance,
/// Labour Service, future types) is shown automatically.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/core/workspace/domain/workspace_catalog_item.dart';

/// Provider that fetches the workspace catalog from `system.workspaces`.
/// Use `ref.watch(workspaceCatalogProvider)` to reactively read state.
final workspaceCatalogProvider =
    FutureProvider<List<WorkspaceCatalogItem>>((ref) async {
  final supabase = SupabaseService.instance;

  final response = await supabase
      .from('workspaces', schema: 'system')
      .select();

  final rows = response as List;
  final items = rows
      .whereType<Map>()
      .map((r) => WorkspaceCatalogItem.fromRow(Map<String, dynamic>.from(r)))
      .toList();

  items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return items;
});
