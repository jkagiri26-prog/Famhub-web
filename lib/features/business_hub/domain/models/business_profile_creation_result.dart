/// ============================================================
/// BUSINESS PROFILE CREATION RESULT (DOMAIN)
/// ============================================================
///
/// Outcome of `commerce.create_business_profile(p_entity_id, p_profile)`.
///
/// The backend RPC is idempotent: it returns the existing active profile
/// when one already exists for the entity. Both outcomes are SUCCESS —
/// the caller must not treat `alreadyExists` as an error.
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

class BusinessProfileCreationResult {
  /// True when a new `commerce.business_profiles` row was created.
  final bool created;

  /// True when an active profile already existed for the entity and was
  /// returned instead of creating a duplicate.
  final bool alreadyExists;

  /// `commerce.business_profiles.id` when the RPC returns it.
  final String? businessProfileId;

  const BusinessProfileCreationResult({
    this.created = false,
    this.alreadyExists = false,
    this.businessProfileId,
  });

  /// Any non-throwing RPC result is a successful completion — a returned
  /// [BusinessProfileCreationResult] never represents a failure.
  factory BusinessProfileCreationResult.fromRow(Map<String, dynamic> row) {
    final alreadyExists =
        row['already_exists'] == true || row['alreadyExists'] == true;
    final created =
        row['created'] == true || (!alreadyExists && row.containsKey('id'));

    final id =
        row['business_profile_id'] ?? row['businessProfileId'] ?? row['id'];

    return BusinessProfileCreationResult(
      created: created,
      alreadyExists: alreadyExists,
      businessProfileId: id?.toString(),
    );
  }
}
