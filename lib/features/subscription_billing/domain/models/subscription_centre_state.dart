/// M-Pesa subscription provider is not configured or temporarily unavailable.
class SubscriptionProviderUnavailable implements Exception {
  const SubscriptionProviderUnavailable();

  @override
  String toString() => 'mpesa_provider_not_configured';
}

/// The provider definitively rejected the payment request.
class SubscriptionPaymentRejected implements Exception {
  const SubscriptionPaymentRejected();

  @override
  String toString() => 'mpesa_provider_rejected';
}

/// Provider outcome is unknown; Finance remains authoritative and recoverable.
class SubscriptionOutcomeUnknown implements Exception {
  const SubscriptionOutcomeUnknown();

  @override
  String toString() => 'mpesa_provider_outcome_unknown';
}

/// Generic subscription centre failure.
class SubscriptionCentreError implements Exception {
  final String message;
  const SubscriptionCentreError(this.message);
}

/// One authoritative subscription-cycle row for the customer centre.
class SubscriptionCentreEntry {
  final String billingAccountId;
  final String billingOwnerType;
  final String planId;
  final String planKey;
  final String planName;
  final String billingCycle;
  final double amount;
  final String currency;
  final String subscriptionCycleId;
  final String cycleStatus;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime? settledAt;
  final String? activeStatus;
  final DateTime? activeStart;
  final DateTime? activeEnd;
  final bool isActive;
  final bool isPending;
  final String? paymentAttemptStatus;

  const SubscriptionCentreEntry({
    required this.billingAccountId,
    required this.billingOwnerType,
    required this.planId,
    required this.planKey,
    required this.planName,
    required this.billingCycle,
    required this.amount,
    required this.currency,
    required this.subscriptionCycleId,
    required this.cycleStatus,
    required this.periodStart,
    required this.periodEnd,
    required this.settledAt,
    required this.activeStatus,
    required this.activeStart,
    required this.activeEnd,
    required this.isActive,
    required this.isPending,
    required this.paymentAttemptStatus,
  });

  bool get isExpired {
    if (isActive) return false;
    final end = activeEnd;
    return end != null && !end.isAfter(DateTime.now().toUtc());
  }

  factory SubscriptionCentreEntry.fromJson(Map<String, dynamic> json) {
    return SubscriptionCentreEntry(
      billingAccountId: json['billing_account_id']?.toString() ?? '',
      billingOwnerType: json['billing_owner_type']?.toString() ?? 'individual',
      planId: json['plan_id']?.toString() ?? '',
      planKey: json['plan_key']?.toString() ?? '',
      planName: json['plan_name']?.toString() ?? '',
      billingCycle: json['billing_cycle']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'KES',
      subscriptionCycleId: json['subscription_cycle_id']?.toString() ?? '',
      cycleStatus: json['cycle_status']?.toString() ?? 'pending',
      periodStart: DateTime.tryParse(json['period_start']?.toString() ?? ''),
      periodEnd: DateTime.tryParse(json['period_end']?.toString() ?? ''),
      settledAt: DateTime.tryParse(json['settled_at']?.toString() ?? ''),
      activeStatus: json['active_status']?.toString(),
      activeStart: DateTime.tryParse(json['active_start']?.toString() ?? ''),
      activeEnd: DateTime.tryParse(json['active_end']?.toString() ?? ''),
      isActive: json['is_active'] == true,
      isPending: json['is_pending'] == true,
      paymentAttemptStatus: json['payment_attempt_status']?.toString(),
    );
  }
}

class SubscriptionCentreState {
  final List<SubscriptionCentreEntry> entries;

  const SubscriptionCentreState({required this.entries});

  static const empty = SubscriptionCentreState(entries: []);

  SubscriptionCentreEntry? get active {
    for (final entry in entries) {
      if (entry.isActive) return entry;
    }
    return null;
  }

  SubscriptionCentreEntry? get pending {
    for (final entry in entries) {
      if (entry.isPending) return entry;
    }
    return null;
  }

  SubscriptionCentreEntry? get latest => entries.isEmpty ? null : entries.first;

  List<SubscriptionCentreEntry> get history =>
      entries.where((entry) => !entry.isActive && !entry.isPending).toList();

  bool get hasActive => active != null;
}

class SubscriptionInitiation {
  final String status;
  final String? paymentAttemptId;
  final String? checkoutRequestId;

  const SubscriptionInitiation({
    required this.status,
    required this.paymentAttemptId,
    required this.checkoutRequestId,
  });

  bool get isPending => status == 'pending' || status == 'processing';
  bool get isSucceeded => status == 'succeeded';

  factory SubscriptionInitiation.fromJson(Map<String, dynamic> json) {
    return SubscriptionInitiation(
      status: json['status']?.toString() ?? 'pending',
      paymentAttemptId: json['paymentAttemptId']?.toString(),
      checkoutRequestId: json['checkoutRequestId']?.toString(),
    );
  }
}
