/// ============================================================
/// FINANCING CATALOGUE — MANAGEMENT PROVIDERS + ACTIONS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/financing/application/providers/ = application layer
///
/// ✅ Responsibilities:
///   - Expose the permission-gated management reads.
///   - Expose one action object covering every backend RPC in the Phase 1
///     contract, invalidating the affected reads after each success.
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Every mutation is a backend RPC; there are no direct table writes.
///   - Actions rethrow the typed domain exceptions so the screen can branch
///     on `isUnauthorized` / `isLifecycleBlocked` / `isInvalid`.
///   - Nothing is invalidated on failure, so a refused action never leaves the
///     UI showing state the backend did not accept.
///
/// ❌ Does NOT:
///   - Grant permissions or bypass RLS
///   - Swallow backend errors
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/features/financing/application/providers/financing_catalogue_provider.dart';
import 'package:famhub_app/features/financing/domain/models/finance_models.dart';
import 'package:famhub_app/features/financing/domain/models/financing_catalogue_models.dart';
import 'package:famhub_app/features/financing/domain/repositories/financing_catalogue_repository.dart';

/// Providers visible to a `finance.manage_providers` /
/// `finance.verify_providers` caller. Empty for everyone else — the backend
/// RLS returns zero rows, which the UI renders as an empty state.
final financingManagedProvidersProvider =
    FutureProvider<List<FinancingProvider>>((ref) async {
  final context = ref.watch(contextProvider);
  if (context.isGuest) return const [];
  return ref.read(financingCatalogueRepositoryProvider).fetchManagedProviders();
});

/// Products visible to a `finance.manage_products` /
/// `finance.review_products` / `finance.publish_products` caller.
final financingManagedProductsProvider =
    FutureProvider<List<FinancingProduct>>((ref) async {
  final context = ref.watch(contextProvider);
  if (context.isGuest) return const [];
  return ref.read(financingCatalogueRepositoryProvider).fetchManagedProducts();
});

/// All catalogue RPC actions in one injectable object.
class FinancingCatalogueActions {
  FinancingCatalogueActions(this._repository, this._ref);

  final FinancingCatalogueRepository _repository;
  final Ref _ref;

  void _invalidateCatalogue() {
    _ref.invalidate(financingManagedProvidersProvider);
    _ref.invalidate(financingManagedProductsProvider);
    _ref.invalidate(financingBrowseProvidersProvider);
    _ref.invalidate(financingBrowseProductsProvider);
    _ref.invalidateSelf();
  }

  // ── Provider lifecycle ──────────────────────────────────────────────────

  /// `financing.manage_provider` — create when [providerId] is null.
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
  }) async {
    final id = await _repository.saveProvider(
      providerId: providerId,
      slug: slug,
      name: name,
      providerType: providerType,
      description: description,
      logoUrl: logoUrl,
      websiteUrl: websiteUrl,
      contactEmail: contactEmail,
      contactPhone: contactPhone,
      countryCode: countryCode,
      isActive: isActive,
    );
    _invalidateCatalogue();
    return id;
  }

  /// `financing.set_provider_verification`.
  /// Rejection/suspension also resets that provider's products to draft on the
  /// backend — which is why both product reads are invalidated together.
  Future<String> verifyProvider({
    required String providerId,
    required FinancingVerificationStatus status,
    String? notes,
  }) async {
    final id = await _repository.verifyProvider(
      providerId: providerId,
      status: status,
      notes: notes,
    );
    _invalidateCatalogue();
    return id;
  }

  // ── Product lifecycle ───────────────────────────────────────────────────

  /// `financing.manage_product` — create when [productId] is null.
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
  }) async {
    final id = await _repository.saveProduct(
      productId: productId,
      providerId: providerId,
      slug: slug,
      name: name,
      productType: productType,
      summary: summary,
      description: description,
      currency: currency,
      minAmount: minAmount,
      maxAmount: maxAmount,
      interestRate: interestRate,
      interestRateType: interestRateType,
      minTenureDays: minTenureDays,
      maxTenureDays: maxTenureDays,
      requiresCollateral: requiresCollateral,
      requirements: requirements,
      isActive: isActive,
    );
    _invalidateCatalogue();
    return id;
  }

  Future<String> reopenProduct(String productId) async {
    final id = await _repository.reopenProduct(productId: productId);
    _invalidateCatalogue();
    return id;
  }

  Future<String> submitProductForReview(String productId) async {
    final id = await _repository.submitProductForReview(productId: productId);
    _invalidateCatalogue();
    return id;
  }

  Future<String> reviewProduct({
    required String productId,
    required bool approved,
    String? notes,
  }) async {
    final id = await _repository.reviewProduct(
      productId: productId,
      approved: approved,
      notes: notes,
    );
    _invalidateCatalogue();
    return id;
  }

  Future<String> publishProduct(String productId) async {
    final id = await _repository.publishProduct(productId: productId);
    _invalidateCatalogue();
    return id;
  }

  Future<String> unpublishProduct(String productId) async {
    final id = await _repository.unpublishProduct(productId: productId);
    _invalidateCatalogue();
    return id;
  }
}

final financingCatalogueActionsProvider = Provider<FinancingCatalogueActions>((
  ref,
) {
  return FinancingCatalogueActions(
    ref.watch(financingCatalogueRepositoryProvider),
    ref,
  );
});

/// Branch on this instead of pattern-matching exception text in the UI.
String describeFinancingActionError(Object error) {
  if (error is FinancingCatalogueUnavailableException) {
    return 'This catalogue action is not available in this environment yet.';
  }
  if (error is FinancingActionException) {
    if (error.isUnauthorized) {
      return 'You do not have permission to perform this action.';
    }
    if (error.isLifecycleBlocked) return error.message;
    if (error.isNotFound) return 'That record was not found.';
    return error.message;
  }
  return 'The request could not be completed. Please try again.';
}
