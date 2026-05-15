import '../../../system/module/module_contract.dart';
import '../presentation/pages/marketplace_page.dart';
import '../presentation/pages/product_details_page.dart';
import '../presentation/pages/create_listing_page.dart';

class MarketplaceModule extends AppModule {
  @override
  String get name => 'marketplace';

  @override
  String get route => '/marketplace';

  @override
  Widget build() => const MarketplacePage();

  @override
  List<String> get allowedRoles => ['farmer', 'trader', 'agrovet'];

  @override
  List<String> get dashboardWidgets => ['market_kpi', 'recent_listings'];
}