/// ============================================================
/// OTP SESSION MODEL — Persistent OTP verification session
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/auth/domain/models/ = domain layer models
///
/// ✅ Responsibilities:
///   - Represent an active OTP verification session
///   - Track phone number, country context, and timestamps
///   - Provide expiry and resend availability checks
///   - Support serialization/deserialization for persistence
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Perform I/O operations
///   - Know about UI or widgets
/// ============================================================
library;

/// Represents an active OTP verification session.
class OtpSession {
  /// The phone number the OTP was sent to (international format, e.g. +2547XXXXXXXX).
  final String phoneNumber;

  /// Optional verification ID from the backend.
  /// Nullable because the current OTP edge function doesn't return one.
  final String? verificationId;

  /// Country ID from core.countries (used for profile context after auth).
  final String? countryId;

  /// Country display name (e.g., "Kenya").
  final String? countryName;

  /// Country ISO alpha-2 code (e.g., "KE") — used for lookup.
  final String? countryIsoAlpha2;

  /// When the OTP was sent.
  final DateTime sentAt;

  /// When the OTP expires and can no longer be used.
  final DateTime expiresAt;

  /// When resend becomes available (rate limiting).
  final DateTime resendAvailableAt;

  const OtpSession({
    required this.phoneNumber,
    this.verificationId,
    DateTime? sentAt,
    DateTime? expiresAt,
    DateTime? resendAvailableAt,
    this.countryId,
    this.countryName,
    this.countryIsoAlpha2,
  }) : sentAt = sentAt ?? DateTime.now(),
       expiresAt = expiresAt ?? DateTime.now().add(const Duration(minutes: 5)),
       resendAvailableAt = resendAvailableAt ?? DateTime.now().add(const Duration(minutes: 1));

  /// Whether this session has expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Whether the user can request a resend now.
  bool get canResend => DateTime.now().isAfter(resendAvailableAt);

  /// Remaining time in seconds until expiry (0 if expired).
  int get secondsRemaining {
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inSeconds;
  }

  /// Remaining time in seconds until resend is allowed (0 if can resend).
  int get secondsUntilResend {
    final diff = resendAvailableAt.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inSeconds;
  }

  /// Create a copy with updated values.
  OtpSession copyWith({
    String? phoneNumber,
    String? verificationId,
    String? countryId,
    String? countryName,
    String? countryIsoAlpha2,
    DateTime? sentAt,
    DateTime? expiresAt,
    DateTime? resendAvailableAt,
  }) {
    return OtpSession(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      verificationId: verificationId ?? this.verificationId,
      countryId: countryId ?? this.countryId,
      countryName: countryName ?? this.countryName,
      countryIsoAlpha2: countryIsoAlpha2 ?? this.countryIsoAlpha2,
      sentAt: sentAt ?? this.sentAt,
      expiresAt: expiresAt ?? this.expiresAt,
      resendAvailableAt: resendAvailableAt ?? this.resendAvailableAt,
    );
  }

  /// Serialize to a map for storage.
  Map<String, dynamic> toJson() {
    return {
      'phoneNumber': phoneNumber,
      'verificationId': verificationId,
      'countryId': countryId,
      'countryName': countryName,
      'countryIsoAlpha2': countryIsoAlpha2,
      'sentAt': sentAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'resendAvailableAt': resendAvailableAt.toIso8601String(),
    };
  }

  /// Deserialize from a map.
  factory OtpSession.fromJson(Map<String, dynamic> json) {
    return OtpSession(
      phoneNumber: json['phoneNumber'] as String,
      verificationId: json['verificationId'] as String?,
      countryId: json['countryId'] as String?,
      countryName: json['countryName'] as String?,
      countryIsoAlpha2: json['countryIsoAlpha2'] as String?,
      sentAt: DateTime.parse(json['sentAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      resendAvailableAt: DateTime.parse(json['resendAvailableAt'] as String),
    );
  }
}