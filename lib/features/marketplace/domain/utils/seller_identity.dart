String sellerIdentityDisplayName({
  required String? entityName,
  required String? firstName,
  required bool isProfileOwned,
}) {
  final entity = entityName?.trim() ?? '';
  final first = firstName?.trim() ?? '';

  if (isProfileOwned) return first;
  if (entity.isNotEmpty && first.isNotEmpty) return '$entity · $first';
  if (entity.isNotEmpty) return entity;
  return first;
}
