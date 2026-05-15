import '../../domain/models/dashboard_layout_binding_rule.dart';

class DashboardLayoutBindingService {
  final List<DashboardLayoutBindingRule> rules;

  DashboardLayoutBindingService({
    required this.rules,
  });

  String? resolveLayoutKey({
    required String moduleKey,
    required String deviceType,
    String? role,
    String? entityId,
  }) {
    /// 1. ENTITY LEVEL
    final entityMatch = rules.where((r) =>
        r.moduleKey == moduleKey &&
        r.entityId == entityId &&
        r.device == deviceType &&
        r.isActive);

    if (entityMatch.isNotEmpty) {
      return _pick(entityMatch.toList());
    }

    /// 2. ROLE LEVEL
    final roleMatch = rules.where((r) =>
        r.moduleKey == moduleKey &&
        r.role == role &&
        r.device == deviceType &&
        r.isActive);

    if (roleMatch.isNotEmpty) {
      return _pick(roleMatch.toList());
    }

    /// 3. MODULE LEVEL
    final moduleMatch = rules.where((r) =>
        r.moduleKey == moduleKey &&
        r.device == deviceType &&
        r.isActive);

    if (moduleMatch.isNotEmpty) {
      return _pick(moduleMatch.toList());
    }

    return null;
  }

  String _pick(List<DashboardLayoutBindingRule> list) {
    list.sort((a, b) => b.priority.compareTo(a.priority));
    return list.first.layoutKey;
  }
}