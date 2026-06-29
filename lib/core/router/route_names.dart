/// ============================================================
/// ROUTE NAMES (SINGLE SOURCE OF ROUTE CONSTANTS)
/// ============================================================
///
/// 🧠 ARCHITECTURAL ROLE:
///   core/router/route_names.dart = route constant definitions
///
/// ✅ Rules:
///   - ALL module routes defined here
///   - ALL named routes defined here
///   - System routes defined here
///
/// ❌ Does NOT:
///   - Import registries
///   - Configure GoRouter
///   - Import any UI
/// ============================================================
class AppRoutes {
  // =========================
  // CORE SHELL ENTRY POINTS
  // =========================

  /// Root dashboard (OS home)
  static const root = '/';

  /// Named route key for root
  static const rootName = 'root';

  /// Generic dynamic module route
  static const module = '/module/:id';

  // =========================
  // MODULE ROUTES
  // =========================

  /// Farm module
  static const farm = '/farm';
  static const farmName = 'farm';

  /// Marketplace module
  static const marketplace = '/marketplace';
  static const marketplaceName = 'marketplace';

  /// Analytics module
  static const analytics = '/analytics';
  static const analyticsName = 'analytics';

  /// Financing module
  static const financing = '/financing';
  static const financingName = 'financing';

  /// Logistics module
  static const logistics = '/logistics';
  static const logisticsName = 'logistics';

  /// Traceability module
  static const traceability = '/traceability';
  static const traceabilityName = 'traceability';

  /// Carbon credit module
  static const carbonCredit = '/carbon-credit';
  static const carbonCreditName = 'carbonCredit';

  /// Knowledge link module
  static const knowledge = '/knowledge';
  static const knowledgeName = 'knowledge';

  /// Agribusiness module
  static const agribusiness = '/agribusiness';
  static const agribusinessName = 'agribusiness';

  /// Opportunities module
  static const opportunities = '/opportunities';
  static const opportunitiesName = 'opportunities';

  /// Extension services module
  static const extension = '/extension';
  static const extensionName = 'extension';

  /// Agri connect module
  static const connect = '/connect';
  static const connectName = 'agriConnect';

  /// Agri tech lab module
  static const techLab = '/tech-lab';
  static const techLabName = 'agriTechLab';

  /// Referral hub module
  static const referrals = '/referrals';
  static const referralsName = 'referrals';

  /// Profile module
  static const profile = '/profile';
  static const profileName = 'profile';

  /// Settings (nested under profile)
  static const settings = '/profile/settings';
  static const settingsName = 'settings';

  /// Admin console module
  static const admin = '/admin';
  static const adminName = 'admin';

  /// Guest page
  static const guest = '/guest';
  static const guestName = 'guest';

  // =========================
  // SYSTEM
  // =========================

    // =========================
  // ENTERPRISE PHASE: SYSTEM PAGES
  // =========================

  /// Home screen
  static const home = '/home';
  static const homeName = 'home';

  /// Global search
  static const search = '/search';
  static const searchName = 'search';

  /// Notification center
  static const notifications = '/notifications';
  static const notificationsName = 'notifications';

  /// Command palette
  static const commandPalette = '/command-palette';
  static const commandPaletteName = 'commandPalette';

  /// Runtime settings
  static const runtimeSettings = '/settings';
  static const runtimeSettingsName = 'runtimeSettings';

  /// Reports center
  static const reports = '/reports';
  static const reportsName = 'reports';

  /// AI assistant
  static const aiAssistant = '/ai-assistant';
  static const aiAssistantName = 'aiAssistant';

  /// 404 fallback
  static const notFound = '/404';
}