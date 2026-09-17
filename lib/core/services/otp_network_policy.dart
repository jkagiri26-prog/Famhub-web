/// ============================================================
/// OTP NETWORK POLICY — TEMPORARY PRE-LAUNCH TESTING RESTRICTION
/// ============================================================
///
/// ⚠️ TEMPORARY / PRE-LAUNCH ONLY — REMOVE WHEN SENDER ID IS READY ⚠️
///
/// Context:
///   - Africa's Talking OTP delivery currently works for Airtel.
///   - Safaricom delivery returns `UserInBlackList` while the Sender ID
///     configuration is being resolved.
///   - This is NOT a permanent Safaricom restriction.
///
/// This single file isolates the temporary restriction so it can be
/// removed in ONE place once the Safaricom Sender ID is configured:
///   1. Set [safaricomTestingRestrictionEnabled] to `false`
///      (or delete this file).
///   2. Remove the `OtpNetworkPolicy` check in `AuthService.sendOtp`.
///   3. Remove the blacklist branch in
///      `AuthService._mapEdgeFunctionError`.
///
/// It does NOT change the OTP/authentication architecture, does NOT
/// create a second auth flow, and does NOT affect Airtel.
/// ============================================================
library;

class OtpNetworkPolicy {
  OtpNetworkPolicy._();

  /// Master switch for the temporary Safaricom testing restriction.
  ///
  /// TODO(pre-launch): flip to `false` (or delete this file) once the
  /// Safaricom Sender ID is configured. This is intentionally the ONLY
  /// switch that needs to change.
  static const bool safaricomTestingRestrictionEnabled = true;

  /// Clean user-facing message shown for Safaricom during testing.
  /// Never expose the raw Africa's Talking error (`UserInBlackList`).
  static const String temporaryUnavailableMessage =
      'OTP currently unavailable for this network\n\n'
      "We're currently testing phone verification. Please use an Airtel "
      'number for now.\n\n'
      'Safaricom support will be enabled before the full launch.';

  /// Known Safaricom Kenya prefixes (national significant number, i.e.
  /// the 9 digits after the +254 country code, WITHOUT a leading 0).
  ///
  /// Deliberately CONSERVATIVE: only prefixes that are unambiguously
  /// Safaricom are listed so Airtel numbers are never blocked. Safaricom
  /// numbers outside this list still receive the friendly message through
  /// the `UserInBlackList` error mapping safety net.
  static const List<String> _safaricomPrefixes = <String>[
    '70', '71', '72', // 070x–072x
    '740', '741', '742', '743', '744', '745',
    '757', '758', '759',
    '790', '791', '792', '793', '794',
    '795', '796', '797', '798', '799',
    '110', '111', '112', '113', '114', '115',
  ];

  /// Whether the OTP request should be temporarily blocked for [phone].
  ///
  /// Only Kenyan (+254) Safaricom numbers are affected; all other numbers
  /// (including Airtel) return false and continue through the normal flow.
  static bool isTemporarilyBlocked(String phone) {
    if (!safaricomTestingRestrictionEnabled) return false;

    final national = _kenyanNationalNumber(phone);
    if (national == null) return false;

    for (final prefix in _safaricomPrefixes) {
      if (national.startsWith(prefix)) return true;
    }
    return false;
  }

  /// Extracts the 9-digit Kenyan national significant number from a phone
  /// number, or null when it is not a Kenyan mobile number.
  static String? _kenyanNationalNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (!digits.startsWith('254')) return null;

    final national = digits.substring(3);
    if (national.length != 9) return null;
    if (!national.startsWith('7') && !national.startsWith('1')) return null;
    return national;
  }
}
