/// ============================================================
/// FINANCING CATALOGUE REPOSITORY (DOMAIN CONTRACT)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/financing/domain/repositories/ = abstract contract
///
/// ✅ Responsibilities:
///   - Declare the bounded catalogue reads (browse + management).
///   - Declare the backend RPC-backed catalogue actions.
///
/// ❌ Does NOT:
///   - Reference Supabase or any infrastructure type
///   - Contain UI or state
///
/// READ SURFACES
///   `fetchBrowse*` reads the column-limited public views and needs no
///   permission beyond an authenticated session.
///   `fetchManaged*` reads the underlying tables, which are protected by
///   permission-gated RLS; an unauthorized caller simply gets an empty list.
///
/// WRITES
///   Every action is a backend RPC. Direct table writes are impossible — the
///   migration grants no INSERT/UPDATE/DELETE to any API role.
/// ============================================================
library;

import '../models/finance_models.dart';
import '../models/financing_catalogue_models.dart';

/// Thrown when the Phase 1 migration is not present in the target environment
/// (relation or RPC missing, or the `financing` schema is not exposed through
/// PostgREST).
///
/// The UI renders this as an explicit "not available yet" state instead of a
/// generic failure — it is a deployment fact, not a user error.
class FinancingCatalogueUnavailableException implements Exception {
  const FinancingCatalogueUnavailableException([this.reason]);

  final String? reason;

  @override
  String toString() => reason ?? 'Financing catalogue is not available yet.';
}

/// Thrown when an action is refused by the backend authorization layer
/// (SQLSTATE 42501) or by a lifecycle/validation guard. `code` carries the
/// backend SQLSTATE so the UI can distinguish "not allowed" from "invalid".
class FinancingActionException implements Exception {
  const FinancingActionException(this.message, {this.code});

  final String message;
  final String? code;

  bool get isUnauthorized => code == '42501';
  bool get isNotFound => code == 'P0002';
  bool get isInvalid => code == '22023';
  bool get isLifecycleBlocked => code == '55000';

  @override
  String toString() => message;
}

abstract class FinancingCatalogueRepository {
  // ── Browse (public views, no permission required beyond sign-in) ─────────

  /// Verified, active providers from `financing.public_financial_providers`.
  Future<List<FinancingProvider>> fetchBrowseProviders({
    int limit = 100,
    FinancialPartnerType? providerType,
  });

  /// Approved + published products of active verified providers, from
  /// `financing.public_financial_products`.
  Future<List<FinancingProduct>> fetchBrowseProducts({
    int limit = 200,
    String? providerId,
    FinancingProductType? productType,
  });

  // ── Management (permission-gated table RLS) ──────────────────────────────

  /// All providers visible to a `finance.manage_providers` /
  /// `finance.verify_providers` caller, including unverified rows.
  Future<List<FinancingProvider>> fetchManagedProviders({
    int limit = 200,
    String? verificationStatus,
  });

  /// All products visible to a `finance.manage_products` /
  /// `finance.review_products` / `finance.publish_products` caller.
  Future<List<FinancingProduct>> fetchManagedProducts({
    int limit = 200,
    String? providerId,
    String? approvalStatus,
  });

  // ── Provider actions (`finance.manage_providers`) ────────────────────────

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
  });

  /// `finance.verify_providers`. Status is one of verified | rejected |
  /// suspended — the backend rejects anything else with 22023.
  Future<String> verifyProvider({
    required String providerId,
    required FinancingVerificationStatus status,
    String? notes,
  });

  // ── Product actions (`finance.manage_products` / review / publish) ───────

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
  });

  Future<String> reopenProduct({required String productId});
  Future<String> submitProductForReview({required String productId});
  Future<String> reviewProduct({
    required String productId,
    required bool approved,
    String? notes,
  });
  Future<String> publishProduct({required String productId});
  Future<String> unpublishProduct({required String productId});
}
