/// ============================================================
/// FINANCING — SLUG RULES
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/financing/domain/ = pure rules shared by the UI and tests
///
/// ✅ Responsibilities:
///   - Derive a provider/product slug from a display name.
///   - Resolve which slug an edit should submit (preserve vs regenerate).
///   - Validate a slug against the exact database format contract.
///
/// WHY THIS IS CLIENT-SIDE
///   The backend is the authority and already enforces the *rule*:
///     * `financing._validate_slug`   → 22023 on empty / malformed
///     * `*_slug_format_check`        → CHECK ^[a-z0-9]+(-[a-z0-9]+)*$
///     * `*_slug_key` UNIQUE          → 23505 on duplicates
///   Generation itself is a form convenience: the operator types a name, not
///   a slug, so the derivation has to happen where the name is edited. Any
///   other caller that skips this helper still cannot bypass the rule — the
///   RPC, the CHECK and the UNIQUE constraint reject anything malformed.
///
/// ❌ Does NOT:
///   - Touch the network, providers or state
/// ============================================================
library;

/// Byte-for-byte the pattern of
/// `financing.financial_providers_slug_format_check` and
/// `financing.financial_products_slug_format_check`
/// (migration 20261012000001).
const String financingSlugPattern = r'^[a-z0-9]+(-[a-z0-9]+)*$';

/// Precompiled form of [financingSlugPattern].
final RegExp financingSlugRegExp = RegExp(financingSlugPattern);

/// The name produced no usable slug (e.g. all punctuation, all non-ASCII).
const String financingSlugUnusableError =
    'A slug could not be generated from this name. Add letters or numbers to '
    'the name, or type a slug yourself.';

/// The operator typed a slug that the database CHECK would reject.
const String financingSlugFormatError =
    'Use lowercase letters, numbers and single hyphens only, e.g. equity-bank.';

/// The operator explicitly cleared the slug field.
const String financingSlugRequiredError = 'Slug is required.';

/// Normalises [source] into a slug that satisfies [financingSlugPattern].
///
/// lowercases → trims → collapses every run of spaces/punctuation into one
/// hyphen → strips leading and trailing hyphens.
///
/// Returns `''` when nothing usable survives; callers must treat that as a
/// validation failure rather than submitting an empty value.
String buildFinancingSlug(String source) {
  final collapsed = source
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-');
  return collapsed
      .replaceFirst(RegExp(r'^-+'), '')
      .replaceFirst(RegExp(r'-+$'), '');
}

/// Decides which slug a save should submit.
///
/// * [manualSlug] non-null  → the operator typed in the slug field; theirs wins.
/// * no [existingSlug]      → derive from [name] (creation).
/// * [name] unchanged       → keep [existingSlug] (edits never churn a slug).
/// * [name] changed         → regenerate from the new name.
String resolveProviderSlug({
  required String name,
  String? existingSlug,
  String? previousName,
  String? manualSlug,
}) {
  if (manualSlug != null) return manualSlug.trim();

  final existing = existingSlug?.trim();
  if (existing == null || existing.isEmpty) return buildFinancingSlug(name);

  final previous = previousName?.trim();
  if (previous != null && previous == name.trim()) return existing;

  return buildFinancingSlug(name);
}

/// Validates the slug a save is about to submit.
///
/// [generated] must be true when the value came from [buildFinancingSlug] so
/// an empty result can explain *why* it is empty instead of just saying
/// "required".
String? validateFinancingSlug(String slug, {required bool generated}) {
  final value = slug.trim();
  if (value.isEmpty) {
    return generated ? financingSlugUnusableError : financingSlugRequiredError;
  }
  if (!financingSlugRegExp.hasMatch(value)) return financingSlugFormatError;
  return null;
}
