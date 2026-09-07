/// ============================================================
/// BUSINESS HUB — PERMISSION CONSTANTS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/business_hub/config/ = static configuration
///
/// Business Hub capability/permission keys (frontend contract).
/// Backend schema identity remains `commerce`.
/// ============================================================
class BusinessHubPermissions {
  const BusinessHubPermissions._();

  /// Core access
  static const String viewBusinessHub = 'business_hub.view';
  static const String accessDashboard = 'business_hub.dashboard.access';

  /// Business entity / profile
  static const String viewBusiness = 'business_hub.business.view';
  static const String createBusiness = 'business_hub.business.create';
  static const String updateBusiness = 'business_hub.business.update';
  static const String manageProfile = 'business_hub.profile.manage';

  /// Business operations (backend contracts live under `commerce` /
  /// `marketplace` — Business Hub only surfaces them)
  static const String viewInventory = 'business_hub.inventory.view';
  static const String viewOrders = 'business_hub.orders.view';
  static const String viewPurchases = 'business_hub.purchases.view';
  static const String viewTransactions = 'business_hub.transactions.view';
  static const String viewListings = 'business_hub.listings.view';

  /// Full registry for validation / seeding / policy sync
  static const List<String> all = [
    viewBusinessHub,
    accessDashboard,
    viewBusiness,
    createBusiness,
    updateBusiness,
    manageProfile,
    viewInventory,
    viewOrders,
    viewPurchases,
    viewTransactions,
    viewListings,
  ];
}
