/// M-Pesa provider is not configured or temporarily unavailable.
/// The Finance attempt may already exist; retry is safe and expected.
class ContactUnlockProviderUnavailable implements Exception {
  const ContactUnlockProviderUnavailable();

  @override
  String toString() => 'mpesa_provider_not_configured';
}

/// Result of requesting a contact-unlock payment attempt.
class ContactUnlockPayment {
  final String? obligationId;
  final String? paymentAttemptId;
  final double amount;
  final String currency;
  final String unlockStatus;

  const ContactUnlockPayment({
    required this.obligationId,
    required this.paymentAttemptId,
    required this.amount,
    required this.currency,
    required this.unlockStatus,
  });

  bool get isAlreadyUnlocked => unlockStatus == 'already_unlocked';

  bool get hasPaymentAttempt =>
      paymentAttemptId != null && paymentAttemptId!.isNotEmpty;

  factory ContactUnlockPayment.fromJson(Map<String, dynamic> json) {
    return ContactUnlockPayment(
      obligationId: json['obligation_id']?.toString(),
      paymentAttemptId: json['payment_attempt_id']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'KES',
      unlockStatus: json['unlock_status']?.toString() ?? 'unknown',
    );
  }
}

/// Seller contact details revealed only after confirmed Finance settlement
/// and contact-unlock activation.
class SellerContact {
  final String sellerEntityId;
  final String? contactPerson;
  final String? email;
  final String? phone;
  final String? businessName;
  final String? physicalAddress;

  const SellerContact({
    required this.sellerEntityId,
    required this.contactPerson,
    required this.email,
    required this.phone,
    required this.businessName,
    required this.physicalAddress,
  });

  factory SellerContact.fromJson(Map<String, dynamic> json) {
    return SellerContact(
      sellerEntityId: json['seller_entity_id']?.toString() ?? '',
      contactPerson: json['contact_person']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      businessName: json['business_name']?.toString(),
      physicalAddress: json['physical_address']?.toString(),
    );
  }
}

/// Current contact-unlock and latest payment-attempt status.
class ContactUnlockStatus {
  final String? obligationId;
  final String? paymentAttemptId;
  final double amount;
  final String currency;
  final String paymentStatus;
  final bool unlocked;
  final String? attemptStatus;

  const ContactUnlockStatus({
    required this.obligationId,
    required this.paymentAttemptId,
    required this.amount,
    required this.currency,
    required this.paymentStatus,
    required this.unlocked,
    required this.attemptStatus,
  });

  bool get isUnlocked => unlocked && paymentStatus == 'completed';

  factory ContactUnlockStatus.fromJson(Map<String, dynamic> json) {
    return ContactUnlockStatus(
      obligationId: json['obligation_id']?.toString(),
      paymentAttemptId: json['payment_attempt_id']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'KES',
      paymentStatus: json['payment_status']?.toString() ?? 'pending',
      unlocked: json['unlocked'] == true,
      attemptStatus: json['attempt_status']?.toString(),
    );
  }
}
