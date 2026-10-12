/// ============================================================
/// FINANCING CATALOGUE — REMOTE DATA SOURCE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/financing/infrastructure/data_sources/ = infrastructure
///
/// ✅ Responsibilities:
///   - Read the Phase 1 catalogue from the exact objects the migration
///     defines, selecting only the columns each surface is allowed to see.
///
/// ❌ Does NOT:
///   - Select `metadata`, `verification_notes`, `approval_notes`,
///     `verified_by`, `approved_by`, `published_by` or `created_by`.
///     Those columns are never part of the frontend surface, regardless of
///     what RLS would allow.
///   - Fall back to mock, cached or invented data when a relation is missing.
///
/// MISSING-RELATION HANDLING (migration not yet deployed): PostgREST answers
/// with PGRST202 / PGRST205 / 42883 / 42P01. Those are re-thrown as
/// [FinancingCatalogueUnavailableException] so the UI can say "catalogue not
/// deployed yet" instead of showing a broken screen. Nothing else is
/// swallowed.
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/financing/domain/models/financing_catalogue_models.dart';
import 'package:famhub_app/features/financing/domain/repositories/financing_catalogue_repository.dart';
import 'package:famhub_app/features/financing/domain/models/finance_models.dart';
import 'package:famhub_app/features/financing/infrastructure/data_sources/financing_rpc_gateway.dart';

/// Column lists — each mirrors its object's declared column set exactly.
abstract final class FinancingColumns {
  /// `financing.public_financial_providers` — curated, reviewer-free.
  static const String publicProvider =
      'id, slug, name, provider_type, description, logo_url, website_url, '
      'country_code, is_active, verification_status, created_at, updated_at';

  /// `financing.public_financial_products` — curated, reviewer-free.
  static const String publicProduct =
      'id, provider_id, slug, name, product_type, summary, description, '
      'currency, min_amount, max_amount, interest_rate, interest_rate_type, '
      'min_tenure_days, max_tenure_days, requires_collateral, requirements, '
      'is_active, is_published, created_at, updated_at';

  /// `financing.financial_providers` (table, RLS-gated).
  /// Deliberately excludes metadata, verification_notes, verified_by, created_by.
  static const String managedProvider =
      'id, slug, name, provider_type, description, logo_url, website_url, '
      'contact_email, contact_phone, country_code, is_active, '
      'verification_status, verified_at, created_at, updated_at';

  /// `financing.financial_products` (table, RLS-gated).
  /// Deliberately excludes metadata, approval_notes, approved_by, published_by,
  /// created_by.
  static const String managedProduct =
      'id, provider_id, slug, name, product_type, summary, description, '
      'currency, min_amount, max_amount, interest_rate, interest_rate_type, '
      'min_tenure_days, max_tenure_days, requires_collateral, requirements, '
      'is_active, is_published, approval_status, approved_at, published_at, '
      'created_at, updated_at';
}

class FinancingCatalogueRemoteDataSource {
  FinancingCatalogueRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // ── Browse: public views ────────────────────────────────────────────────

  Future<List<FinancingProvider>> fetchBrowseProviders({
    int limit = 100,
    FinancialPartnerType? providerType,
  }) async {
    return _guard(() async {
      var query = _client
          .schema(financingSchema)
          .from('public_financial_providers')
          .select(FinancingColumns.publicProvider)
          .eq('is_active', true)
          .eq('verification_status', 'verified');
      if (providerType != null) {
        query = query.eq('provider_type', partnerTypeToDb(providerType));
      }
      final rows = await query
          .order('name', ascending: true)
          .limit(limit);
      return rows.map(FinancingProvider.fromMap).toList();
    });
  }

  Future<List<FinancingProduct>> fetchBrowseProducts({
    int limit = 200,
    String? providerId,
    FinancingProductType? productType,
  }) async {
    return _guard(() async {
      var query = _client
          .schema(financingSchema)
          .from('public_financial_products')
          .select(FinancingColumns.publicProduct)
          .eq('is_active', true)
          .eq('is_published', true);
      if (providerId != null && providerId.isNotEmpty) {
        query = query.eq('provider_id', providerId);
      }
      if (productType != null) {
        query = query.eq('product_type', productType.dbValue);
      }
      final rows = await query.order('name', ascending: true).limit(limit);
      return rows.map(FinancingProduct.fromMap).toList();
    });
  }

  // ── Management: permission-gated tables ─────────────────────────────────

  Future<List<FinancingProvider>> fetchManagedProviders({
    int limit = 200,
    String? verificationStatus,
  }) async {
    return _guard(() async {
      var query = _client
          .schema(financingSchema)
          .from('financial_providers')
          .select(FinancingColumns.managedProvider);
      if (verificationStatus != null && verificationStatus.isNotEmpty) {
        query = query.eq('verification_status', verificationStatus);
      }
      final rows = await query
          .order('updated_at', ascending: false)
          .limit(limit);
      return rows.map(FinancingProvider.fromMap).toList();
    });
  }

  Future<List<FinancingProduct>> fetchManagedProducts({
    int limit = 200,
    String? providerId,
    String? approvalStatus,
  }) async {
    return _guard(() async {
      var query = _client
          .schema(financingSchema)
          .from('financial_products')
          .select(FinancingColumns.managedProduct);
      if (providerId != null && providerId.isNotEmpty) {
        query = query.eq('provider_id', providerId);
      }
      if (approvalStatus != null && approvalStatus.isNotEmpty) {
        query = query.eq('approval_status', approvalStatus);
      }
      final rows = await query
          .order('updated_at', ascending: false)
          .limit(limit);
      return rows.map(FinancingProduct.fromMap).toList();
    });
  }

  // ── Error translation ───────────────────────────────────────────────────

  /// Maps "the migration isn't here" to a typed, renderable exception.
  ///
  /// Nothing else is translated here: authorization and lifecycle errors from
  /// the RPC gateway reach the UI untouched so they can be mapped by code.
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      if (_isMissingRelation(e)) {
        throw const FinancingCatalogueUnavailableException(
          'The financing catalogue is not available in this environment yet.',
        );
      }
      rethrow;
    }
  }

  static bool _isMissingRelation(PostgrestException e) {
    final code = e.code ?? '';
    // PGRST202 = schema/relation not exposed, PGRST205 = relation not found,
    // 42883 = undefined function, 42P01 = undefined table.
    if (code == 'PGRST202' ||
        code == 'PGRST205' ||
        code == '42883' ||
        code == '42P01') {
      return true;
    }
    final text = e.message.toLowerCase();
    return text.contains('does not exist') ||
        text.contains('schema cache') ||
        text.contains('could not find the function');
  }
}
