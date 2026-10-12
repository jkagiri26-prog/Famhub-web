/// ============================================================
/// FINANCING CATALOGUE REPOSITORY (INFRASTRUCTURE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/financing/infrastructure/repositories/ = implementation
///
/// ✅ Responsibilities:
///   - Delegate reads to the remote data source.
///   - Delegate writes to the RPC gateway.
///   - Translate backend SQLSTATEs into typed domain exceptions.
///
/// ❌ Does NOT:
///   - Grant anything, cache results, or fall back to fabricated data.
///
/// ERROR TRANSLATION
///   42501 → FinancingActionException(isUnauthorized)  — permission not seeded
///   P0002 → FinancingActionException(isNotFound)
///   22023 → FinancingActionException(isInvalid)
///   55000 → FinancingActionException(isLifecycleBlocked)
///   23505 → FinancingActionException — slug-specific copy when the conflict
///           came from `*_slug_key`, so the operator knows which field to fix
///   missing RPC → FinancingCatalogueUnavailableException
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/financing/domain/models/finance_models.dart';
import 'package:famhub_app/features/financing/domain/models/financing_catalogue_models.dart';
import 'package:famhub_app/features/financing/domain/repositories/financing_catalogue_repository.dart';
import 'package:famhub_app/features/financing/infrastructure/data_sources/financing_catalogue_remote_data_source.dart';
import 'package:famhub_app/features/financing/infrastructure/data_sources/financing_rpc_gateway.dart';

class FinancingCatalogueRepositoryImpl implements FinancingCatalogueRepository {
  FinancingCatalogueRepositoryImpl({
    required FinancingCatalogueRemoteDataSource dataSource,
    FinancingRpcGateway? rpc,
  })  : _dataSource = dataSource,
        _rpc = rpc ?? SupabaseFinancingRpcGateway();

  final FinancingCatalogueRemoteDataSource _dataSource;
  final FinancingRpcGateway _rpc;

  // ── Reads ───────────────────────────────────────────────────────────────

  @override
  Future<List<FinancingProvider>> fetchBrowseProviders({
    int limit = 100,
    FinancialPartnerType? providerType,
  }) {
    return _dataSource.fetchBrowseProviders(limit: limit, providerType: providerType);
  }

  @override
  Future<List<FinancingProduct>> fetchBrowseProducts({
    int limit = 200,
    String? providerId,
    FinancingProductType? productType,
  }) {
    return _dataSource.fetchBrowseProducts(
      limit: limit,
      providerId: providerId,
      productType: productType,
    );
  }

  @override
  Future<List<FinancingProvider>> fetchManagedProviders({
    int limit = 200,
    String? verificationStatus,
  }) {
    return _dataSource.fetchManagedProviders(
      limit: limit,
      verificationStatus: verificationStatus,
    );
  }

  @override
  Future<List<FinancingProduct>> fetchManagedProducts({
    int limit = 200,
    String? providerId,
    String? approvalStatus,
  }) {
    return _dataSource.fetchManagedProducts(
      limit: limit,
      providerId: providerId,
      approvalStatus: approvalStatus,
    );
  }

  // ── Provider actions ────────────────────────────────────────────────────

  @override
  Future<String> saveProvider({
    String? providerId,
    String? slug,
    required String name,
    required FinancialPartnerType providerType,
    String? description,
    String? logoUrl,
    String? websiteUrl,
    String? contactEmail,
    String? contactPhone,
    String? countryCode,
    bool? isActive,
  }) {
    return _guard(() => _rpc.manageProvider(
          providerId: providerId,
          slug: slug,
          name: name,
          providerType: partnerTypeToDb(providerType),
          description: description,
          logoUrl: logoUrl,
          websiteUrl: websiteUrl,
          contactEmail: contactEmail,
          contactPhone: contactPhone,
          countryCode: countryCode,
          isActive: isActive,
        ));
  }

  @override
  Future<String> verifyProvider({
    required String providerId,
    required FinancingVerificationStatus status,
    String? notes,
  }) {
    return _guard(() => _rpc.setProviderVerification(
          providerId: providerId,
          verificationStatus: status.dbValue,
          notes: notes,
        ));
  }

  // ── Product actions ─────────────────────────────────────────────────────

  @override
  Future<String> saveProduct({
    String? productId,
    String? providerId,
    String? slug,
    required String name,
    required FinancingProductType productType,
    String? summary,
    String? description,
    String? currency,
    double? minAmount,
    double? maxAmount,
    double? interestRate,
    FinancingRateType? interestRateType,
    int? minTenureDays,
    int? maxTenureDays,
    bool? requiresCollateral,
    List<String>? requirements,
    bool? isActive,
  }) {
    return _guard(() => _rpc.manageProduct(
          productId: productId,
          providerId: providerId,
          slug: slug,
          name: name,
          productType: productType.dbValue,
          summary: summary,
          description: description,
          currency: currency,
          minAmount: minAmount,
          maxAmount: maxAmount,
          interestRate: interestRate,
          interestRateType: interestRateType?.dbValue,
          minTenureDays: minTenureDays,
          maxTenureDays: maxTenureDays,
          requiresCollateral: requiresCollateral,
          requirements: requirements,
          isActive: isActive,
        ));
  }

  @override
  Future<String> reopenProduct({required String productId}) {
    return _guard(() => _rpc.reopenProductForEdit(productId: productId));
  }

  @override
  Future<String> submitProductForReview({required String productId}) {
    return _guard(() => _rpc.submitProductForReview(productId: productId));
  }

  @override
  Future<String> reviewProduct({
    required String productId,
    required bool approved,
    String? notes,
  }) {
    return _guard(
      () => _rpc.reviewProduct(productId: productId, approved: approved, notes: notes),
    );
  }

  @override
  Future<String> publishProduct({required String productId}) {
    return _guard(() => _rpc.publishProduct(productId: productId));
  }

  @override
  Future<String> unpublishProduct({required String productId}) {
    return _guard(() => _rpc.unpublishProduct(productId: productId));
  }

  // ── Error translation ───────────────────────────────────────────────────

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      if (_isMissingRpc(e)) {
        throw const FinancingCatalogueUnavailableException(
          'This catalogue action is not available in this environment yet.',
        );
      }
      throw FinancingActionException(_safeMessage(e), code: e.code);
    }
  }

  static bool _isMissingRpc(PostgrestException e) {
    final code = e.code ?? '';
    if (code == 'PGRST202' || code == 'PGRST205' || code == '42883') return true;
    final text = e.message.toLowerCase();
    return text.contains('could not find the function') ||
        text.contains('does not exist');
  }

  /// Never leak SQL, SECURITY DEFINER detail or function names to the UI.
  /// The SQLSTATE is carried separately in `code` for branching.
  static String _safeMessage(PostgrestException e) {
    final code = e.code ?? '';
    return switch (code) {
      '42501' => 'You do not have permission to perform this action.',
      'P0002' => 'That record was not found.',
      '22023' => e.message,
      '55000' => e.message,
      // `financial_providers_slug_key` / `financial_products_provider_slug_key`.
      // The constraint name and `details` are inspected but never shown.
      '23505' => _isSlugConflict(e)
          ? 'That slug is already used by another provider or product. '
              'Pick a different one.'
          : 'A record with that value already exists.',
      '23503' => 'That record is referenced by other data and cannot change.',
      '23514' => 'That value is not allowed for this field.',
      _ => 'The request could not be completed.',
    };
  }

  /// True when the 23505 came from a slug unique constraint. Only the
  /// constraint name (schema-qualified identifier, no user data) and the
  /// column name in `details` are inspected — neither is ever echoed back.
  static bool _isSlugConflict(PostgrestException e) {
    final haystack = '${e.message} ${e.details ?? ''}'.toLowerCase();
    return haystack.contains('slug');
  }
}
