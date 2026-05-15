import '../../features/farm_management/presentation/dashboard/farm_dashboard_composer.dart';
import '../../features/marketplace/presentation/dashboard/marketplace_composer.dart';
import '../../features/admin_console/presentation/dashboard/admin_composer.dart';

import '../../core/dashboard/domain/repositories/dashboard_composer_contract.dart';

class DashboardComposerRegistry {
  static final List<DashboardComposerContract> _composers = [
    FarmDashboardComposer(),
    MarketplaceComposer(),
    AdminDashboardComposer(),
  ];

  static DashboardComposerContract? resolve(String moduleKey) {
    try {
      return _composers.firstWhere(
        (c) => c.moduleKey == moduleKey,
      );
    } catch (_) {
      return null;
    }
  }
}