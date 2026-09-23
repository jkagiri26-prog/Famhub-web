/// ============================================================
/// ADMIN TAXONOMY — READ MODELS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/domain/models/ = domain models
///
/// The narrow admin-management projection returned by the canonical
/// `users.admin_*` taxonomy RPCs. One shared node shape covers domains,
/// categories, items and variants; only variants carry a `source`.
/// ============================================================
library;

/// The four canonical taxonomy hierarchy levels.
enum TaxonomyLevel { domain, category, item, variant }

class AdminTaxonomyNode {
  final String id;
  final String name;
  final bool isActive;
  final String? source;

  const AdminTaxonomyNode({
    required this.id,
    required this.name,
    this.isActive = true,
    this.source,
  });

  factory AdminTaxonomyNode.fromMap(Map<String, dynamic> map) =>
      AdminTaxonomyNode(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        isActive: map['is_active'] != false,
        source: (map['source'] ?? map['source_type'] ?? map['origin'])
            ?.toString(),
      );
}

class AdminTaxonomyPage {
  final List<AdminTaxonomyNode> items;
  final int totalCount;

  const AdminTaxonomyPage({required this.items, required this.totalCount});

  factory AdminTaxonomyPage.empty() =>
      const AdminTaxonomyPage(items: [], totalCount: 0);

  bool get isEmpty => items.isEmpty;
}
