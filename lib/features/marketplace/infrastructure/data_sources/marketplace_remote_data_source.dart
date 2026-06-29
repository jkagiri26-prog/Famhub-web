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
/// Handles all Supabase queries for the `listings` table.
/// All queries are scoped via RLS — no user_id from frontend.
class MarketplaceRemoteDataSource {
  final SupabaseClient _client;

  MarketplaceRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Fetch all listings (with optional filters).
  Future<List<Map<String, dynamic>>> fetchListings({
    String? category,
    String? searchQuery,
    String? sellerId,
    String? statusFilter,
  }) async {
    try {
      var query = _client.from('listings').select();

      // Apply filters at DB level
      if (statusFilter != null && statusFilter.isNotEmpty) {
        final statusValues = statusFilter;
        query = query.or('status.in.($statusValues)');
      } else {
        // Default: hide archived
        query = query.not('status', 'eq', 'archived');
      }

      if (category != null && category != 'ALL') {
        query = query.eq('category', category);
      }

      if (sellerId != null) {
        query = query.eq('seller_id', sellerId);
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
          .from('listings')
          .select()
          .eq('id', id)
          .maybeSingle();
      return response;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch listing: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch listing: $e');
    }
  }

  /// Create a new listing.
  Future<Map<String, dynamic>> createListing(
      Map<String, dynamic> payload) async {
    try {
      final response = await _client
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
          .from('listings')
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
      await _client.from('listings').update({
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

  /// Update inventory quantities.
  Future<void> updateInventory({
    required String listingId,
    double? availableQuantity,
    double? soldQuantity,
    double? reservedQuantity,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (availableQuantity != null) {
        updates['available_quantity'] = availableQuantity;
      }
      if (soldQuantity != null) updates['sold_quantity'] = soldQuantity;
      if (reservedQuantity != null) {
        updates['reserved_quantity'] = reservedQuantity;
      }
      updates['updated_at'] = DateTime.now().toIso8601String();

      // Auto-mark sold_out if available reaches zero
      if (availableQuantity != null && availableQuantity <= 0) {
        updates['status'] = 'sold_out';
      }

      await _client.from('listings').update(updates).eq('id', listingId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update inventory: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update inventory: $e');
    }
  }

  /// Get seller listing stats.
  Future<Map<String, dynamic>> fetchSellerStats(String sellerId) async {
    try {
      final response = await _client
          .from('listings')
          .select()
          .eq('seller_id', sellerId);

      final listings = (response as List).cast<Map<String, dynamic>>();
      final active =
          listings.where((l) => l['status'] == 'active').length;
      final total = listings.length;
      final totalSold = listings.fold<double>(
          0,
          (sum, l) =>
              sum + ((l['sold_quantity'] as num?)?.toDouble() ?? 0));

      return {
        'total_listings': total,
        'active_listings': active,
        'total_sold': totalSold,
      };
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch seller stats: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch seller stats: $e');
    }
  }
}
