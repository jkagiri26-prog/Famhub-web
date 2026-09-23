/// ============================================================
/// ADMIN TAXONOMY PROVIDERS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/application/providers/ = application layer
///
/// Bridges the Taxonomy UI to the admin-safe `AdminTaxonomyService`.
/// A single family list provider is keyed by (level, parentId, query) so
/// Riverpod caches each combination. All filtering/pagination is
/// server-side and scoped to the selected parent.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/admin_console/domain/models/admin_taxonomy.dart';
import 'package:famhub_app/features/admin_console/infrastructure/services/admin_taxonomy_service.dart';

final adminTaxonomyServiceProvider =
    Provider<AdminTaxonomyService>((ref) => AdminTaxonomyService());

class AdminTaxonomyQuery {
  final String? search;
  final bool? isActive;
  final int page;
  final int pageSize;

  const AdminTaxonomyQuery({
    this.search,
    this.isActive,
    this.page = 0,
    this.pageSize = 25,
  });

  int get offset => page * pageSize;

  @override
  bool operator ==(Object other) =>
      other is AdminTaxonomyQuery &&
      other.search == search &&
      other.isActive == isActive &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(search, isActive, page, pageSize);
}

class AdminTaxonomyListKey {
  final TaxonomyLevel level;
  final String? parentId;
  final AdminTaxonomyQuery query;

  const AdminTaxonomyListKey({
    required this.level,
    required this.parentId,
    required this.query,
  });

  @override
  bool operator ==(Object other) =>
      other is AdminTaxonomyListKey &&
      other.level == level &&
      other.parentId == parentId &&
      other.query == query;

  @override
  int get hashCode => Object.hash(level, parentId, query);
}

final adminTaxonomyListProvider =
    FutureProvider.family<AdminTaxonomyPage, AdminTaxonomyListKey>(
  (ref, key) async {
    final service = ref.watch(adminTaxonomyServiceProvider);
    final search = key.query.search?.trim();
    final s = (search == null || search.isEmpty) ? null : search;
    final q = key.query;

    return switch (key.level) {
      TaxonomyLevel.domain => service.listDomains(
          search: s,
          isActive: q.isActive,
          limit: q.pageSize,
          offset: q.offset,
        ),
      TaxonomyLevel.category => service.listCategories(
          domainId: key.parentId!,
          search: s,
          isActive: q.isActive,
          limit: q.pageSize,
          offset: q.offset,
        ),
      TaxonomyLevel.item => service.listItems(
          categoryId: key.parentId!,
          search: s,
          isActive: q.isActive,
          limit: q.pageSize,
          offset: q.offset,
        ),
      TaxonomyLevel.variant => service.listVariants(
          itemId: key.parentId!,
          search: s,
          isActive: q.isActive,
          limit: q.pageSize,
          offset: q.offset,
        ),
    };
  },
);

/// Actions controller: performs create/update/set-active through the service.
/// Invalidation is done by the calling container so only the affected
/// container's list reloads.
final adminTaxonomyActionsProvider =
    Provider<AdminTaxonomyActions>((ref) => AdminTaxonomyActions(ref));

class AdminTaxonomyActions {
  final Ref _ref;

  AdminTaxonomyActions(this._ref);

  AdminTaxonomyService get _service =>
      _ref.read(adminTaxonomyServiceProvider);

  Future<void> create(TaxonomyLevel level, String name,
      {String? parentId}) async {
    switch (level) {
      case TaxonomyLevel.domain:
        await _service.createDomain(name);
      case TaxonomyLevel.category:
        await _service.createCategory(parentId!, name);
      case TaxonomyLevel.item:
        await _service.createItem(parentId!, name);
      case TaxonomyLevel.variant:
        await _service.createVariant(parentId!, name);
    }
  }

  Future<void> update(TaxonomyLevel level, String id, String name) async {
    switch (level) {
      case TaxonomyLevel.domain:
        await _service.updateDomain(id, name);
      case TaxonomyLevel.category:
        await _service.updateCategory(id, name);
      case TaxonomyLevel.item:
        await _service.updateItem(id, name);
      case TaxonomyLevel.variant:
        await _service.updateVariant(id, name);
    }
  }

  Future<void> setActive(
      TaxonomyLevel level, String id, bool isActive) async {
    switch (level) {
      case TaxonomyLevel.domain:
        await _service.setDomainActive(id, isActive);
      case TaxonomyLevel.category:
        await _service.setCategoryActive(id, isActive);
      case TaxonomyLevel.item:
        await _service.setItemActive(id, isActive);
      case TaxonomyLevel.variant:
        await _service.setVariantActive(id, isActive);
    }
  }

  Future<List<String>> suggestSimilar(String itemId, String name) =>
      _service.suggestSimilarVariants(itemId: itemId, name: name);
}
