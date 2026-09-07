/// ============================================================
/// BUSINESS HUB — REMOTE DATA SOURCE
/// ============================================================
///
/// Responsible for Supabase communication for Business Hub.
/// Architecture: Domain → RepositoryImpl → DataSource → Supabase
///
/// Backend contract surface (schema identity: `commerce`):
///   - `core.entities`                 → business/entity records
///   - `commerce.business_profiles`    → optional seller profile
///   - `commerce.stock_registry`       → inventory (future sections)
///   - `commerce.stock_movements`      → stock ledger (future sections)
///   - `commerce.orders`               → orders (future sections)
///   - `commerce.purchase_orders`      → purchases (future sections)
///   - `commerce.transactions`         → payments (future sections)
///   - `marketplace.listings`          → sell-side catalog (future)
///   - `core.entity_context_sessions`  → business/context switching
///
/// RLS/identity rules:
///   - Scalar select only; no PostgREST FK embeds (stale schema cache).
///   - Ownership (`core.auth_user_id()`) is resolved server-side under
///     RLS. The client never sends a user id / ownership claim.
///
/// Schema source: docs/Backend schemas/*.md
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote data source for Business Hub reads.
class BusinessHubRemoteDataSource {
  final SupabaseClient _client;

  BusinessHubRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// PostgREST select fragment for `core.entities` — scalar columns only.
  static const String _entitySelectQuery = '''
    id, name, slug, entity_type, verification_status, legal_owner_type,
    is_active, primary_contact_profile_id, created_at, updated_at
  ''';

  /// PostgREST select fragment for `commerce.business_profiles` —
  /// scalar columns only.
  static const String _profileSelectQuery = '''
    id, entity_id, entity_type, supplier_name, contact_person, phone,
    email, verification_status, rating, is_active, created_at, updated_at
  ''';

  /// PostgREST select fragment for `commerce.stock_registry` — scalar
  /// columns only (no FK embeds).
  static const String _stockSelectQuery = '''
    id, entity_id, business_profile_id, variant_id, product_id, unit_id,
    location_id, quantity, reserved_quantity, status, updated_at
  ''';

  /// PostgREST select fragment for `commerce.purchase_orders` — scalar
  /// columns only.
  static const String _purchaseOrderSelectQuery = '''
    id, supplier_id, created_by, status, total_amount, currency, notes,
    created_at
  ''';

  /// PostgREST select fragment for `commerce.business_profiles` name
  /// enrichment — scalar columns only.
  static const String _businessProfileNameSelectQuery = '''
    id, entity_id, supplier_name
  ''';

  /// PostgREST select fragment for `commerce.orders` — scalar columns
  /// only.
  static const String _orderSelectQuery = '''
    id, buyer_id, listing_id, supplier_id, quantity, total_amount, status,
    payment_status, payment_mode, order_date, delivery_date, created_at,
    unit_id
  ''';

  /// PostgREST select fragment for `commerce.order_items` — scalar
  /// columns only. `product_id` is intentionally excluded (no FK).
  static const String _orderItemSelectQuery = '''
    id, order_id, listing_id, variant_id, unit_id, unit, quantity,
    price_per_unit, total_amount
  ''';

  /// PostgREST select fragment for `commerce.transactions` — scalar
  /// columns only.
  static const String _transactionSelectQuery = '''
    id, order_id, supplier_id, amount, currency, payment_method,
    payment_status, transaction_id, transaction_date, recorded_by
  ''';

  /// Fetch `core.entities` rows available to the current user.
  ///
  /// RLS scopes results to entities the authenticated user owns or is a
  /// member of (`core.entities.owner_id` defaults to
  /// `core.auth_user_id()`). The client does not filter by owner.
  Future<List<Map<String, dynamic>>> fetchMyEntities() async {
    try {
      final response = await _client
          .schema('core')
          .from('entities')
          .select(_entitySelectQuery)
          .eq('is_active', true)
          .order('name');
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch businesses: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch businesses: $e');
    }
  }

  /// Fetch the `commerce.business_profiles` row for an entity (if any).
  Future<Map<String, dynamic>?> fetchBusinessProfile(
    String entityId,
  ) async {
    try {
      final response = await _client
          .schema('commerce')
          .from('business_profiles')
          .select(_profileSelectQuery)
          .eq('entity_id', entityId)
          .maybeSingle();
      return response;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch business profile: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch business profile: $e');
    }
  }

  /// Fetch `commerce.stock_registry` rows for a business entity.
  ///
  /// Scoped to the ACTIVE business entity id. Ownership stays
  /// server-side under RLS — no `user_id` is ever sent. `entity_id`
  /// merely narrows to the business already selected by the caller.
  Future<List<Map<String, dynamic>>> fetchInventoryRows(
    String entityId,
  ) async {
    try {
      final response = await _client
          .schema('commerce')
          .from('stock_registry')
          .select(_stockSelectQuery)
          .eq('entity_id', entityId)
          .order('updated_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch inventory: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch inventory: $e');
    }
  }

  /// Resolve variant names for the given variant IDs (id → name).
  Future<Map<String, String>> fetchVariantsByIds(
    Set<String> variantIds,
  ) async {
    final ids = variantIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return const {};
    try {
      final response = await _client
          .schema('core')
          .from('item_variants')
          .select('id, name')
          .inFilter('id', ids);
      final rows = (response as List).cast<Map<String, dynamic>>();
      return {
        for (final row in rows)
          if (row['id'] != null)
            row['id'].toString(): row['name']?.toString() ?? '',
      };
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch variants: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch variants: $e');
    }
  }

  /// Resolve item (product) names for the given item IDs (id → name).
  Future<Map<String, String>> fetchItemsByIds(Set<String> itemIds) async {
    final ids = itemIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return const {};
    try {
      final response = await _client
          .schema('core')
          .from('items')
          .select('id, name')
          .inFilter('id', ids);
      final rows = (response as List).cast<Map<String, dynamic>>();
      return {
        for (final row in rows)
          if (row['id'] != null)
            row['id'].toString(): row['name']?.toString() ?? '',
      };
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch items: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch items: $e');
    }
  }

  /// Resolve unit names for the given unit IDs (id → name).
  Future<Map<String, String>> fetchUnitsByIds(Set<String> unitIds) async {
    final ids = unitIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return const {};
    try {
      final response = await _client
          .schema('core')
          .from('units')
          .select('id, name')
          .inFilter('id', ids);
      final rows = (response as List).cast<Map<String, dynamic>>();
      return {
        for (final row in rows)
          if (row['id'] != null)
            row['id'].toString(): row['name']?.toString() ?? '',
      };
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch units: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch units: $e');
    }
  }

  /// Resolve location names for the given location IDs (id → name).
  Future<Map<String, String>> fetchLocationsByIds(
    Set<String> locationIds,
  ) async {
    final ids = locationIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return const {};
    try {
      final response = await _client
          .schema('core')
          .from('locations')
          .select('id, name')
          .inFilter('id', ids);
      final rows = (response as List).cast<Map<String, dynamic>>();
      return {
        for (final row in rows)
          if (row['id'] != null)
            row['id'].toString(): row['name']?.toString() ?? '',
      };
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch locations: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch locations: $e');
    }
  }

  /// ============================================================
  /// PROCUREMENT (commerce.purchase_orders)
  /// ============================================================

  /// Fetch the owner profile id for an entity (`core.entities.owner_id`).
  Future<String?> fetchEntityOwnerId(String entityId) async {
    try {
      final response = await _client
          .schema('core')
          .from('entities')
          .select('owner_id')
          .eq('id', entityId)
          .maybeSingle();
      if (response == null) return null;
      return response['owner_id']?.toString();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch entity owner: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch entity owner: $e');
    }
  }

  /// Fetch the active member profile ids for an entity
  /// (`core.entity_members.profile_id`).
  Future<Set<String>> fetchEntityMemberProfileIds(String entityId) async {
    try {
      final response = await _client
          .schema('core')
          .from('entity_members')
          .select('profile_id')
          .eq('entity_id', entityId)
          .eq('is_active', true);
      final rows = (response as List).cast<Map<String, dynamic>>();
      final ids = <String>{};
      for (final row in rows) {
        final id = row['profile_id']?.toString();
        if (id != null && id.isNotEmpty) ids.add(id);
      }
      return ids;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch entity members: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch entity members: $e');
    }
  }

  /// Fetch `commerce.purchase_orders` rows created by any of the given
  /// profile ids. Scalar columns only; ownership is server-side RLS.
  Future<List<Map<String, dynamic>>> fetchPurchaseOrdersByCreators(
    Set<String> creatorProfileIds,
  ) async {
    final ids = creatorProfileIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return const [];
    try {
      final response = await _client
          .schema('commerce')
          .from('purchase_orders')
          .select(_purchaseOrderSelectQuery)
          .inFilter('created_by', ids)
          .order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch purchase orders: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch purchase orders: $e');
    }
  }

  /// Resolve supplier display names for the given
  /// `commerce.business_profiles` ids (id → supplier_name).
  Future<Map<String, String>> fetchBusinessProfileNamesByIds(
    Set<String> profileIds,
  ) async {
    final ids = profileIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return const {};
    try {
      final response = await _client
          .schema('commerce')
          .from('business_profiles')
          .select(_businessProfileNameSelectQuery)
          .inFilter('id', ids);
      final rows = (response as List).cast<Map<String, dynamic>>();
      return {
        for (final row in rows)
          if (row['id'] != null)
            row['id'].toString():
                row['supplier_name']?.toString() ?? '',
      };
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch suppliers: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch suppliers: $e');
    }
  }

  /// ============================================================
  /// SALES (commerce.orders / commerce.order_items)
  /// ============================================================

  /// Fetch the `commerce.business_profiles` ids belonging to an entity
  /// (the business's seller profile(s) of record).
  Future<Set<String>> fetchEntityBusinessProfileIds(String entityId) async {
    try {
      final response = await _client
          .schema('commerce')
          .from('business_profiles')
          .select('id')
          .eq('entity_id', entityId)
          .eq('is_active', true);
      final rows = (response as List).cast<Map<String, dynamic>>();
      final ids = <String>{};
      for (final row in rows) {
        final id = row['id']?.toString();
        if (id != null && id.isNotEmpty) ids.add(id);
      }
      return ids;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch business profiles: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch business profiles: $e');
    }
  }

  /// Fetch `commerce.orders` where the seller (`supplier_id`) is one of
  /// the given business profiles. Scalar columns only; RLS scopes rows.
  Future<List<Map<String, dynamic>>> fetchOrdersBySuppliers(
    Set<String> supplierProfileIds,
  ) async {
    final ids = supplierProfileIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return const [];
    try {
      final response = await _client
          .schema('commerce')
          .from('orders')
          .select(_orderSelectQuery)
          .inFilter('supplier_id', ids)
          .order('order_date', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch orders: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch orders: $e');
    }
  }

  /// Fetch `commerce.order_items` rows for the given order ids (linked
  /// via the verified `order_id` FK).
  Future<List<Map<String, dynamic>>> fetchOrderItemsByOrderIds(
    Set<String> orderIds,
  ) async {
    final ids = orderIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return const [];
    try {
      final response = await _client
          .schema('commerce')
          .from('order_items')
          .select(_orderItemSelectQuery)
          .inFilter('order_id', ids)
          .order('created_at', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch order items: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch order items: $e');
    }
  }

  /// Resolve buyer display names from `users.profiles`
  /// (id → "First Last"). Best-effort — profiles visibility is RLS-bound.
  Future<Map<String, String>> fetchUserProfileNamesByIds(
    Set<String> profileIds,
  ) async {
    final ids = profileIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return const {};
    try {
      final response = await _client
          .schema('users')
          .from('profiles')
          .select('id, first_name, last_name')
          .inFilter('id', ids);
      final rows = (response as List).cast<Map<String, dynamic>>();
      final names = <String, String>{};
      for (final row in rows) {
        if (row['id'] == null) continue;
        final first = row['first_name']?.toString() ?? '';
        final last = row['last_name']?.toString() ?? '';
        final full = '$first $last'.trim();
        names[row['id'].toString()] = full;
      }
      return names;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch buyers: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch buyers: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════
  // PAYMENTS (commerce.transactions)
  // ════════════════════════════════════════════════════════════════

  /// Fetch `commerce.transactions` where the business of record
  /// (`supplier_id`) is one of the given business profiles. Scalar
  /// columns only; RLS scopes rows.
  Future<List<Map<String, dynamic>>> fetchTransactionsBySuppliers(
    Set<String> supplierProfileIds,
  ) async {
    final ids = supplierProfileIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return const [];
    try {
      final response = await _client
          .schema('commerce')
          .from('transactions')
          .select(_transactionSelectQuery)
          .inFilter('supplier_id', ids)
          .order('transaction_date', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch transactions: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }
}
