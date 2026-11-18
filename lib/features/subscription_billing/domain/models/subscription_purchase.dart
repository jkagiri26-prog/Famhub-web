/// Customer-facing subscription plan.
///
/// This is a read model over `system.subscription_plans`; it intentionally
/// excludes internal accounting/Finance fields.
class SubscriptionPlan {
  final String planId;
  final String planKey;
  final String planName;
  final double amount;
  final String currency;
  final String billingCycle;
  final bool isActive;
  final Map<String, dynamic> features;

  const SubscriptionPlan({
    required this.planId,
    required this.planKey,
    required this.planName,
    required this.amount,
    required this.currency,
    required this.billingCycle,
    required this.isActive,
    required this.features,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features_json'];
    return SubscriptionPlan(
      planId: json['plan_id']?.toString() ?? '',
      planKey: json['plan_key']?.toString() ?? '',
      planName: json['plan_name']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'KES',
      billingCycle: json['billing_cycle']?.toString() ?? 'yearly',
      isActive: json['is_active'] == true,
      features: rawFeatures is Map
          ? Map<String, dynamic>.from(rawFeatures)
          : const {},
    );
  }
}

/// Result of creating or reusing the caller's pending subscription cycle.
class SubscriptionPurchase {
  final String subscriptionCycleId;
  final String planId;
  final String planKey;
  final String planName;
  final double amount;
  final String currency;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String status;
  final String? billingCycle;

  const SubscriptionPurchase({
    required this.subscriptionCycleId,
    required this.planId,
    required this.planKey,
    required this.planName,
    required this.amount,
    required this.currency,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    this.billingCycle,
  });

  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';

  factory SubscriptionPurchase.fromJson(Map<String, dynamic> json) {
    return SubscriptionPurchase(
      subscriptionCycleId: json['subscription_cycle_id']?.toString() ?? '',
      planId: json['plan_id']?.toString() ?? '',
      planKey: json['plan_key']?.toString() ?? '',
      planName: json['plan_name']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'KES',
      periodStart: DateTime.tryParse(json['period_start']?.toString() ?? ''),
      periodEnd: DateTime.tryParse(json['period_end']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'pending',
      billingCycle: json['billing_cycle']?.toString(),
    );
  }
}
