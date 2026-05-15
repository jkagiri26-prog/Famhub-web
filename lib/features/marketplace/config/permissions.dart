class MarketplacePermissions {
  const MarketplacePermissions._();

  /// Core access
  static const String viewMarketplace = 'marketplace.view';
  static const String accessDashboard = 'marketplace.dashboard.access';

  /// Product management
  static const String createProduct = 'marketplace.product.create';
  static const String updateProduct = 'marketplace.product.update';
  static const String deleteProduct = 'marketplace.product.delete';
  static const String publishProduct = 'marketplace.product.publish';
  static const String manageInventory = 'marketplace.inventory.manage';

  /// Orders
  static const String viewOrders = 'marketplace.orders.view';
  static const String createOrder = 'marketplace.orders.create';
  static const String updateOrder = 'marketplace.orders.update';
  static const String cancelOrder = 'marketplace.orders.cancel';
  static const String approveOrder = 'marketplace.orders.approve';

  /// Payments
  static const String viewPayments = 'marketplace.payments.view';
  static const String managePayments = 'marketplace.payments.manage';
  static const String requestPayout = 'marketplace.payout.request';
  static const String approvePayout = 'marketplace.payout.approve';

  /// Vendors / Suppliers
  static const String viewSuppliers = 'marketplace.suppliers.view';
  static const String manageSuppliers = 'marketplace.suppliers.manage';
  static const String verifySupplier = 'marketplace.suppliers.verify';

  /// Pricing / Promotions
  static const String managePricing = 'marketplace.pricing.manage';
  static const String createPromotion = 'marketplace.promotion.create';
  static const String managePromotion = 'marketplace.promotion.manage';

  /// Reports / Analytics
  static const String viewReports = 'marketplace.reports.view';
  static const String exportReports = 'marketplace.reports.export';

  /// Admin controls
  static const String manageMarketplaceSettings =
      'marketplace.settings.manage';
  static const String moderateListings = 'marketplace.listings.moderate';
  static const String resolveDisputes = 'marketplace.disputes.resolve';

  /// AI / Smart workflows
  static const String accessMarketplaceAI = 'marketplace.ai.access';
  static const String approveAIRecommendations =
      'marketplace.ai.approve_recommendations';

  /// Full registry for validation / seeding / policy sync
  static const List<String> all = [
    viewMarketplace,
    accessDashboard,

    createProduct,
    updateProduct,
    deleteProduct,
    publishProduct,
    manageInventory,

    viewOrders,
    createOrder,
    updateOrder,
    cancelOrder,
    approveOrder,

    viewPayments,
    managePayments,
    requestPayout,
    approvePayout,

    viewSuppliers,
    manageSuppliers,
    verifySupplier,

    managePricing,
    createPromotion,
    managePromotion,

    viewReports,
    exportReports,

    manageMarketplaceSettings,
    moderateListings,
    resolveDisputes,

    accessMarketplaceAI,
    approveAIRecommendations,
  ];
}
