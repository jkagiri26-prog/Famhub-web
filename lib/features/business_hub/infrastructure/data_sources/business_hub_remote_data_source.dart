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
}
