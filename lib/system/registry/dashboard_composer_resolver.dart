import '../../core/dashboard/domain/repositories/dashboard_composer_contract.dart';
import 'dashboard_composer_registry.dart';

DashboardComposerContract? resolveComposer(String moduleKey) {
  return dashboardComposerRegistry[moduleKey];
}
