/// Normalizes a Kenyan M-Pesa number to the canonical `2547XXXXXXXX` form.
///
/// Accepts `07XXXXXXXX`, `7XXXXXXXX`, `2547XXXXXXXX`, and the same forms with
/// spaces, dashes, or a leading `+`. Returns null for anything else.
String? normalizeKenyanMpesaPhone(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  String? national;

  if (digits.length == 10 && digits.startsWith('07')) {
    national = digits.substring(1);
  } else if (digits.length == 9 && digits.startsWith('7')) {
    national = digits;
  } else if (digits.length == 12 && digits.startsWith('2547')) {
    national = digits.substring(3);
  }

  if (national == null || !RegExp(r'^7\d{8}$').hasMatch(national)) {
    return null;
  }
  return '254$national';
}
