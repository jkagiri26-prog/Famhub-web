import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/features/admin_console/domain/models/admin_taxonomy.dart';

/// ============================================================
/// ADMIN TAXONOMY SERVICE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/infrastructure/services/ = infrastructure
///
/// The ONLY frontend entry point for canonical taxonomy admin management.
/// Uses the deployed admin RPCs (authorized server-side):
///   admin_list_domains / admin_list_categories / admin_list_items /
///   admin_list_item_variants / admin_suggest_similar_item_variants
///   admin_create_* / admin_update_* / admin_set_*_active
///
/// ❌ Never queries `core.domains` / `core.categories` / `core.items` /
///    `core.item_variants` directly and adds no client-side authorization
///    logic. The backend remains authoritative.
/// ============================================================
class AdminTaxonomyService {
  final _client = SupabaseService.instance.client;

  Future<AdminTaxonomyPage> listDomains({
    String? search,
    bool? isActive,
    int limit = 25,
    int offset = 0,
    String sort = 'name',
    String order = 'asc',
  }) {
    return _list('admin_list_domains', {
      'p_search': search,
      'p_is_active': isActive,
      'p_limit': limit,
      'p_offset': offset,
      'p_sort': sort,
      'p_order': order,
    });
  }

  Future<AdminTaxonomyPage> listCategories({
    required String domainId,
    String? search,
    bool? isActive,
    int limit = 25,
    int offset = 0,
    String sort = 'name',
    String order = 'asc',
  }) {
    return _list('admin_list_categories', {
      'p_domain_id': domainId,
      'p_search': search,
      'p_is_active': isActive,
      'p_limit': limit,
      'p_offset': offset,
      'p_sort': sort,
      'p_order': order,
    });
  }

  Future<AdminTaxonomyPage> listItems({
    required String categoryId,
    String? search,
    bool? isActive,
    int limit = 25,
    int offset = 0,
    String sort = 'name',
    String order = 'asc',
  }) {
    return _list('admin_list_items', {
      'p_category_id': categoryId,
      'p_search': search,
      'p_is_active': isActive,
      'p_limit': limit,
      'p_offset': offset,
      'p_sort': sort,
      'p_order': order,
    });
  }

  Future<AdminTaxonomyPage> listVariants({
    required String itemId,
    String? search,
    bool? isActive,
    int limit = 25,
    int offset = 0,
    String sort = 'name',
    String order = 'asc',
  }) {
    return _list('admin_list_item_variants', {
      'p_item_id': itemId,
      'p_search': search,
      'p_is_active': isActive,
      'p_limit': limit,
      'p_offset': offset,
      'p_sort': sort,
      'p_order': order,
    });
  }

  Future<List<String>> suggestSimilarVariants({
    required String itemId,
    required String name,
    String? excludeVariantId,
    int limit = 10,
  }) async {
    try {
      final response = await _client.schema('users').rpc(
            'admin_suggest_similar_item_variants',
            params: {
              'p_item_id': itemId,
              'p_name': name,
              'p_exclude_variant_id': excludeVariantId,
              'p_limit': limit,
            },
          );
      return (response as List)
          .whereType<Map>()
          .map((r) => (r['name'] ?? r['variant_name'] ?? '').toString())
          .where((name) => name.isNotEmpty)
          .toList();
    } on PostgrestException catch (e) {
      throw AdminTaxonomyException(e.message);
    } catch (e) {
      throw AdminTaxonomyException('$e');
    }
  }

  Future<void> createDomain(String name) =>
      _write('admin_create_domain', {'p_name': name});

  Future<void> updateDomain(String domainId, String name) =>
      _write('admin_update_domain', {'p_domain_id': domainId, 'p_name': name});

  Future<void> setDomainActive(String domainId, bool isActive) =>
      _write('admin_set_domain_active', {
        'p_domain_id': domainId,
        'p_is_active': isActive,
      });

  Future<void> createCategory(String domainId, String name) =>
      _write('admin_create_category', {
        'p_domain_id': domainId,
        'p_name': name,
      });

  Future<void> updateCategory(String categoryId, String name) =>
      _write('admin_update_category', {
        'p_category_id': categoryId,
        'p_name': name,
      });

  Future<void> setCategoryActive(String categoryId, bool isActive) =>
      _write('admin_set_category_active', {
        'p_category_id': categoryId,
        'p_is_active': isActive,
      });

  Future<void> createItem(String categoryId, String name) =>
      _write('admin_create_item', {
        'p_category_id': categoryId,
        'p_name': name,
      });

  Future<void> updateItem(String itemId, String name) =>
      _write('admin_update_item', {'p_item_id': itemId, 'p_name': name});

  Future<void> setItemActive(String itemId, bool isActive) =>
      _write('admin_set_item_active', {
        'p_item_id': itemId,
        'p_is_active': isActive,
      });

  Future<void> createVariant(String itemId, String name) =>
      _write('admin_create_item_variant', {
        'p_item_id': itemId,
        'p_name': name,
      });

  Future<void> updateVariant(String variantId, String name) =>
      _write('admin_update_item_variant', {
        'p_variant_id': variantId,
        'p_name': name,
      });

  Future<void> setVariantActive(String variantId, bool isActive) =>
      _write('admin_set_item_variant_active', {
        'p_variant_id': variantId,
        'p_is_active': isActive,
      });

  Future<AdminTaxonomyPage> _list(
    String function,
    Map<String, dynamic> params,
  ) async {
    try {
      final response = await _client.schema('users').rpc(function, params: params);
      final rows = (response as List)
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      final totalCount = rows.isEmpty
          ? 0
          : (rows.first['total_count'] as num?)?.toInt() ?? rows.length;
      return AdminTaxonomyPage(
        items: rows.map(AdminTaxonomyNode.fromMap).toList(),
        totalCount: totalCount,
      );
    } on PostgrestException catch (e) {
      throw AdminTaxonomyException(e.message);
    } catch (e) {
      throw AdminTaxonomyException('$e');
    }
  }

  Future<void> _write(String function, Map<String, dynamic> params) async {
    try {
      await _client.schema('users').rpc(function, params: params);
    } on PostgrestException catch (e) {
      throw AdminTaxonomyException(e.message);
    } catch (e) {
      throw AdminTaxonomyException('$e');
    }
  }
}

class AdminTaxonomyException implements Exception {
  final String message;

  AdminTaxonomyException(this.message);

  @override
  String toString() => message;
}
