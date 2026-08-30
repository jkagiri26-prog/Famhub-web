/// ============================================================
/// WORKSPACE DASHBOARD PROVIDERS — Workspace-aware Dashboard
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/workspace/application/ = application layer
///
/// ✅ Responsibilities:
///   - Define the code-side workspace-type → module mapping used to
///     promote modules on the selected workspace Dashboard.
///   - Resolve the active workspace's normalized type + display name
///     from `system.workspaces` (via workspaceCatalogProvider).
///   - Provide the ordered dashboard NavItems for the active workspace.
///
/// ✅ Why code-side:
///   - No backend/schema changes. system.workspaces / system.modules
///     remain the source of truth for the catalog and module list.
///   - The mapping is intentionally a small, extendable table.
///
/// ❌ Does NOT:
///   - Create tables, alter system.modules, or change RLS.
///   - Duplicate the generic all-module list on a workspace Dashboard.
///   - Touch More navigation.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/navigation/nav_config.dart';
import 'package:famhub_app/core/navigation/nav_item.dart';
import 'package:famhub_app/core/workspace/application/active_workspace_provider.dart';
import 'package:famhub_app/core/workspace/application/workspace_catalog_provider.dart';
import 'package:famhub_app/core/workspace/domain/workspace_catalog_item.dart';

/// ============================================================
/// WORKSPACE DASHBOARD CATALOG (CODE-SIDE MAPPING)
/// ============================================================
///
/// Maps a normalized workspace type to the ordered module keys promoted
/// on that workspace's Dashboard.
///
/// - The FIRST key is the PRIMARY workspace experience and is surfaced
///   prominently (e.g. farmer → farm_management / Farm Management).
/// - Keys MUST be actual `system.modules.module_key` values. Verified
///   against lib/system/registry/module_registry.dart:
///     farm_management, marketplace, analytics, finance, logistics,
///     traceability, carbon_credit, knowledge_link, agribusiness,
///     opportunities, extension_services, agri_connect, agri_tech_lab,
///     referral_hub, profile, admin_console.
/// - Extend freely: add a workspace type + ordered keys.
///
/// NOTE: 'farmer' is the confidently-established mapping. The other
/// types are initial, best-effort compositions using only actual module
/// keys; adjust as backend workspace metadata is confirmed.
/// ============================================================
class WorkspaceDashboardCatalog {
  /// workspace type → ordered module keys (first = primary experience)
  static const Map<String, List<String>> modulePromotions = {
    'farmer': [
      'farm_management',
      'marketplace',
      'analytics',
      'finance',
      'logistics',
      'traceability',
      'extension_services',
      'knowledge_link',
      'agri_connect',
      'agri_tech_lab',
      'opportunities',
    ],
    'trader': [
      'marketplace',
      'logistics',
      'analytics',
      'finance',
      'traceability',
      'agri_connect',
    ],
    'institution': [
      'finance',
      'analytics',
      'opportunities',
      'marketplace',
    ],
    'supplier': [
      'marketplace',
      'logistics',
      'analytics',
      'agri_connect',
    ],
    'service_provider': [
      'extension_services',
      'analytics',
      'agri_connect',
      'agri_tech_lab',
    ],
    'knowledge_partner': [
      'knowledge_link',
      'agri_tech_lab',
      'analytics',
      'agri_connect',
    ],
  };

  /// Ordered module keys for a workspace type. Unmapped types return [].
  static List<String> moduleKeysFor(String? workspaceType) {
    if (workspaceType == null) return const [];
    return modulePromotions[workspaceType] ?? const [];
  }

  /// Normalize a raw workspace type/category label into a stable key.
  /// Handles common backend label variations (snake_case, aliases).
  static String? normalizeType(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized =
        raw.trim().toLowerCase().replaceAll(RegExp(r'[\s\-/]+'), '_');
    const aliases = <String, String>{
      'financial_institution': 'institution',
      'bank': 'institution',
      'input_supplier': 'supplier',
      'agrovet': 'supplier',
      'aggregator': 'trader',
      'retailer': 'trader',
      'extension_service': 'service_provider',
      'trainer': 'service_provider',
      'knowledge': 'knowledge_partner',
    };
    return aliases[normalized] ?? normalized;
  }
}

/// ============================================================
/// PROVIDER: ACTIVE WORKSPACE TYPE
/// ============================================================
///
/// Resolves the normalized workspace type for the active workspace
/// from the backend `system.workspaces` catalog. Null while unknown.
/// ============================================================
final activeWorkspaceTypeProvider = Provider<String?>((ref) {
  final active = ref.watch(activeWorkspaceProvider);
  final catalog =
      ref.watch(workspaceCatalogProvider).asData?.value ?? const [];
  final item = _catalogById(catalog, active.workspaceId);
  if (item == null) return null;
  final raw = (item.category ?? item.name).trim();
  if (raw.isEmpty) return null;
  return WorkspaceDashboardCatalog.normalizeType(raw);
});

/// ============================================================
/// PROVIDER: ACTIVE WORKSPACE NAME
/// ============================================================
///
/// Display name of the active workspace from the catalog.
/// Null while unknown.
/// ============================================================
final activeWorkspaceNameProvider = Provider<String?>((ref) {
  final active = ref.watch(activeWorkspaceProvider);
  final catalog =
      ref.watch(workspaceCatalogProvider).asData?.value ?? const [];
  final item = _catalogById(catalog, active.workspaceId);
  return item?.name;
});

/// ============================================================
/// PROVIDER: WORKSPACE DASHBOARD NAV ITEMS
/// ============================================================
///
/// Ordered NavItems for the active workspace Dashboard.
/// Built from dashboardNavItemsProvider (backend governance applied)
/// reordered by the code-side promotion map. Never the generic
/// all-module list.
/// ============================================================
final workspaceDashboardNavItemsProvider = Provider<List<NavItem>>((ref) {
  final type = ref.watch(activeWorkspaceTypeProvider);
  final dashboardItems = ref.watch(dashboardNavItemsProvider);
  final keys = WorkspaceDashboardCatalog.moduleKeysFor(type);
  if (keys.isEmpty) return const [];

  final byKey = <String, NavItem>{
    for (final item in dashboardItems) item.moduleKey: item,
  };

  final ordered = <NavItem>[];
  for (final key in keys) {
    final item = byKey[key];
    if (item != null) ordered.add(item);
  }
  return ordered;
});

/// Find a catalog item by id without pulling in the collection package.
WorkspaceCatalogItem? _catalogById(List<WorkspaceCatalogItem> items, String id) {
  for (final item in items) {
    if (item.id == id) return item;
  }
  return null;
}
