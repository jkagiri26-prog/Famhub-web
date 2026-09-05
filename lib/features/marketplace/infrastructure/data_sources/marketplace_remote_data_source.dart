/// ============================================================
/// MARKETPLACE — REMOTE DATA SOURCE
/// ============================================================
///
/// Responsible for Supabase communication.
/// Extracted from MarketplaceService per architecture standard:
///   Domain → RepositoryImpl → DataSource → Supabase
/// ============================================================
library;

import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/listing_edit_changes.dart';

/// Serializes [changes] into the exact whitelisted JSONB payload accepted by
/// `marketplace.update_listing`.
///
/// Only the four editable fields can ever appear:
///   title, description, price_per_unit, currency
/// Nothing else (images, status, ids, promotion fields, timestamps) can be
/// produced, because [ListingEditChanges] cannot even carry them.
/// A description that was intentionally cleared serializes as `null`.
Map<String, dynamic> editableListingChangesPayload(ListingEditChanges changes) {
  final payload = <String, dynamic>{};
  if (changes.title != null) payload['title'] = changes.title;
  if (changes.descriptionChanged) {
    payload['description'] = changes.description;
  }
  if (changes.pricePerUnit != null) {
    payload['price_per_unit'] = changes.pricePerUnit;
  }
  if (changes.currency != null) payload['currency'] = changes.currency;
  return payload;
}

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

  /// Resolve variant names for the given variant IDs (id → name).
  ///
  /// Direct `core.item_variants` query — never depends on the schema cache.
  Future<Map<String, String>> fetchVariantsByIds(Set<String> variantIds) async {
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
  ///
  /// Direct `core.items` query — never depends on the schema cache.
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

  // ════════════════════════════════════════════════════════════════
  // MANAGED-STOCK PUBLISHING (PHASE 1)
  // ════════════════════════════════════════════════════════════════
  //
  // Reads `commerce.stock_registry` — the existing inventory system —
  // scoped by RLS. No cross-schema FK embeds (stale schema cache; see the
  // class docs above): scalar columns are selected and referenced display
  // data is resolved via the batched lookup helpers above.

  /// Select fragment for `commerce.stock_registry` — scalar columns only.
  static const String _stockSelectQuery = '''
    id, entity_id, variant_id, product_id, unit_id, location_id,
    quantity, reserved_quantity, status
  ''';

  /// Fetch managed stock owned by the authenticated user (RLS-scoped).
  ///
  /// Only `active` records with positive on-hand quantity are returned.
  /// Availability (`quantity - reserved_quantity > 0`) is enforced
  /// client-side by the repository enrichment layer.
  Future<List<Map<String, dynamic>>> fetchManagedStock() async {
    try {
      final response = await _client
          .schema('commerce')
          .from('stock_registry')
          .select(_stockSelectQuery)
          .eq('status', 'active')
          .gt('quantity', 0)
          .order('updated_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch managed stock: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch managed stock: $e');
    }
  }

  /// Fetch a single managed stock record by id (RLS-scoped).
  Future<Map<String, dynamic>?> fetchManagedStockById(String stockId) async {
    try {
      final response = await _client
          .schema('commerce')
          .from('stock_registry')
          .select(_stockSelectQuery)
          .eq('id', stockId)
          .maybeSingle();
      return response;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch managed stock: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch managed stock: $e');
    }
  }

  /// Publish a listing from managed stock via the
  /// `marketplace.publish_listing_from_stock` RPC.
  ///
  /// The client only supplies the stock id, price, title, description and
  /// images. entity_id / variant_id / unit_id / location_id / quantity are
  /// resolved server-side under RLS — the client never inserts into
  /// `marketplace.listings` directly.
  ///
  /// NOTE: `PostgrestException` is deliberately NOT wrapped so callers can
  /// map error codes/messages (unique violation, insufficient stock,
  /// unauthorized, invalid price) for user-friendly handling.
  Future<Map<String, dynamic>?> publishListingFromStock({
    required String stockId,
    required double pricePerUnit,
    String? title,
    String? description,
    required List<String> images,
  }) async {
    final params = <String, dynamic>{
      'p_stock_id': stockId,
      'p_price_per_unit': pricePerUnit,
      if (title != null && title.trim().isNotEmpty) 'p_title': title.trim(),
      if (description != null && description.trim().isNotEmpty)
        'p_description': description.trim(),
      'p_images': images,
    };
    final response = await _client
        .schema('marketplace')
        .rpc('publish_listing_from_stock', params: params);
    // The RPC may return the created listing (RETURNING), a row set, or
    // nothing at all. Parse defensively.
    if (response is Map<String, dynamic>) return response;
    if (response is List && response.isNotEmpty) {
      final first = response.first;
      if (first is Map<String, dynamic>) return first;
    }
    return null;
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
    Map<String, dynamic> payload,
  ) async {
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
    String id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _client
          .schema('marketplace')
          .from('listings')
          .update({...payload, 'updated_at': DateTime.now().toIso8601String()})
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
      await _client
          .schema('marketplace')
          .from('listings')
          .update({
            'status': 'archived',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
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
          .schema('marketplace')
          .from('listings')
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
      final active = listings.where((l) => l['status'] == 'active').length;
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

  // ════════════════════════════════════════════════════════════════
  // LISTING EDIT — CANONICAL MUTATION RPCS
  // ════════════════════════════════════════════════════════════════
  //
  // Editing existing listings is limited to the two deployed canonical RPCs:
  //   update_listing   (metadata only — title/description/price/currency)
  //   set_listing_status (active | inactive)
  //
  // PostgrestException is deliberately NOT wrapped so callers can map error
  // codes/messages (unauthorized, no stock, invalid value) into friendly UI
  // messages. No auth.uid()/entity_id/ownership claim is ever sent — the
  // backend authorizes via the authenticated session and can_manage.

  static const String updateListingRpc = 'update_listing';
  static const String setListingStatusRpc = 'set_listing_status';

  /// Update listing metadata via `marketplace.update_listing(uuid, jsonb)`.
  ///
  /// The jsonb payload is produced by [editableListingChangesPayload] so only
  /// changed editable fields (title / description / price_per_unit / currency)
  /// are ever transmitted.
  Future<Map<String, dynamic>?> updateListingDetails({
    required String listingId,
    required ListingEditChanges changes,
  }) async {
    final response = await _client
        .schema('marketplace')
        .rpc(
          updateListingRpc,
          params: {
            'p_listing_id': listingId,
            'p_changes': editableListingChangesPayload(changes),
          },
        );
    return MarketplaceRemoteDataSource._firstListingRow(response);
  }

  /// Set a listing's status via `marketplace.set_listing_status(uuid, text)`.
  ///
  /// Only `active` and `inactive` are supported by the backend. Activation is
  /// stock-validated server-side (stock_registry.quantity > 0).
  Future<Map<String, dynamic>?> setListingStatus({
    required String listingId,
    required String status,
  }) async {
    final response = await _client
        .schema('marketplace')
        .rpc(
          setListingStatusRpc,
          params: {'p_listing_id': listingId, 'p_status': status},
        );
    return MarketplaceRemoteDataSource._firstListingRow(response);
  }

  /// Defensively extracts a single listing row from an RPC response that may
  /// be a bare row map, a `{ data: [...] }` envelope, an empty list, or null.
  static Map<String, dynamic>? _firstListingRow(dynamic response) {
    if (response is Map<String, dynamic>) return response;
    if (response is Map) return Map<String, dynamic>.from(response);
    if (response is List) {
      for (final item in response) {
        if (item is Map<String, dynamic>) return item;
        if (item is Map) return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }

  // ════════════════════════════════════════════════════════════════
  // LISTING MEDIA (HARDENED EDGE-FUNCTION CONTRACT)
  // ════════════════════════════════════════════════════════════════
  //
  // Listing images live in the PRIVATE media bucket and are reached only
  // through the deployed edge functions:
  //   upload_media        (multipart; context="listings", context_id)
  //   media_get_by_context(returns signed URLs)
  //   delete_media        (file_id)
  //
  // The client never touches Storage directly, never sends user_id/entity_id
  // as an authorization mechanism, and never builds storage paths.
  //
  // Context contract:
  //   context    = "listings"
  //   context_id = marketplace.listings.id

  static const String _listingMediaContextType = 'listings';
  static const String _uploadMediaFunction = 'upload_media';
  static const String _mediaGetByContextFunction = 'media_get_by_context';
  static const String _deleteMediaFunction = 'delete_media';

  /// Upload a single WebP listing image to the authenticated user's listing.
  ///
  /// The authenticated backend derives the user and attaches the uploaded
  /// media to the listing's images through the trusted flow — the client
  /// never writes `listing.images`.
  Future<void> uploadListingMedia({
    required Uint8List bytes,
    required String fileName,
    required String listingId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        _uploadMediaFunction,
        body: {'context': _listingMediaContextType, 'context_id': listingId},
        files: [
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName,
            contentType: MediaType('image', 'webp'),
          ),
        ],
      );
      final reason = MarketplaceRemoteDataSource.uploadFailureReason(
        response.data,
      );
      if (reason != null) {
        throw Exception(_describeMediaError('Photo upload failed', reason));
      }
    } on FunctionException catch (e) {
      throw Exception(_describeMediaFunctionError('Photo upload failed', e));
    }
  }

  /// Retrieve signed URLs for a listing's media via `media_get_by_context`.
  Future<List<String>> fetchListingMediaUrls(String listingId) async {
    final entries = await fetchListingMediaEntries(listingId);
    return [
      for (final entry in entries)
        if (entry['url'] != null) entry['url']!,
    ];
  }

  /// Retrieve a listing's media entries (id + signed URL) via
  /// `media_get_by_context`.
  Future<List<Map<String, String>>> fetchListingMediaEntries(
    String listingId,
  ) async {
    try {
      final response = await _client.functions.invoke(
        _mediaGetByContextFunction,
        body: {'context': _listingMediaContextType, 'context_id': listingId},
      );
      return MarketplaceRemoteDataSource.mediaFileEntries(response.data);
    } on FunctionException catch (e) {
      // ignore: avoid_print
      print('[media_get_by_context] status=${e.status} '
          'details=${e.details} reason=${e.reasonPhrase}');
      // A 404 means this context has no media yet (e.g. a freshly published
      // listing with no photos). Treat it as an empty album so the seller can
      // still add the first photo.
      if (e.status == 404) return const [];
      throw Exception(
        _describeMediaFunctionError('Failed to load listing photos', e),
      );
    }
  }

  /// Delete a listing image by `media.files.id` via `delete_media`.
  ///
  /// The backend handles ownership, detach, soft delete and Storage cleanup.
  Future<void> deleteListingMedia(String fileId) async {
    try {
      final response = await _client.functions.invoke(
        _deleteMediaFunction,
        body: {'file_id': fileId},
      );
      final reason = MarketplaceRemoteDataSource.deleteFailureReason(
        response.data,
      );
      if (reason != null) {
        throw Exception(_describeMediaError('Photo removal failed', reason));
      }
    } on FunctionException catch (e) {
      throw Exception(_describeMediaFunctionError('Photo removal failed', e));
    }
  }

  /// Returns a non-null reason when an `upload_media` payload did not confirm
  /// success.
  static String? uploadFailureReason(dynamic payload) {
    if (payload is Map) {
      if (payload['success'] == true) return null;
      return payload['error']?.toString() ??
          payload['message']?.toString() ??
          'The server rejected the photo.';
    }
    if (payload == null) return 'No response from the server.';
    return 'Unexpected response from the server.';
  }

  /// Returns a non-null reason when a `delete_media` payload did not confirm
  /// success.
  static String? deleteFailureReason(dynamic payload) {
    if (payload is Map) {
      if (payload['success'] == true) return null;
      return payload['error']?.toString() ??
          payload['message']?.toString() ??
          'The photo could not be removed.';
    }
    if (payload == null) return 'No response from the server.';
    return 'Unexpected response from the server.';
  }

  /// Normalizes a `media_get_by_context` payload into ordered media entries.
  ///
  /// Accepts both a bare list and a `{data|media|files: [...]}` envelope.
  /// Each entry exposes an `id` (media.files.id) and an http(s) `url`
  /// (temporary signed URL). Non-http references are dropped — the signed URL
  /// is the only displayable form.
  static List<Map<String, String>> mediaFileEntries(dynamic payload) {
    final List<dynamic> raw;
    if (payload is List) {
      raw = payload;
    } else if (payload is Map) {
      final inner = payload['data'] ?? payload['media'] ?? payload['files'];
      raw = inner is List ? inner : const [];
    } else {
      raw = const [];
    }

    final entries = <Map<String, String>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final url = (item['url'] ?? item['signed_url'] ?? item['public_url'])
          ?.toString();
      final lower = url?.toLowerCase() ?? '';
      if (lower.isEmpty ||
          (!lower.startsWith('http://') && !lower.startsWith('https://'))) {
        continue;
      }
      final id = (item['id'] ?? item['file_id'] ?? item['media_id'])
          ?.toString();
      entries.add({'url': url!, if (id != null && id.isNotEmpty) 'id': id});
    }
    return entries;
  }

  static String _describeMediaError(String action, String reason) {
    return '$action: $reason';
  }

  static String _describeMediaFunctionError(
    String action,
    FunctionException e,
  ) {
    if (e.status == 401) {
      return '$action: your session has expired. Sign in and try again.';
    }
    if (e.status == 403) {
      return '$action: you do not have permission to do this.';
    }
    final details = e.details?.toString();
    if (details != null && details.isNotEmpty) {
      return '$action: $details';
    }
    return '$action: please try again.';
  }
}
