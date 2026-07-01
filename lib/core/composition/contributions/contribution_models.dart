/// ============================================================
/// RUNTIME CONTRIBUTION MODELS (ENTERPRISE PHASE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/contributions/ = runtime contribution engine
///
/// ✅ Responsibilities:
///   - Define ALL contribution types that modules can contribute
///   - Pure data models — NO widget trees, NO rendering logic
///   - Every user-facing capability is composed from these
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Extends existing ModuleRuntimeDescriptor, does NOT replace it
///   - Each contribution type maps to a ModuleDescriptor field
///   - Governance is applied by the Contribution Engine, not by models
/// ============================================================
library;

// ============================================================
// 1. DASHBOARD WIDGET CONTRIBUTION
// ============================================================
class DashboardWidgetContribution {
  final String widgetKey;
  final String displayName;
  final String sectionKey;
  final int displayOrder;
  final int width;
  final int height;
  final bool isVisibleByDefault;
  final String iconKey;
  final int refreshIntervalSeconds;

  const DashboardWidgetContribution({
    required this.widgetKey,
    required this.displayName,
    required this.sectionKey,
    this.displayOrder = 0,
    this.width = 1,
    this.height = 1,
    this.isVisibleByDefault = true,
    this.iconKey = 'widgets',
    this.refreshIntervalSeconds = 0,
  });
}

// ============================================================
// 2. HOME WIDGET CONTRIBUTION
// ============================================================
class HomeWidgetContribution {
  final String widgetKey;
  final String widgetType; // greeting, alert, news, promotion, weather, recommended_action, pinned_module, quick_action, recent_activity, ai_suggestion
  final String displayName;
  final int displayOrder;
  final String iconKey;
  final int priority;
  final bool isVisibleByDefault;

  const HomeWidgetContribution({
    required this.widgetKey,
    required this.widgetType,
    required this.displayName,
    this.displayOrder = 0,
    this.iconKey = 'widgets',
    this.priority = 0,
    this.isVisibleByDefault = true,
  });
}

// ============================================================
// 3. QUICK ACTION CONTRIBUTION
// ============================================================
class QuickActionContribution {
  final String actionKey;
  final String label;
  final String iconKey;
  final int displayOrder;
  final bool isVisibleByDefault;
  final String? route;
  final String? actionId;
  final bool isPrimary;
  final String? moduleId;

  const QuickActionContribution({
    required this.actionKey,
    required this.label,
    this.iconKey = 'add',
    this.displayOrder = 0,
    this.isVisibleByDefault = true,
    this.route,
    this.actionId,
    this.isPrimary = false,
    this.moduleId,
  });
}

// ============================================================
// 4. ROUTE CONTRIBUTION
// ============================================================
class RouteContribution {
  final String path;
  final String? name;
  final bool isPrimary;
  final int displayOrder;
  final String? moduleId;

  const RouteContribution({
    required this.path,
    this.name,
    this.isPrimary = false,
    this.displayOrder = 0,
    this.moduleId,
  });
}

// ============================================================
// 5. NOTIFICATION PROVIDER CONTRIBUTION
// ============================================================
class NotificationProviderContribution {
  final String providerKey;
  final String displayName;
  final String channel; // push, email, in_app, sms
  final int priority;
  final String category;
  final String iconKey;
  final bool supportsBadge;
  final List<NotificationActionContribution> actions;
  final List<String> notificationTypes;
  final bool enabledByDefault;

  const NotificationProviderContribution({
    required this.providerKey,
    required this.displayName,
    this.channel = 'in_app',
    this.priority = 0,
    this.category = 'general',
    this.iconKey = 'notifications',
    this.supportsBadge = true,
    this.actions = const [],
    this.notificationTypes = const [],
    this.enabledByDefault = true,
  });
}

class NotificationActionContribution {
  final String actionKey;
  final String label;
  final String? route;
  final bool destructive;

  const NotificationActionContribution({
    required this.actionKey,
    required this.label,
    this.route,
    this.destructive = false,
  });
}

// ============================================================
// 6. SEARCH PROVIDER CONTRIBUTION
// ============================================================
class SearchProviderContribution {
  final String providerKey;
  final String displayName;
  final String entityType;
  final String searchRepository;
  final int priority;
  final List<String> filters;
  final List<String> permissions;
  final bool enabledByDefault;

  const SearchProviderContribution({
    required this.providerKey,
    required this.displayName,
    required this.entityType,
    required this.searchRepository,
    this.priority = 0,
    this.filters = const [],
    this.permissions = const [],
    this.enabledByDefault = true,
  });
}

// ============================================================
// 7. ANALYTICS PROVIDER CONTRIBUTION
// ============================================================
class AnalyticsProviderContribution {
  final String providerKey;
  final String displayName;
  final List<String> metricKeys;
  final bool enabledByDefault;

  const AnalyticsProviderContribution({
    required this.providerKey,
    required this.displayName,
    this.metricKeys = const [],
    this.enabledByDefault = true,
  });
}

// ============================================================
// 8. AI PROVIDER CONTRIBUTION
// ============================================================
class AIProviderContribution {
  final String providerKey;
  final String displayName;
  final String capability; // price_recommendation, demand_forecast, crop_advisor, disease_detection, weather_advice, loan_eligibility, cashflow_prediction, knowledge_search, document_qa
  final String description;
  final int priority;
  final bool enabledByDefault;
  final Map<String, dynamic> configuration;

  const AIProviderContribution({
    required this.providerKey,
    required this.displayName,
    required this.capability,
    this.description = '',
    this.priority = 0,
    this.enabledByDefault = true,
    this.configuration = const {},
  });
}

// ============================================================
// 9. COMMAND PALETTE ACTION CONTRIBUTION
// ============================================================
class CommandPaletteActionContribution {
  final String actionKey;
  final String label;
  final String description;
  final String category; // marketplace, farm, finance, knowledge, general
  final String iconKey;
  final String? route;
  final String? actionId;
  final int priority;
  final List<String> keywords;
  final bool enabledByDefault;
  final String? moduleId;

  const CommandPaletteActionContribution({
    required this.actionKey,
    required this.label,
    this.description = '',
    required this.category,
    this.iconKey = 'terminal',
    this.route,
    this.actionId,
    this.priority = 0,
    this.keywords = const [],
    this.enabledByDefault = true,
    this.moduleId,
  });
}

// ============================================================
// 10. BACKGROUND JOB CONTRIBUTION
// ============================================================
class BackgroundJobContribution {
  final String jobKey;
  final String displayName;
  final String description;
  final String schedule; // cron expression or interval
  final bool enabledByDefault;
  final int priority;

  const BackgroundJobContribution({
    required this.jobKey,
    required this.displayName,
    this.description = '',
    required this.schedule,
    this.enabledByDefault = true,
    this.priority = 0,
  });
}

// ============================================================
// 11. FLOATING ACTION BUTTON CONTRIBUTION
// ============================================================
class FloatingActionButtonContribution {
  final String actionKey;
  final String label;
  final String iconKey;
  final String? route;
  final String? actionId;
  final int priority;
  final String? screenRoute; // which screen this FAB appears on
  final bool enabledByDefault;

  const FloatingActionButtonContribution({
    required this.actionKey,
    required this.label,
    this.iconKey = 'add',
    this.route,
    this.actionId,
    this.priority = 0,
    this.screenRoute,
    this.enabledByDefault = true,
  });
}

// ============================================================
// 12. SETTINGS PAGE CONTRIBUTION
// ============================================================
class SettingsPageContribution {
  final String settingsKey;
  final String displayName;
  final String description;
  final String iconKey;
  final String category; // general, notification, privacy, security, billing, about
  final int displayOrder;
  final String? route;
  final bool enabledByDefault;

  const SettingsPageContribution({
    required this.settingsKey,
    required this.displayName,
    this.description = '',
    this.iconKey = 'settings',
    required this.category,
    this.displayOrder = 0,
    this.route,
    this.enabledByDefault = true,
  });
}

// ============================================================
// 13. REPORT CONTRIBUTION
// ============================================================
class ReportContribution {
  final String reportKey;
  final String displayName;
  final String description;
  final String iconKey;
  final String category;
  final int displayOrder;
  final bool enabledByDefault;

  const ReportContribution({
    required this.reportKey,
    required this.displayName,
    this.description = '',
    this.iconKey = 'description',
    required this.category,
    this.displayOrder = 0,
    this.enabledByDefault = true,
  });
}

// ============================================================
// 14. EXPORT PROVIDER CONTRIBUTION
// ============================================================
class ExportProviderContribution {
  final String providerKey;
  final String displayName;
  final List<String> formats; // csv, xlsx, pdf, json
  final List<String> entityTypes;
  final bool enabledByDefault;

  const ExportProviderContribution({
    required this.providerKey,
    required this.displayName,
    this.formats = const ['csv'],
    this.entityTypes = const [],
    this.enabledByDefault = true,
  });
}

// ============================================================
// 15. IMPORT PROVIDER CONTRIBUTION
// ============================================================
class ImportProviderContribution {
  final String providerKey;
  final String displayName;
  final List<String> formats; // csv, xlsx, json
  final List<String> entityTypes;
  final bool enabledByDefault;

  const ImportProviderContribution({
    required this.providerKey,
    required this.displayName,
    this.formats = const ['csv'],
    this.entityTypes = const [],
    this.enabledByDefault = true,
  });
}

// ============================================================
// 16. ACTIVITY TIMELINE ITEM CONTRIBUTION
// ============================================================
class ActivityTimelineItemContribution {
  final String activityKey;
  final String displayName;
  final String iconKey;
  final String category;
  final int displayOrder;
  final bool enabledByDefault;

  const ActivityTimelineItemContribution({
    required this.activityKey,
    required this.displayName,
    this.iconKey = 'history',
    required this.category,
    this.displayOrder = 0,
    this.enabledByDefault = true,
  });
}

// ============================================================
// 17. HELP ARTICLE CONTRIBUTION
// ============================================================
class HelpArticleContribution {
  final String articleKey;
  final String title;
  final String summary;
  final String category;
  final List<String> tags;
  final int displayOrder;
  final bool enabledByDefault;

  const HelpArticleContribution({
    required this.articleKey,
    required this.title,
    this.summary = '',
    required this.category,
    this.tags = const [],
    this.displayOrder = 0,
    this.enabledByDefault = true,
  });
}

// ============================================================
// 18. CONTEXT MENU CONTRIBUTION
// ============================================================
class ContextMenuContribution {
  final String actionKey;
  final String label;
  final String iconKey;
  final String entityType;
  final int displayOrder;
  final bool destructive;
  final String? route;
  final String? actionId;
  final bool enabledByDefault;

  const ContextMenuContribution({
    required this.actionKey,
    required this.label,
    this.iconKey = 'more_vert',
    required this.entityType,
    this.displayOrder = 0,
    this.destructive = false,
    this.route,
    this.actionId,
    this.enabledByDefault = true,
  });
}

// ============================================================
// 19. ENTITY ACTION CONTRIBUTION
// ============================================================
class EntityActionContribution {
  final String actionKey;
  final String label;
  final String iconKey;
  final String entityType;
  final int displayOrder;
  final String? route;
  final String? actionId;
  final bool isPrimary;
  final bool enabledByDefault;

  const EntityActionContribution({
    required this.actionKey,
    required this.label,
    this.iconKey = 'touch_app',
    required this.entityType,
    this.displayOrder = 0,
    this.route,
    this.actionId,
    this.isPrimary = false,
    this.enabledByDefault = true,
  });
}

// ============================================================
// 20. WORKFLOW STEP CONTRIBUTION
// ============================================================
class WorkflowStepContribution {
  final String stepKey;
  final String displayName;
  final String description;
  final String workflowKey;
  final int stepOrder;
  final bool enabledByDefault;

  const WorkflowStepContribution({
    required this.stepKey,
    required this.displayName,
    this.description = '',
    required this.workflowKey,
    required this.stepOrder,
    this.enabledByDefault = true,
  });
}

// ============================================================
// 21. APPROVAL ACTION CONTRIBUTION
// ============================================================
class ApprovalActionContribution {
  final String actionKey;
  final String displayName;
  final String description;
  final String entityType;
  final List<String> requiredRoles;
  final bool enabledByDefault;

  const ApprovalActionContribution({
    required this.actionKey,
    required this.displayName,
    this.description = '',
    required this.entityType,
    this.requiredRoles = const [],
    this.enabledByDefault = true,
  });
}

// ============================================================
// 22. SHELL EXTENSION CONTRIBUTION
// ============================================================
///
/// Represents a module's desire to place a widget in a shell slot.
/// The shell ExtensionSlot renders these by consulting this contribution.
///
/// Governance is applied by the contribution engine:
///   - Disabled modules → extensions are filtered out
///   - Maintenance mode → extensions hidden (if hideInMaintenance)
///   - Feature flag → evaluated at build time
/// ============================================================
class ShellExtensionContribution {
  /// Unique identifier for this extension
  final String id;

  /// The module this extension originates from
  final String moduleId;

  /// Shell slot identifier (matches ShellExtensionSlot enum values)
  final String slot;

  /// Priority for ordering (lower = higher priority)
  final int priority;

  /// Key used for feature flag evaluation
  final String? featureFlagKey;

  /// Whether this extension should be hidden when the module is in maintenance
  final bool hideInMaintenance;

  const ShellExtensionContribution({
    required this.id,
    required this.moduleId,
    required this.slot,
    this.priority = 100,
    this.featureFlagKey,
    this.hideInMaintenance = true,
  });
}
