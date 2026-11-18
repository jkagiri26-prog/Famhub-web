/// Backend-authoritative subscription entitlement snapshot.
class SubscriptionEntitlements {
  final bool verified;
  final bool isActive;
  final bool isFuture;
  final bool isExpired;
  final String? entityId;
  final String? billingOwnerType;
  final String? planName;
  final String? billingCycle;
  final DateTime? startDate;
  final DateTime? endDate;
  final Set<String> capabilities;

  const SubscriptionEntitlements({
    required this.verified,
    required this.isActive,
    required this.isFuture,
    required this.isExpired,
    required this.entityId,
    required this.billingOwnerType,
    required this.planName,
    required this.billingCycle,
    required this.startDate,
    required this.endDate,
    required this.capabilities,
  });

  static const unverified = SubscriptionEntitlements(
    verified: false,
    isActive: false,
    isFuture: false,
    isExpired: false,
    entityId: null,
    billingOwnerType: null,
    planName: null,
    billingCycle: null,
    startDate: null,
    endDate: null,
    capabilities: <String>{},
  );

  static const empty = SubscriptionEntitlements(
    verified: true,
    isActive: false,
    isFuture: false,
    isExpired: false,
    entityId: null,
    billingOwnerType: null,
    planName: null,
    billingCycle: null,
    startDate: null,
    endDate: null,
    capabilities: <String>{},
  );

  bool hasCapability(String capability) {
    final normalized = capability.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    final candidates = <String>{
      normalized,
      normalized.replaceAll('_', '.'),
      normalized.replaceAll('_', ''),
    };
    for (final granted in capabilities) {
      if (candidates.contains(granted)) return true;
      if (granted.endsWith('.*')) {
        final prefix = granted.substring(0, granted.length - 1);
        if (candidates.any((candidate) => candidate.startsWith(prefix))) {
          return true;
        }
      }
    }
    return false;
  }

  bool allowsModule(String moduleKey) {
    if (!verified || !isActive) return false;
    return hasCapability(moduleKey) || hasCapability('$moduleKey.access');
  }

  factory SubscriptionEntitlements.fromRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return empty;

    final activeRows = rows.where((row) => row['is_active'] == true).toList();
    final futureRows = rows.where((row) => row['is_future'] == true).toList();
    final expiredRows = rows.where((row) => row['is_expired'] == true).toList();
    final selected = activeRows.isNotEmpty
        ? activeRows.first
        : futureRows.isNotEmpty
        ? futureRows.first
        : expiredRows.isNotEmpty
        ? expiredRows.first
        : rows.first;

    final capabilities = <String>{};
    for (final row in activeRows) {
      final raw = row['capabilities'];
      if (raw is List) {
        for (final value in raw) {
          final capability = value?.toString().trim().toLowerCase() ?? '';
          if (capability.isNotEmpty) capabilities.add(capability);
        }
      }
    }

    return SubscriptionEntitlements(
      verified: true,
      isActive: activeRows.isNotEmpty,
      isFuture: activeRows.isEmpty && futureRows.isNotEmpty,
      isExpired:
          activeRows.isEmpty && futureRows.isEmpty && expiredRows.isNotEmpty,
      entityId: selected['entity_id']?.toString(),
      billingOwnerType: selected['billing_owner_type']?.toString(),
      planName: selected['plan_name']?.toString(),
      billingCycle: selected['billing_cycle']?.toString(),
      startDate: DateTime.tryParse(selected['start_date']?.toString() ?? ''),
      endDate: DateTime.tryParse(selected['end_date']?.toString() ?? ''),
      capabilities: Set.unmodifiable(capabilities),
    );
  }
}
