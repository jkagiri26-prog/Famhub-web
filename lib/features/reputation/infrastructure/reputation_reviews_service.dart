import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/my_reputation_state.dart';
import '../domain/models/reputation_rating_summary.dart';
import '../domain/models/reputation_review.dart';

class ReputationReviewsService {
  final SupabaseClient _client;

  ReputationReviewsService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  bool get isSignedIn => _client.auth.currentUser != null;

  String? _asId(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    if (value is List && value.isNotEmpty) return _asId(value.first);
    if (value is Map && value.isNotEmpty) {
      for (final key in const ['id', 'subject_id', 'value']) {
        final found = _asId(value[key]);
        if (found != null) return found;
      }
    }
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  Future<String?> resolveProductSubject(String variantId) async {
    if (variantId.isEmpty) return null;
    try {
      return _asId(
        await _client
            .schema('system')
            .rpc(
              'resolve_reputation_product_subject',
              params: {'p_variant_id': variantId},
            ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> resolveSellerSubject(String entityId) async {
    if (entityId.isEmpty) return null;
    try {
      return _asId(
        await _client
            .schema('system')
            .rpc(
              'resolve_reputation_seller_subject',
              params: {'p_entity_id': entityId},
            ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> ensureProductSubject(String variantId) async {
    final value = await _client
        .schema('system')
        .rpc(
          'ensure_reputation_product_subject',
          params: {'p_variant_id': variantId},
        );
    final id = _asId(value);
    if (id == null) throw StateError('Could not resolve product subject');
    return id;
  }

  Future<String> ensureSellerSubject(String entityId) async {
    final value = await _client
        .schema('system')
        .rpc(
          'ensure_reputation_seller_subject',
          params: {'p_entity_id': entityId},
        );
    final id = _asId(value);
    if (id == null) throw StateError('Could not resolve seller subject');
    return id;
  }

  Future<ReputationRatingSummary?> fetchSummary(String subjectId) async {
    final response = await _client
        .schema('system')
        .rpc(
          'get_reputation_rating_summary',
          params: {'p_subject_id': subjectId},
        );
    if (response is List && response.isNotEmpty) {
      final row = response.first;
      if (row is Map) {
        return ReputationRatingSummary.fromJson(
          Map<String, dynamic>.from(row),
        );
      }
    }
    if (response is Map) {
      return ReputationRatingSummary.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    return null;
  }

  Future<List<ReputationReview>> fetchReviews(
    String subjectId, {
    DateTime? cursorCreatedAt,
    String? cursorId,
    int limit = 20,
  }) async {
    final response = await _client
        .schema('system')
        .rpc(
          'list_reputation_reviews',
          params: {
            'p_subject_id': subjectId,
            'p_cursor_created_at': cursorCreatedAt?.toUtc().toIso8601String(),
            'p_cursor_id': cursorId,
            'p_limit': limit,
          },
        );
    if (response is! List) return const [];
    return response
        .whereType<Map>()
        .map((row) => ReputationReview.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<MyReputationState?> fetchMyState(String subjectId) async {
    if (!isSignedIn) return null;
    try {
      final response = await _client
          .schema('system')
          .rpc(
            'get_my_reputation_subject_state',
            params: {'p_subject_id': subjectId},
          );
      if (response is List && response.isNotEmpty) {
        final row = response.first;
        if (row is Map) {
          final state = MyReputationState.fromJson(
            Map<String, dynamic>.from(row),
          );
          if (state.ratingId == null && state.reviewId == null) return null;
          return state;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> submitRating({
    required String subjectId,
    required int rating,
    String? engagementId,
  }) async {
    await _client
        .schema('system')
        .rpc(
          'submit_reputation_rating',
          params: {
            'p_subject_id': subjectId,
            'p_rating': rating,
            'p_engagement_id': engagementId,
          },
        );
  }

  Future<void> editRating({required String ratingId, required int rating}) async {
    await _client
        .schema('system')
        .rpc(
          'edit_reputation_rating',
          params: {'p_rating_id': ratingId, 'p_rating': rating},
        );
  }

  Future<void> submitReview({
    required String subjectId,
    required String body,
    String? title,
    String? ratingId,
    String? engagementId,
    String publicIdentityMode = 'display_name',
  }) async {
    await _client
        .schema('system')
        .rpc(
          'submit_reputation_review',
          params: {
            'p_subject_id': subjectId,
            'p_body': body,
            'p_title': title,
            'p_rating_id': ratingId,
            'p_engagement_id': engagementId,
            'p_public_identity_mode': publicIdentityMode,
          },
        );
  }

  Future<void> editReview({
    required String reviewId,
    required String body,
    String? title,
    String? ratingId,
    String publicIdentityMode = 'display_name',
  }) async {
    await _client
        .schema('system')
        .rpc(
          'edit_reputation_review',
          params: {
            'p_review_id': reviewId,
            'p_body': body,
            'p_title': title,
            'p_rating_id': ratingId,
            'p_public_identity_mode': publicIdentityMode,
          },
        );
  }

  Future<void> respondToReview({
    required String reviewId,
    required String body,
  }) async {
    await _client
        .schema('system')
        .rpc(
          'respond_to_reputation_review',
          params: {'p_review_id': reviewId, 'p_body': body},
        );
  }
}
