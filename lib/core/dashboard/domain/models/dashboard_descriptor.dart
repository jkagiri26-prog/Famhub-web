@immutable
class DashboardDescriptor {
  // =========================
  // IDENTITY
  // =========================
  final String id;
  final String moduleKey;
  final String widgetKey;
  final String descriptorName;

  // =========================
  // LAYOUT CONTROL
  // =========================
  final int displayOrder;
  final int priority;
  final String layoutZone;

  // =========================
  // RENDER CONFIG
  // =========================
  final Map<String, dynamic> config;
  final String descriptorType;

  // =========================
  // SYSTEM BEHAVIOR HINTS
  // =========================
  final String cacheStrategy;
  final bool requiresEntityContext;

  // =========================
  // ACCESS CONTROL
  // =========================
  final String? featureFlagKey;
  final bool isEnabled;
  final bool isPremium;
  final String visibilityScope;

  final bool mobileVisibility;
  final bool tabletVisibility;
  final bool desktopVisibility;

  // =========================
  // CONSTRUCTOR
  // =========================