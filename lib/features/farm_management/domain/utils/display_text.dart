/// Pure-Dart presentation helpers for normalizing display text.
///
/// These do NOT change database values — they only standardize how stored
/// labels are shown in the UI (e.g. "maize h614" → "Maize — H614",
/// "harvesting" → "Harvesting").
library;

/// True when [value] looks like a UUID, in which case we never try to
/// pretty-print it (a real activity type id should always resolve through
/// the activity_types catalog first).
final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool _looksLikeUuid(String value) => _uuidPattern.hasMatch(value);

bool _isAllCaps(String token) =>
    token.length > 1 && token == token.toUpperCase();

/// Capitalizes one token. All-caps/acronym tokens (e.g. "DK8031") pass
/// through unchanged.
String _capToken(String token) {
  if (token.isEmpty) return token;
  if (_isAllCaps(token)) return token;
  return token[0].toUpperCase() + token.substring(1).toLowerCase();
}

/// Presents a crop/livestock display label consistently as
/// `Item — Variant` when a variant-like token is present
/// (e.g. "maize h614" → "Maize — H614"). Single/multi-word labels without a
/// variant token are only capitalized ("Sweet Maize" → "Sweet Maize").
String assetDisplayTitle(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return raw;

  final tokens = trimmed
      .split(RegExp(r'[\s/]+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return trimmed;

  // A variant-like token contains a digit or is an all-caps acronym.
  var variantIndex = -1;
  for (var i = 1; i < tokens.length; i++) {
    final token = tokens[i];
    if (token.contains(RegExp(r'\d')) || _isAllCaps(token)) {
      variantIndex = i;
      break;
    }
  }
  if (variantIndex == -1) {
    return tokens.map(_capToken).join(' ');
  }
  final item = tokens.take(variantIndex).map(_capToken).join(' ');
  final variant = tokens.skip(variantIndex).map(_capToken).join(' ');
  return '$item — $variant';
}

/// Presents an activity type consistently. Real UUIDs (which should have
/// been resolved via `activity_types`) fall back to a neutral label rather
/// than being shown raw. Slug-like values ("harvesting", "pest_control")
/// are split and capitalized.
String activityTypeDisplay(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return raw;
  if (_looksLikeUuid(trimmed)) return 'Activity';

  final normalized =
      trimmed.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  if (normalized.isEmpty) return raw;

  final words = normalized
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map(_capToken)
      .toList();
  return words.join(' ');
}
