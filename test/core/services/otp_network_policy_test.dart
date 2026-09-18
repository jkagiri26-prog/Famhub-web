import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/services/otp_network_policy.dart';

void main() {
  group('OtpNetworkPolicy — temporary Safaricom restriction', () {
    test('blocks Safaricom Kenyan numbers', () {
      const safaricom = [
        '+254700123456',
        '+254712345678',
        '+254722345678',
        '+254740123456',
        '+254745123456',
        '+254757123456',
        '+254759123456',
        '+254790123456',
        '+254799123456',
        '+254110123456',
        '+254115123456',
      ];
      for (final phone in safaricom) {
        expect(
          OtpNetworkPolicy.isTemporarilyBlocked(phone),
          isTrue,
          reason: '$phone should be blocked',
        );
      }
    });

    test('does NOT block Airtel Kenyan numbers', () {
      const airtel = [
        '+254730123456',
        '+254731123456',
        '+254739123456',
        '+254750123456',
        '+254756123456',
        '+254785123456',
        '+254789123456',
        '+254100123456',
        '+254104123456',
      ];
      for (final phone in airtel) {
        expect(
          OtpNetworkPolicy.isTemporarilyBlocked(phone),
          isFalse,
          reason: '$phone must remain allowed (Airtel)',
        );
      }
    });

    test('does NOT block other networks or countries', () {
      const allowed = [
        '+254770123456', // Telkom
        '+254763123456', // Equitel
        '+255700123456', // Tanzania
        '+256700123456', // Uganda
        '+25470012345', // too short
        '+2547001234567', // too long
      ];
      for (final phone in allowed) {
        expect(
          OtpNetworkPolicy.isTemporarilyBlocked(phone),
          isFalse,
          reason: '$phone should not be blocked',
        );
      }
    });

    test('friendly message never exposes the raw provider error', () {
      expect(
        OtpNetworkPolicy.temporaryUnavailableMessage
            .toLowerCase()
            .contains('blacklist'),
        isFalse,
      );
      expect(
        OtpNetworkPolicy.temporaryUnavailableMessage,
        contains('OTP currently unavailable for this network'),
      );
    });
  });
}
