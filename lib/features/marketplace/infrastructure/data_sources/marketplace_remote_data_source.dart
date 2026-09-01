/// ============================================================
/// MARKETPLACE — REMOTE DATA SOURCE
/// ============================================================
///
/// Responsible for Supabase communication.
/// Extracted from MarketplaceService per architecture standard:
///   Domain → RepositoryImpl → DataSource → Supabase
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote data source for marketplace listings.
///
/// Handles all Supabase queries for `marketplace.listings`.
///
/// RELATIONSHIP POLICY (audit — Dec 2026):
///   The authoritative FK contract is:
///     unit_id     → core.units.id            (fk_listing_unit)
///     location_id → core.locations.id        (fk_listing_location)
///     variant_id  → core.item_variants.id    (listings_variant_id_fkey)
///     entity_id   → core.entities.id         (listings_entity_id_fkey)
///     stock_id    → commerce.stock_registry.id (listings_stock_id_fkey)
///
///   PostgREST embeds (`unit:unit_id(name)`, `location:location_id(name)`,
///   `stock:stock_id(...)`) resolve relationships from the PostgREST schema
///   cache. After the recent schema changes that cache is stale for these
///   cross-schema FKs, so the whole query fails with a
///   "Could not find a relationship ... in the schema cache" error.
///
///   Therefore the listings query selects SCALAR FK columns only and the
///   referenced display data is resolved with separate batched lookups:
///     unit_name     ← core.units             (fetchUnitsByIds)
///     location_name ← core.locations         (fetchLocationsByIds)
///     quantities    ← commerce.stock_registry (fetchStockByIds)
///
/// sellerName/sellerRating resolved via separate 2-hop query:
///   entity_id → core.entities → commerce.business_profiles
/// All queries are scoped via RLS — no user_id from frontend.
class MarketplaceRemoteDataSource {
  final SupabaseClient _client;

  MarketplaceRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// PostgREST select fragment — scalar columns only, no FK embeds.
  /// (Cross-schema embeds depend on the PostgREST schema cache, which is
  /// stale for these relationships; see the class docs above.)
  static const String _listingSelectQuery = '''
    id, title, description, price_per_unit, currency, status, images,
    contact_visibility, is_promoted, promoted_until, created_at, updated_at,
    entity_id, variant_id, stock_id, unit_id, location_id
  ''';

  /// Resolve unit names for the given unit IDs (id → name).
  ///
  /// Uses a direct `core.units` query keyed on the scalar `unit_id` FK column
  /// instead of a PostgREST embed, so it never depends on the schema cache.
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
  ///
  /// Direct `core.locations` query — never depends on the schema cache.
  Future<Map<String, String>> fetchLocationsByIds(
      Set<String> locationIds) async {
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

  /// Resolve stock quantities for the given stock IDs
  /// (id → (quantity, reserved_quantity)).
  ///
  /// Direct `commerce.stock_registry` query — never depends on the schema cache.
  Future<Map<String, ({double quantity, double reservedQuantity})>>
      fetchStockByIds(Set<String> stockIds) async {
    final ids = stockIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return const {};
    try {
      final response = await _client
          .schema('commerce')
          .from('stock_registry')
          .select('id, quantity, reserved_quantity')
          .inFilter('id', ids);
      final rows = (response as List).cast<Map<String, dynamic>>();
      return {
        for (final row in rows)
          if (row['id'] != null)
            row['id'].toString(): (
              quantity: (row['quantity'] as num?)?.toDouble() ?? 0,
              reservedQuantity:
                  (row['reserved_quantity'] as num?)?.toDouble() ?? 0,
            ),
      };
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch stock: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch stock: $e');
    }
  }

  /// Fetch all listings (with optional filters).
  Future<List<Map<String, dynamic>>> fetchListings({
    String? category,
    String? searchQuery,
    String? sellerId,
    String? statusFilter,
  }) async {
    try {
      var query = _client
          .schema('marketplace')
          .from('listings')
          .select(_listingSelectQuery);

      if (statusFilter != null && statusFilter.isNotEmpty) {
        final statusValues = statusFilter;
        query = query.or('status.in.($statusValues)');
      } else {
        query = query.not('status', 'eq', 'archived');
      }

      if (sellerId != null) {
        query = query.eq('entity_id', sellerId);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike('title', '%$searchQuery%');
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch listings: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch listings: $e');
    }
  }

  /// Fetch a single listing by ID.
  Future<Map<String, dynamic>?> fetchListingById(String id) async {
    try {
      final response = await _client
          .schema('marketplace')
          .from('listings')
          .select(_listingSelectQuery)
          .eq('id', id)
          .maybeSingle();
      return response;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch listing: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch listing: $e');
    }
  }

  /// Fetch seller business profile by entity_id.
  ///
  /// 2-hop: entity_id → core.entities → commerce.business_profiles
  /// PostgREST cannot natively do this, so it's a separate query.
  Future<Map<String, dynamic>?> fetchSellerProfile(String entityId) async {
    try {
      final response = await _client
          .schema('commerce')
          .from('business_profiles')
          .select('supplier_name, rating')
          .eq('entity_id', entityId)
          .maybeSingle();
      return response;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch seller profile: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch seller profile: $e');
    }
  }

  /// Create a new listing.
  Future<Map<String, dynamic>> createListing(
      Map<String, dynamic> payload) async {
    try {
      final response = await _client
          .schema('marketplace')
          .from('listings')
          .insert({
            ...payload,
            'status': 'draft',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return response;
    } on PostgrestException catch (e) {
      throw Exception('Failed to create listing: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create listing: $e');
    }
  }

  /// Update an existing listing.
  Future<Map<String, dynamic>> updateListing(
      String id, Map<String, dynamic> payload) async {
    try {
      final response = await _client
          .schema('marketplace').from('listings')
          .update({
            ...payload,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();
      return response;
    } on PostgrestException catch (e) {
      throw Exception('Failed to update listing: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update listing: $e');
    }
  }

  /// Archive (soft-delete) a listing.
  Future<void> archiveListing(String id) async {
    try {
      await _client.schema('marketplace').from('listings').update({
        'status': 'archived',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to archive listing: ${e.message}');
    } catch (e) {
      throw Exception('Failed to archive listing: $e');
    }
  }

  /// Publish a listing (move from draft → active).
  Future<Map<String, dynamic>> publishListing(String id) async {
    try {
      final response = await _client
          .schema('marketplace').from('listings')
          .update({
            'status': 'active',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();
      return response;
    } on PostgrestException catch (e) {
      throw Exception('Failed to publish listing: ${e.message}');
    } catch (e) {
      throw Exception('Failed to publish listing: $e');
    }
  }

  /// Update inventory — writes to commerce.stock_registry via stock_id.
  Future<void> updateInventory({
    required String listingId,
    double? availableQuantity,
    double? reservedQuantity,
  }) async {
    try {
      // Lookup stock_id from the listing
      final listing = await _client
          .schema('marketplace')
          .from('listings')
          .select('stock_id')
          .eq('id', listingId)
          .maybeSingle();

      if (listing == null) throw Exception('Listing not found');

      final stockId = listing['stock_id'];
      if (stockId == null) {
        throw Exception('Listing has no associated stock record');
      }

      // Update commerce.stock_registry
      final stockUpdates = <String, dynamic>{};
      if (availableQuantity != null) {
        stockUpdates['quantity'] = availableQuantity;
      }
      if (reservedQuantity != null) {
        stockUpdates['reserved_quantity'] = reservedQuantity;
      }
      stockUpdates['updated_at'] = DateTime.now().toIso8601String();

      await _client
          .schema('commerce')
          .from('stock_registry')
          .update(stockUpdates)
          .eq('id', stockId);

      // Auto-mark sold_out if stock reaches zero
      if (availableQuantity != null && availableQuantity <= 0) {
        await _client
            .schema('marketplace')
            .from('listings')
            .update({
              'status': 'sold_out',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', listingId);
      }
    } on PostgrestException catch (e) {
      throw Exception('Failed to update inventory: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update inventory: $e');
    }
  }

  /// Get seller listing stats.
  Future<Map<String, dynamic>> fetchSellerStats(String entityId) async {
    try {
      final response = await _client
          .schema('marketplace')
          .from('listings')
          .select('status')
          .eq('entity_id', entityId);

      final listings = (response as List).cast<Map<String, dynamic>>();
      final active =
          listings.where((l) => l['status'] == 'active').length;
      final total = listings.length;

      return {
        'total_listings': total,
        'active_listings': active,
        'total_sold': 0,
      };
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch seller stats: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch seller stats: $e');
    }
  }
}
