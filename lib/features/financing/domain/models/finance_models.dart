/// ============================================================
/// FINANCING MODULE — DOMAIN MODELS
/// ============================================================
///
/// Phase D: Live data models for financial services integration.
/// Supports: Banks, SACCOs, Insurance companies, and lending platforms.
/// ============================================================
library;

/// Financial partner types supported by the platform
enum FinancialPartnerType {
  bank,
  sacco,
  insurance,
  microfinance,
  lendingPlatform,
  mobileMoney,
}

/// Account balance summary
class AccountBalance {
  final String accountId;
  final String accountName;
  final String partnerName;
  final FinancialPartnerType partnerType;
  final double currentBalance;
  final double availableBalance;
  final String currency;
  final DateTime lastUpdated;
  final bool isConnected;

  const AccountBalance({
    required this.accountId,
    required this.accountName,
    required this.partnerName,
    required this.partnerType,
    required this.currentBalance,
    required this.availableBalance,
    this.currency = 'KES',
    required this.lastUpdated,
    this.isConnected = true,
  });

  factory AccountBalance.fromMap(Map<String, dynamic> map) {
    return AccountBalance(
      accountId: map['account_id']?.toString() ?? '',
      accountName: map['account_name']?.toString() ?? 'Account',
      partnerName: map['partner_name']?.toString() ?? '',
      partnerType: FinancialPartnerType.values.firstWhere(
        (t) => t.name == map['partner_type']?.toString(),
        orElse: () => FinancialPartnerType.bank,
      ),
      currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0,
      availableBalance: (map['available_balance'] as num?)?.toDouble() ?? 0,
      currency: map['currency']?.toString() ?? 'KES',
      lastUpdated: map['last_updated'] != null
          ? DateTime.parse(map['last_updated'] as String)
          : DateTime.now(),
      isConnected: map['is_connected'] as bool? ?? true,
    );
  }
}

/// Transaction record
class FinanceTransaction {
  final String transactionId;
  final String accountId;
  final String partnerName;
  final String description;
  final double amount;
  final TransactionType type;
  final TransactionStatus status;
  final String category;
  final DateTime transactionDate;
  final String? referenceNumber;

  const FinanceTransaction({
    required this.transactionId,
    required this.accountId,
    required this.partnerName,
    required this.description,
    required this.amount,
    required this.type,
    required this.status,
    this.category = 'general',
    required this.transactionDate,
    this.referenceNumber,
  });

  factory FinanceTransaction.fromMap(Map<String, dynamic> map) {
    return FinanceTransaction(
      transactionId: map['transaction_id']?.toString() ?? '',
      accountId: map['account_id']?.toString() ?? '',
      partnerName: map['partner_name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      type: TransactionType.values.firstWhere(
        (t) => t.name == map['type']?.toString(),
        orElse: () => TransactionType.credit,
      ),
      status: TransactionStatus.values.firstWhere(
        (s) => s.name == map['status']?.toString(),
        orElse: () => TransactionStatus.completed,
      ),
      category: map['category']?.toString() ?? 'general',
      transactionDate: map['transaction_date'] != null
          ? DateTime.parse(map['transaction_date'] as String)
          : DateTime.now(),
      referenceNumber: map['reference_number']?.toString(),
    );
  }
}

enum TransactionType { credit, debit, payment, withdrawal, deposit, transfer }
enum TransactionStatus { pending, completed, failed, cancelled }

/// Loan product offer from a partner
class LoanOffer {
  final String offerId;
  final String partnerName;
  final FinancialPartnerType partnerType;
  final String loanName;
  final double minAmount;
  final double maxAmount;
  final double interestRate;
  final String interestRateType; // fixed, reducing_balance, flat
  final int minTenureDays;
  final int maxTenureDays;
  final List<String> requirements;
  final bool requiresCollateral;
  final String status; // active, coming_soon, expired

  const LoanOffer({
    required this.offerId,
    required this.partnerName,
    required this.partnerType,
    required this.loanName,
    required this.minAmount,
    required this.maxAmount,
    required this.interestRate,
    this.interestRateType = 'reducing_balance',
    required this.minTenureDays,
    required this.maxTenureDays,
    this.requirements = const [],
    this.requiresCollateral = false,
    this.status = 'active',
  });

  factory LoanOffer.fromMap(Map<String, dynamic> map) {
    return LoanOffer(
      offerId: map['offer_id']?.toString() ?? '',
      partnerName: map['partner_name']?.toString() ?? '',
      partnerType: FinancialPartnerType.values.firstWhere(
        (t) => t.name == map['partner_type']?.toString(),
        orElse: () => FinancialPartnerType.bank,
      ),
      loanName: map['loan_name']?.toString() ?? '',
      minAmount: (map['min_amount'] as num?)?.toDouble() ?? 0,
      maxAmount: (map['max_amount'] as num?)?.toDouble() ?? 0,
      interestRate: (map['interest_rate'] as num?)?.toDouble() ?? 0,
      interestRateType: map['interest_rate_type']?.toString() ?? 'reducing_balance',
      minTenureDays: map['min_tenure_days'] as int? ?? 30,
      maxTenureDays: map['max_tenure_days'] as int? ?? 365,
      requirements: (map['requirements'] as List?)?.cast<String>() ?? [],
      requiresCollateral: map['requires_collateral'] as bool? ?? false,
      status: map['status']?.toString() ?? 'active',
    );
  }
}

/// Active loan from a partner
class ActiveLoan {
  final String loanId;
  final String partnerName;
  final String loanName;
  final double principalAmount;
  final double outstandingBalance;
  final double interestRate;
  final double monthlyPayment;
  final DateTime disbursementDate;
  final DateTime? maturityDate;
  final String status; // active, closed, defaulted, restructured
  final int remainingInstallments;
  final double paidAmount;

  const ActiveLoan({
    required this.loanId,
    required this.partnerName,
    required this.loanName,
    required this.principalAmount,
    required this.outstandingBalance,
    required this.interestRate,
    required this.monthlyPayment,
    required this.disbursementDate,
    this.maturityDate,
    this.status = 'active',
    this.remainingInstallments = 0,
    this.paidAmount = 0,
  });

  factory ActiveLoan.fromMap(Map<String, dynamic> map) {
    return ActiveLoan(
      loanId: map['loan_id']?.toString() ?? '',
      partnerName: map['partner_name']?.toString() ?? '',
      loanName: map['loan_name']?.toString() ?? '',
      principalAmount: (map['principal_amount'] as num?)?.toDouble() ?? 0,
      outstandingBalance: (map['outstanding_balance'] as num?)?.toDouble() ?? 0,
      interestRate: (map['interest_rate'] as num?)?.toDouble() ?? 0,
      monthlyPayment: (map['monthly_payment'] as num?)?.toDouble() ?? 0,
      disbursementDate: DateTime.parse(map['disbursement_date'] as String),
      maturityDate: map['maturity_date'] != null
          ? DateTime.parse(map['maturity_date'] as String)
          : null,
      status: map['status']?.toString() ?? 'active',
      remainingInstallments: map['remaining_installments'] as int? ?? 0,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0,
    );
  }

  double get progress => principalAmount > 0 ? paidAmount / principalAmount : 0;
  bool get isOverdue => status == 'active' && maturityDate != null && maturityDate!.isBefore(DateTime.now());
}

/// Insurance policy
class InsurancePolicy {
  final String policyId;
  final String partnerName;
  final String policyName;
  final String policyType; // crop, livestock, asset, health, life
  final double premium;
  final double coverageAmount;
  final DateTime startDate;
  final DateTime? expiryDate;
  final String status; // active, expired, claimed, cancelled

  const InsurancePolicy({
    required this.policyId,
    required this.partnerName,
    required this.policyName,
    required this.policyType,
    required this.premium,
    required this.coverageAmount,
    required this.startDate,
    this.expiryDate,
    this.status = 'active',
  });

  factory InsurancePolicy.fromMap(Map<String, dynamic> map) {
    return InsurancePolicy(
      policyId: map['policy_id']?.toString() ?? '',
      partnerName: map['partner_name']?.toString() ?? '',
      policyName: map['policy_name']?.toString() ?? '',
      policyType: map['policy_type']?.toString() ?? '',
      premium: (map['premium'] as num?)?.toDouble() ?? 0,
      coverageAmount: (map['coverage_amount'] as num?)?.toDouble() ?? 0,
      startDate: DateTime.parse(map['start_date'] as String),
      expiryDate: map['expiry_date'] != null
          ? DateTime.parse(map['expiry_date'] as String)
          : null,
      status: map['status']?.toString() ?? 'active',
    );
  }
}

/// Financial partner profile
class FinancialPartner {
  final String partnerId;
  final String name;
  final FinancialPartnerType type;
  final String? logoUrl;
  final String? description;
  final List<String> services;
  final bool isConnected;
  final double? rating;
  final int? customerCount;

  const FinancialPartner({
    required this.partnerId,
    required this.name,
    required this.type,
    this.logoUrl,
    this.description,
    this.services = const [],
    this.isConnected = false,
    this.rating,
    this.customerCount,
  });

  factory FinancialPartner.fromMap(Map<String, dynamic> map) {
    return FinancialPartner(
      partnerId: map['partner_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      type: FinancialPartnerType.values.firstWhere(
        (t) => t.name == map['type']?.toString(),
        orElse: () => FinancialPartnerType.bank,
      ),
      logoUrl: map['logo_url']?.toString(),
      description: map['description']?.toString(),
      services: (map['services'] as List?)?.cast<String>() ?? [],
      isConnected: map['is_connected'] as bool? ?? false,
      rating: (map['rating'] as num?)?.toDouble(),
      customerCount: map['customer_count'] as int?,
    );
  }
}
