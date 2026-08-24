/// ============================================================
/// WORKSPACE CATALOG ITEM — Backend-driven workspace record
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/workspace/domain/ = workspace domain models
///
/// A lightweight presentation model for a row in `system.workspaces`.
/// The backend (system.workspaces table) is the source of truth for the
/// workspace catalog — this model intentionally has NO hardcoded list of
/// workspace types, so new records (e.g. Retailer, Trader, Aggregator,
/// Suppliers, Agrovet, Financial Institution, Insurance, Labour Service)
/// appear in the UI automatically without a frontend enum.
///
/// ❌ Does NOT:
///   - Contain a hardcoded workspace catalog
///   - Contain business logic
/// ============================================================
library;

/// A single selectable workspace record from `system.workspaces`.
class WorkspaceCatalogItem {
  final String id;
  final String name;

  /// Short human-readable description (may be null in the DB).
  final String? description;

  /// Grouping label, e.g. "Trader / Retailer", "Aggregator / Suppliers",
  /// "Other stakeholders". Null when the backend does not categorize.
  final String? category;

  /// Generic icon key resolved through IconResolver (presentation only).
  final String? iconKey;

  const WorkspaceCatalogItem({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.iconKey,
  });

  /// Build from a `system.workspaces` row.
  ///
  /// Column names are read defensively so minor backend variations
  /// (name/title/display_name, category/workspace_type/type,
  /// icon/icon_key/icon_name) never break the UI.
  factory WorkspaceCatalogItem.fromRow(Map<String, dynamic> row) {
    return WorkspaceCatalogItem(
      id: row['id']?.toString() ?? '',
      name: (row['name'] ??
              row['title'] ??
              row['display_name'] ??
              row['label'] ??
              'Workspace')
          .toString(),
      description: (row['description'] ??
              row['subtitle'] ??
              row['summary'])
          ?.toString(),
      category: (row['category'] ??
              row['workspace_type'] ??
              row['type'])
          ?.toString(),
      iconKey: (row['icon'] ?? row['icon_key'] ?? row['icon_name'])
          ?.toString(),
    );
  }
}
