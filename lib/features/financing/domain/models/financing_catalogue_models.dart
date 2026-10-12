/// ============================================================
/// FINANCING MODULE — CATALOGUE DOMAIN MODELS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/financing/domain/models/ = pure data contracts
///
/// ✅ Responsibilities:
///   - Model the Phase 1 provider / product catalogue exactly as the
///     backend migration `20261012000001_financing_provider_product_catalog`
///     exposes it.
///
/// ❌ Does NOT:
///   - Reference Supabase, Riverpod or Flutter.
///   - Hold reviewer notes or internal metadata for unprivileged callers.
///
/// TWO READ SURFACES — this is the whole point of the nullable internal
/// fields below:
///
///   1. Public browse surface (any authenticated user, no permission needed):
///      `financing.public_financial_providers`
///      `financing.public_financial_products`
///      → curated columns only. `contactEmail`, `contactPhone`,
///        `approvalStatus`, `verifiedAt`, `approvedAt` and `publishedAt` are
///        absent from the views, so they arrive as null.
///
///   2. Management surface (permission-gated by table RLS):
///      `financing.financial_providers` / `financing.financial_products`
///      → only readable with finance.manage_* / review / publish.
///
/// PRIVACY RULE ENFORCED HERE: the data source never selects `metadata`,
/// `verification_notes`, `approval_notes`, `verified_by`, `approved_by`,
/// `published_by` or `created_by`, and no widget renders them. Those columns
/// exist on the table and are readable by authorized reviewers through the
/// backend, but they are deliberately not part of this frontend's surface.
///
/// Enum `dbValue`s are the literal strings in the migration CHECK
/// constraints — they are the contract, not a convenience.
/// ============================================================
library;

import 'finance_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums (values mirror the SQL CHECK constraints verbatim)
// ─────────────────────────────────────────────────────────────────────────────

/// `financial_providers.verification_status`
enum FinancingVerificationStatus {
  pending('pending'),
  verified('verified'),
  rejected('rejected'),
  suspended('suspended');

  const FinancingVerificationStatus(this.dbValue);
  final String dbValue;

  static FinancingVerificationStatus fromDb(String? value) {
    return FinancingVerificationStatus.values.firstWhere(
      (s) => s.dbValue == value,
      orElse: () => FinancingVerificationStatus.pending,
    );
  }

  /// Short label for status chips. Safe for any audience.
  String get label => switch (this) {
        FinancingVerificationStatus.pending => 'Pending review',
        FinancingVerificationStatus.verified => 'Verified',
        FinancingVerificationStatus.rejected => 'Rejected',
        FinancingVerificationStatus.suspended => 'Suspended',
      };
}

/// `financial_products.approval_status`
enum FinancingApprovalStatus {
  draft('draft'),
  inReview('in_review'),
  approved('approved'),
  rejected('rejected');

  const FinancingApprovalStatus(this.dbValue);
  final String dbValue;

  static FinancingApprovalStatus? fromDb(String? value) {
    if (value == null) return null;
    for (final status in FinancingApprovalStatus.values) {
      if (status.dbValue == value) return status;
    }
    return null;
  }

  String get label => switch (this) {
        FinancingApprovalStatus.draft => 'Draft',
        FinancingApprovalStatus.inReview => 'In review',
        FinancingApprovalStatus.approved => 'Approved',
        FinancingApprovalStatus.rejected => 'Rejected',
      };
}

/// `financial_products.product_type`
enum FinancingProductType {
  loan('loan'),
  insurance('insurance'),
  savings('savings'),
  assetFinancing('asset_financing'),
  inputFinancing('input_financing'),
  mobileMoney('mobile_money');

  const FinancingProductType(this.dbValue);
  final String dbValue;

  static FinancingProductType? fromDb(String? value) {
    if (value == null) return null;
    for (final type in FinancingProductType.values) {
      if (type.dbValue == value) return type;
    }
    return null;
  }

  String get label => switch (this) {
        FinancingProductType.loan => 'Loan',
        FinancingProductType.insurance => 'Insurance',
        FinancingProductType.savings => 'Savings',
        FinancingProductType.assetFinancing => 'Asset financing',
        FinancingProductType.inputFinancing => 'Input financing',
        FinancingProductType.mobileMoney => 'Mobile money',
      };
}

/// `financial_products.interest_rate_type`
enum FinancingRateType {
  fixed('fixed'),
  reducingBalance('reducing_balance'),
  flat('flat'),
  variable('variable');

  const FinancingRateType(this.dbValue);
  final String dbValue;

  static FinancingRateType? fromDb(String? value) {
    if (value == null) return null;
    for (final type in FinancingRateType.values) {
      if (type.dbValue == value) return type;
    }
    return null;
  }

  String get label => switch (this) {
        FinancingRateType.fixed => 'Fixed',
        FinancingRateType.reducingBalance => 'Reducing balance',
        FinancingRateType.flat => 'Flat',
        FinancingRateType.variable => 'Variable',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

/// A financing partner row.
///
/// Built from `financing.public_financial_providers` (browse) or
/// `financing.financial_providers` (management). Fields that only exist on
/// the table are nullable and stay null for unprivileged callers.
class FinancingProvider {
  final String id;
  final String slug;
  final String name;
  final FinancialPartnerType providerType;
  final String? description;
  final String? logoUrl;
  final String? websiteUrl;
  final String? countryCode;
  final bool isActive;
  final FinancingVerificationStatus verificationStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── Table-only columns (never present on the public view) ──
  final String? contactEmail;
  final String? contactPhone;
  final DateTime? verifiedAt;

  const FinancingProvider({
    required this.id,
    required this.slug,
    required this.name,
    required this.providerType,
    required this.isActive,
    required this.verificationStatus,
    this.description,
    this.logoUrl,
    this.websiteUrl,
    this.countryCode,
    this.createdAt,
    this.updatedAt,
    this.contactEmail,
    this.contactPhone,
    this.verifiedAt,
  });

  factory FinancingProvider.fromMap(Map<String, dynamic> map) {
    return FinancingProvider(
      id: map['id']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      providerType:
          partnerTypeFromDb(map['provider_type']?.toString()) ?? FinancialPartnerType.bank,
      description: map['description']?.toString(),
      logoUrl: map['logo_url']?.toString(),
      websiteUrl: map['website_url']?.toString(),
      countryCode: map['country_code']?.toString(),
      isActive: map['is_active'] as bool? ?? false,
      verificationStatus:
          FinancingVerificationStatus.fromDb(map['verification_status']?.toString()),
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
      contactEmail: map['contact_email']?.toString(),
      contactPhone: map['contact_phone']?.toString(),
      verifiedAt: _parseDate(map['verified_at']),
    );
  }
}

/// A financing product row.
///
/// Built from `financing.public_financial_products` (browse) or
/// `financing.financial_products` (management).
class FinancingProduct {
  final String id;
  final String providerId;
  final String slug;
  final String name;
  final FinancingProductType productType;
  final String? summary;
  final String? description;
  final String currency;
  final double? minAmount;
  final double? maxAmount;
  final double? interestRate;
  final FinancingRateType? interestRateType;
  final int? minTenureDays;
  final int? maxTenureDays;
  final bool requiresCollateral;
  final List<String> requirements;
  final bool isActive;
  final bool isPublished;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── Table-only columns (never present on the public view) ──
  final FinancingApprovalStatus? approvalStatus;
  final DateTime? approvedAt;
  final DateTime? publishedAt;

  const FinancingProduct({
    required this.id,
    required this.providerId,
    required this.slug,
    required this.name,
    required this.productType,
    required this.isActive,
    required this.isPublished,
    this.summary,
    this.description,
    this.currency = 'KES',
    this.minAmount,
    this.maxAmount,
    this.interestRate,
    this.interestRateType,
    this.minTenureDays,
    this.maxTenureDays,
    this.requiresCollateral = false,
    this.requirements = const [],
    this.createdAt,
    this.updatedAt,
    this.approvalStatus,
    this.approvedAt,
    this.publishedAt,
  });

  /// Borrow range in `currency`, formatted for display. Null when unset.
  String? get amountRangeLabel {
    if (minAmount == null && maxAmount == null) return null;
    final min = minAmount == null ? null : _formatAmount(minAmount!);
    final max = maxAmount == null ? null : _formatAmount(maxAmount!);
    if (min != null && max != null) return '$min – $max';
    return min ?? max;
  }

  /// Tenure range in days, formatted for display. Null when unset.
  String? get tenureLabel {
    if (minTenureDays == null && maxTenureDays == null) return null;
    if (minTenureDays != null && maxTenureDays != null) {
      return minTenureDays == maxTenureDays
          ? '$minTenureDays days'
          : '$minTenureDays – $maxTenureDays days';
    }
    return '${minTenureDays ?? maxTenureDays} days';
  }

  /// e.g. `12% reducing balance`. Null when no rate is set.
  String? get interestLabel {
    if (interestRate == null) return null;
    final type = interestRateType?.label;
    return type == null ? '${_trim(interestRate!)}%' : '${_trim(interestRate!)}% $type';
  }

  factory FinancingProduct.fromMap(Map<String, dynamic> map) {
    return FinancingProduct(
      id: map['id']?.toString() ?? '',
      providerId: map['provider_id']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      productType:
          FinancingProductType.fromDb(map['product_type']?.toString()) ?? FinancingProductType.loan,
      summary: map['summary']?.toString(),
      description: map['description']?.toString(),
      currency: map['currency']?.toString() ?? 'KES',
      minAmount: (map['min_amount'] as num?)?.toDouble(),
      maxAmount: (map['max_amount'] as num?)?.toDouble(),
      interestRate: (map['interest_rate'] as num?)?.toDouble(),
      interestRateType: FinancingRateType.fromDb(map['interest_rate_type']?.toString()),
      minTenureDays: (map['min_tenure_days'] as num?)?.toInt(),
      maxTenureDays: (map['max_tenure_days'] as num?)?.toInt(),
      requiresCollateral: map['requires_collateral'] as bool? ?? false,
      requirements:
          (map['requirements'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      isActive: map['is_active'] as bool? ?? false,
      isPublished: map['is_published'] as bool? ?? false,
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
      approvalStatus: FinancingApprovalStatus.fromDb(map['approval_status']?.toString()),
      approvedAt: _parseDate(map['approved_at']),
      publishedAt: _parseDate(map['published_at']),
    );
  }
}

/// Grouping used by the catalogue browse screen.
class FinancingProviderWithProducts {
  final FinancingProvider provider;
  final List<FinancingProduct> products;

  const FinancingProviderWithProducts({
    required this.provider,
    this.products = const [],
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

DateTime? _parseDate(Object? value) {
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

String _trim(double value) {
  return value == value.roundToDouble() ? value.round().toString() : value.toString();
}

String _formatAmount(double value) {
  final rounded = _trim(value);
  final buffer = StringBuffer();
  for (var i = 0; i < rounded.length; i++) {
    buffer.write(rounded[i]);
    final fromEnd = rounded.length - i - 1;
    if (fromEnd > 0 && fromEnd % 3 == 0 && rounded[i] != '.') buffer.write(',');
  }
  return buffer.toString();
}
