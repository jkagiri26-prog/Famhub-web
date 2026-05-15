class DashboardLayoutBindingService {
  final List<Map<String, dynamic>> backendRules;

  DashboardLayoutBindingService({
    required this.backendRules,
  });

  String? resolveLayoutKey({
    required String moduleKey,
    required String deviceType,
    String? role,
    String? entityId,
  }) {
    /// 1. ENTITY LEVEL (highest priority)
    final entityMatch = backendRules.where((r) {
      return r['module_key'] == moduleKey &&
          r['entity_id'] == entityId &&
          r['device'] == deviceType &&
          r['is_active'] == true;
    });

    if (entityMatch.isNotEmpty) {
      return _pick(entityMatch);
    }

    /// 2. ROLE LEVEL
    final roleMatch = backendRules.where((r) {
      return r['module_key'] == moduleKey &&
          r['role'] == role &&
          r['device'] == deviceType &&
          r['is_active'] == true;
    });

    if (roleMatch.isNotEmpty) {
      return _pick(roleMatch);
    }

    /// 3. MODULE DEFAULT
    final moduleMatch = backendRules.where((r) {
      return r['module_key'] == moduleKey &&
          r['device'] == deviceType &&
          r['is_active'] == true;
    });

    if (moduleMatch.isNotEmpty) {
      return _pick(moduleMatch);
    }

    return null;
  }

  String _pick(List<Map<String, dynamic>> matches) {
    matches.sort((a, b) {
      return (b['priority'] ?? 0).compareTo(a['priority'] ?? 0);
    });

    return matches.first['layout_key'];
  }
}