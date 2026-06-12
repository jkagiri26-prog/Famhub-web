class PolicyDecisionService {
  const PolicyDecisionService({
    required this.moduleService,
    required this.accessEngine,
    required this.subscriptionService,
  });

  final dynamic moduleService;
  final dynamic accessEngine;
  final dynamic subscriptionService;

  bool canAccess({
    required String moduleKey,
    required String resourceKey,
  }) {
    /// 1. Structural availability (module system)
    final isModuleEnabled = moduleService.isEnabled(moduleKey);
    if (!isModuleEnabled) return false;

    /// 2. Permission layer (RBAC / roles / admin)
    final hasAccess = accessEngine.canAccess(resourceKey);
    if (!hasAccess) return false;

    /// 3. Subscription / entitlement layer
    final hasSubscriptionAccess =
        subscriptionService.hasAccess(moduleKey);
    if (!hasSubscriptionAccess) return false;

    return true;
  }
}