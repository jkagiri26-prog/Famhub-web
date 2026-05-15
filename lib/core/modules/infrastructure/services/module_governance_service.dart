import '../../domain/models/system_module.dart';

class ModuleGovernanceService {
  List<SystemModule> applyRules(List<SystemModule> modules) {
    final filtered = modules.where((m) {
      return m.isEnabled && m.dashboardVisible;
    }).toList();

    filtered.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return filtered;
  }
}