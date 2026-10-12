/// ============================================================
/// FINANCING — RPC GATEWAY (EXACT BACKEND CONTRACT)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/financing/infrastructure/data_sources/ = infrastructure
///
/// ✅ Responsibilities:
///   - Own the literal RPC names, parameter names and payload shapes defined
///     by `supabase/migrations/20261012000001_financing_provider_product_catalog.sql`.
///
/// ❌ Does NOT:
///   - Invent alternative names, extra parameters or client-side defaults the
///     backend does not declare. Every write goes through these RPCs; direct
///     table writes are impossible (the migration grants no INSERT/UPDATE/
///     DELETE to any API role).
///
/// All eight mutating RPCs are `SECURITY DEFINER`, granted to
/// `authenticated` + `service_role` only, and take no actor id — the backend
/// derives the actor from the session and authorizes via
/// `financing._require_permission(...)`.
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Schema the catalogue objects live in. Matches the migration exactly.
const String financingSchema = 'financing';

/// Literal RPC names from the migration. Never invent alternatives.
abstract final class FinancingRpcNames {
  // Provider lifecycle
  static const String manageProvider = 'manage_provider';
  static const String setProviderVerification = 'set_provider_verification';

  // Product lifecycle
  static const String manageProduct = 'manage_product';
  static const String reopenProductForEdit = 'reopen_product_for_edit';
  static const String submitProductForReview = 'submit_product_for_review';
  static const String reviewProduct = 'review_product';
  static const String publishProduct = 'publish_product';
  static const String unpublishProduct = 'unpublish_product';
}

/// Contract of the eight write RPCs. Kept separate from reads so the
/// repository can depend on an injectable seam (this is the test double point).
abstract class FinancingRpcGateway {
  /// `financing.manage_provider(...) -> uuid`
  /// Create when [providerId] is null, otherwise update.
  Future<String> manageProvider({
    String? providerId,
    String? slug,
    required String name,
    required String providerType,
    String? description,
    String? logoUrl,
    String? websiteUrl,
    String? contactEmail,
    String? contactPhone,
    String? countryCode,
    Map<String, dynamic>? metadata,
    bool? isActive,
  });

  /// `financing.set_provider_verification(p_provider_id, p_verification_status, p_notes) -> uuid`
  Future<String> setProviderVerification({
    required String providerId,
    required String verificationStatus,
    String? notes,
  });

  /// `financing.manage_product(...) -> uuid`
  Future<String> manageProduct({
    String? productId,
    String? providerId,
    String? slug,
    required String name,
    required String productType,
    String? summary,
    String? description,
    String? currency,
    double? minAmount,
    double? maxAmount,
    double? interestRate,
    String? interestRateType,
    int? minTenureDays,
    int? maxTenureDays,
    bool? requiresCollateral,
    List<String>? requirements,
    Map<String, dynamic>? metadata,
    bool? isActive,
  });

  Future<String> reopenProductForEdit({required String productId});

  Future<String> submitProductForReview({required String productId});

  /// `financing.review_product(p_product_id, p_approved, p_notes) -> uuid`
  /// [approved] must be a non-null boolean — the backend rejects NULL with
  /// SQLSTATE 22023, so it is non-nullable here too.
  Future<String> reviewProduct({
    required String productId,
    required bool approved,
    String? notes,
  });

  Future<String> publishProduct({required String productId});

  Future<String> unpublishProduct({required String productId});
}

/// Default implementation: raw Supabase RPC calls against `financing`.
class SupabaseFinancingRpcGateway implements FinancingRpcGateway {
  SupabaseFinancingRpcGateway({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _c => _client ?? Supabase.instance.client;

  Future<String> _call(String function, Map<String, dynamic> params) async {
    final dynamic response = await _c.schema(financingSchema).rpc(function, params: params);
    return _extractId(response, function);
  }

  /// PostgREST returns a `RETURNS uuid` value as a bare string, a
  /// single-element array or a wrapped object — normalize all three, exactly
  /// the way the established Logistics gateway does.
  static String _extractId(dynamic response, String function) {
    if (response is String && response.isNotEmpty) return response;
    if (response is Map) {
      for (final key in ['id', function, 'p_provider_id', 'p_product_id']) {
        final value = response[key];
        if (value is String && value.isNotEmpty) return value;
      }
      if (response.length == 1) {
        final value = response.values.first;
        if (value is String && value.isNotEmpty) return value;
      }
    }
    if (response is List && response.isNotEmpty) {
      final first = response.first;
      if (first is String && first.isNotEmpty) return first;
      if (first is Map) return _extractId(first, function);
    }
    throw StateError('RPC "$function" returned no identifier.');
  }

  @override
  Future<String> manageProvider({
    String? providerId,
    String? slug,
    required String name,
    required String providerType,
    String? description,
    String? logoUrl,
    String? websiteUrl,
    String? contactEmail,
    String? contactPhone,
    String? countryCode,
    Map<String, dynamic>? metadata,
    bool? isActive,
  }) {
    return _call(FinancingRpcNames.manageProvider, {
      if (providerId != null) 'p_provider_id': providerId,
      'p_slug': slug,
      'p_name': name,
      'p_provider_type': providerType,
      'p_description': description,
      'p_logo_url': logoUrl,
      'p_website_url': websiteUrl,
      'p_contact_email': contactEmail,
      'p_contact_phone': contactPhone,
      if (countryCode != null) 'p_country_code': countryCode,
      if (metadata != null) 'p_metadata': metadata,
      if (isActive != null) 'p_is_active': isActive,
    });
  }

  @override
  Future<String> setProviderVerification({
    required String providerId,
    required String verificationStatus,
    String? notes,
  }) {
    return _call(FinancingRpcNames.setProviderVerification, {
      'p_provider_id': providerId,
      'p_verification_status': verificationStatus,
      if (notes != null) 'p_notes': notes,
    });
  }

  @override
  Future<String> manageProduct({
    String? productId,
    String? providerId,
    String? slug,
    required String name,
    required String productType,
    String? summary,
    String? description,
    String? currency,
    double? minAmount,
    double? maxAmount,
    double? interestRate,
    String? interestRateType,
    int? minTenureDays,
    int? maxTenureDays,
    bool? requiresCollateral,
    List<String>? requirements,
    Map<String, dynamic>? metadata,
    bool? isActive,
  }) {
    return _call(FinancingRpcNames.manageProduct, {
      if (productId != null) 'p_product_id': productId,
      if (providerId != null) 'p_provider_id': providerId,
      'p_slug': slug,
      'p_name': name,
      'p_product_type': productType,
      'p_summary': summary,
      'p_description': description,
      if (currency != null) 'p_currency': currency,
      'p_min_amount': minAmount,
      'p_max_amount': maxAmount,
      'p_interest_rate': interestRate,
      'p_interest_rate_type': interestRateType,
      'p_min_tenure_days': minTenureDays,
      'p_max_tenure_days': maxTenureDays,
      if (requiresCollateral != null) 'p_requires_collateral': requiresCollateral,
      if (requirements != null) 'p_requirements': requirements,
      if (metadata != null) 'p_metadata': metadata,
      if (isActive != null) 'p_is_active': isActive,
    });
  }

  @override
  Future<String> reopenProductForEdit({required String productId}) {
    return _call(FinancingRpcNames.reopenProductForEdit, {'p_product_id': productId});
  }

  @override
  Future<String> submitProductForReview({required String productId}) {
    return _call(FinancingRpcNames.submitProductForReview, {'p_product_id': productId});
  }

  @override
  Future<String> reviewProduct({
    required String productId,
    required bool approved,
    String? notes,
  }) {
    return _call(FinancingRpcNames.reviewProduct, {
      'p_product_id': productId,
      'p_approved': approved,
      if (notes != null) 'p_notes': notes,
    });
  }

  @override
  Future<String> publishProduct({required String productId}) {
    return _call(FinancingRpcNames.publishProduct, {'p_product_id': productId});
  }

  @override
  Future<String> unpublishProduct({required String productId}) {
    return _call(FinancingRpcNames.unpublishProduct, {'p_product_id': productId});
  }
}
