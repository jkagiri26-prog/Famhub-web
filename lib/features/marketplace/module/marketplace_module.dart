import '../../../system/modules_control/module_contract.dart';
class MarketplaceModule extends AppModule {
  @override
  String get name => 'marketplace';

  @override
  String get route => '/marketplace';

  @override
  List<String> get allowedRoles => ['farmer', 'trader', 'agrovet'];

  @override
  List<String> get dashboardWidgets => ['market_kpi', 'recent_listings'];
}