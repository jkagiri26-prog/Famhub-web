/// ============================================================
/// MODULE RUNTIME DESCRIPTOR (PURE DATA MODEL)
/// ============================================================
///
/// ⚡ CORE ARCHITECTURE RULE:
/// The backend (system.modules) is the ONLY source of truth.
///
/// This descriptor is the runtime representation that every module
/// contributes. It contains ONLY metadata, widget builders,
/// and contribution points — NO widget trees, NO rendering logic.
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/domain/models/ = composition domain models
///
/// ✅ Responsibilities:
///   - Pure data model for module runtime contributions
///   - Defines widget builders, dashboard widgets, home widgets,
///     quick actions, notification providers, search providers,
///     analytics providers, routes, permissions, AI providers,
///     command palette actions, settings pages, reports, and more
///
/// ❌ Does NOT:
///   - Render UI
///   - Import Flutter widgets directly
///   - Reference registries
///   - Contain business logic
/// ============================================================
library;

/// ============================================================
/// MODULE RUNTIME DESCRIPTOR
/// ============================================================
///
/// Every module exposes one of these. The Runtime Composition Engine
/// uses descriptors to build the entire UI — not hardcoded references.
/// ============================================================
class ModuleRuntimeDescriptor {
  /// Module identifier key (matches system.modules.module_key)
  final String moduleKey;

  /// Human-readable display name
  final String displayName;

  /// Module description
  final String description;

  /// Icon key for UI resolution
  final String iconKey;

  /// Entry route path
  final String route;

  /// Display order for sorting
  final int displayOrder;

  // ── Dashboard Widget Contributions ──
  final List<DashboardWidgetDescriptor> dashboardWidgets;

  // ── Home Screen Contributions ──
  final List<HomeWidgetDescriptor> homeWidgets;

  // ── Quick Action Contributions ──
  final List<QuickActionDescriptor> quickActions;

  // ── Notification Providers ──
  final List<NotificationProviderDescriptor> notificationProviders;

  // ── Search Providers ──
  final List<SearchProviderDescriptor> searchProviders;

  // ── Analytics Providers ──
  final List<AnalyticsProviderDescriptor> analyticsProviders;

  // ── Routes ──
  final List<RouteDescriptor> routes;

  // ── Permissions ──
  final List<PermissionDescriptor> permissions;

  // ── Enterprise Phase: AI Provider Contributions ──
  final List<AIProviderDescriptor> aiProviders;

  // ── Enterprise Phase: Command Palette Actions ──
  final List<CommandPaletteActionDescriptor> commandPaletteActions;

  // ── Enterprise Phase: Settings Pages ──
  final List<SettingsPageDescriptor> settingsPages;

  // ── Enterprise Phase: Reports ──
  final List<ReportDescriptor> reports;

  // ── Enterprise Phase: Background Jobs ──
  final List<BackgroundJobDescriptor> backgroundJobs;

  // ── Enterprise Phase: Floating Action Buttons ──
  final List<FloatingActionButtonDescriptor> floatingActionButtons;

  // ── Enterprise Phase: Export Providers ──
  final List<ExportProviderDescriptor> exportProviders;

  // ── Enterprise Phase: Import Providers ──
  final List<ImportProviderDescriptor> importProviders;

  // ── Enterprise Phase: Activity Timeline Items ──
  final List<ActivityTimelineItemDescriptor> activityTimelineItems;

  // ── Enterprise Phase: Help Articles ──
  final List<HelpArticleDescriptor> helpArticles;

  // ── Enterprise Phase: Context Menus ──
  final List<ContextMenuDescriptor> contextMenus;

  // ── Enterprise Phase: Entity Actions ──
  final List<EntityActionDescriptor> entityActions;

  // ── Enterprise Phase: Workflow Steps ──
  final List<WorkflowStepDescriptor> workflowSteps;

  // ── Enterprise Phase: Approval Actions ──
  final List<ApprovalActionDescriptor> approvalActions;

  // ── Shell Extension Points ──
  final List<ShellExtensionDescriptor> shellExtensions;

  const ModuleRuntimeDescriptor({
    required this.moduleKey,
    required this.displayName,
    this.description = '',
    this.iconKey = 'widgets',
    this.route = '',
    this.displayOrder = 999,
    this.dashboardWidgets = const [],
    this.homeWidgets = const [],
    this.quickActions = const [],
    this.notificationProviders = const [],
    this.searchProviders = const [],
    this.analyticsProviders = const [],
    this.routes = const [],
    this.permissions = const [],
    this.aiProviders = const [],
    this.commandPaletteActions = const [],
    this.settingsPages = const [],
    this.reports = const [],
    this.backgroundJobs = const [],
    this.floatingActionButtons = const [],
    this.exportProviders = const [],
    this.importProviders = const [],
    this.activityTimelineItems = const [],
    this.helpArticles = const [],
    this.contextMenus = const [],
    this.entityActions = const [],
    this.workflowSteps = const [],
    this.approvalActions = const [],
    this.shellExtensions = const [],
  });
}

/// ============================================================
/// DASHBOARD WIDGET DESCRIPTOR
/// ============================================================
///
/// A widget contribution for the dashboard.
/// The dashboard engine composes these into sections.
/// ============================================================
class DashboardWidgetDescriptor {
  /// Module key this widget belongs to
  final String moduleKey;

  /// Unique widget key for registry lookup
  final String widgetKey;

  /// Human-readable name
  final String displayName;

  /// Section this widget belongs to (e.g., 'farm', 'marketplace', 'finance')
  final String sectionKey;

  /// Display order within section
  final int displayOrder;

  /// Widget width in grid units (1-6)
  final int width;

  /// Widget height in grid units (1-6)
  final int height;

  /// Whether this widget is visible by default
  final bool isVisibleByDefault;

  /// Icon key for widget header
  final String iconKey;

  /// Refresh interval in seconds (0 = no auto-refresh)
  final int refreshIntervalSeconds;

  const DashboardWidgetDescriptor({
    required this.moduleKey,
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

/// ============================================================
/// HOME WIDGET DESCRIPTOR
/// ============================================================
///
/// A widget contribution for the home screen.
/// Types include: card, promotion, tip, announcement, pinned_action, news, alert
/// ============================================================
class HomeWidgetDescriptor {
  /// Unique widget key
  final String widgetKey;

  /// Widget type (card, promotion, tip, announcement, pinned_action, news, alert)
  final String widgetType;

  /// Human-readable name
  final String displayName;

  /// Display order
  final int displayOrder;

  /// Icon key
  final String iconKey;

  /// Priority (higher = more prominent)
  final int priority;

  /// Whether visible by default
  final bool isVisibleByDefault;

  const HomeWidgetDescriptor({
    required this.widgetKey,
    required this.widgetType,
    required this.displayName,
    this.displayOrder = 0,
    this.iconKey = 'widgets',
    this.priority = 0,
    this.isVisibleByDefault = true,
  });
}

/// ============================================================
/// QUICK ACTION DESCRIPTOR
/// ============================================================
///
/// A quick action that appears in the launcher/quick action bar.
/// ============================================================
class QuickActionDescriptor {
  /// Unique action key
  final String actionKey;

  /// Human-readable label
  final String label;

  /// Icon key
  final String iconKey;

  /// Display order
  final int displayOrder;

  /// Whether visible by default
  final bool isVisibleByDefault;

  /// Route or action identifier
  final String? route;

  /// Whether this is a primary action
  final bool isPrimary;

  const QuickActionDescriptor({
    required this.actionKey,
    required this.label,
    this.iconKey = 'add',
    this.displayOrder = 0,
    this.isVisibleByDefault = true,
    this.route,
    this.isPrimary = false,
  });
}

/// ============================================================
/// NOTIFICATION PROVIDER DESCRIPTOR
/// ============================================================
///
/// A notification provider that the Notification Center aggregates.
/// ============================================================
class NotificationProviderDescriptor {
  /// Unique provider key
  final String providerKey;

  /// Human-readable provider name
  final String displayName;

  /// Notification types this provider supports
  final List<String> notificationTypes;

  /// Whether enabled by default
  final bool enabledByDefault;

  const NotificationProviderDescriptor({
    required this.providerKey,
    required this.displayName,
    this.notificationTypes = const [],
    this.enabledByDefault = true,
  });
}

/// ============================================================
/// SEARCH PROVIDER DESCRIPTOR
/// ============================================================
///
/// A search provider that registers searchable entities.
/// ============================================================
class SearchProviderDescriptor {
  /// Unique provider key
  final String providerKey;

  /// Human-readable provider name
  final String displayName;

  /// Searchable entity types this provider offers
  final List<String> entityTypes;

  /// Whether enabled by default
  final bool enabledByDefault;

  const SearchProviderDescriptor({
    required this.providerKey,
    required this.displayName,
    this.entityTypes = const [],
    this.enabledByDefault = true,
  });
}

/// ============================================================
/// ANALYTICS PROVIDER DESCRIPTOR
/// ============================================================
///
/// An analytics provider that contributes metrics.
/// ============================================================
class AnalyticsProviderDescriptor {
  /// Unique provider key
  final String providerKey;

  /// Human-readable provider name
  final String displayName;

  /// Metric keys this provider tracks
  final List<String> metricKeys;

  /// Whether enabled by default
  final bool enabledByDefault;

  const AnalyticsProviderDescriptor({
    required this.providerKey,
    required this.displayName,
    this.metricKeys = const [],
    this.enabledByDefault = true,
  });
}

/// ============================================================
/// ROUTE DESCRIPTOR
/// ============================================================
///
/// A route contributed by a module.
/// ============================================================
class RouteDescriptor {
  /// Route path
  final String path;

  /// Route name for named navigation
  final String? name;

  /// Whether this is the primary/entry route
  final bool isPrimary;

  /// Display order
  final int displayOrder;

  const RouteDescriptor({
    required this.path,
    this.name,
    this.isPrimary = false,
    this.displayOrder = 0,
  });
}

/// ============================================================
/// PERMISSION DESCRIPTOR
/// ============================================================
///
/// A permission that a module declares.
/// ============================================================
class PermissionDescriptor {
  /// Permission key
  final String permissionKey;

  /// Human-readable permission name
  final String displayName;

  /// Permission description
  final String? description;

  /// Whether this is a system permission
  final bool isSystem;

  const PermissionDescriptor({
    required this.permissionKey,
    required this.displayName,
    this.description,
    this.isSystem = false,
  });
}

// ============================================================
// ENTERPRISE PHASE: EXTENDED DESCRIPTOR TYPES
// ============================================================

/// ============================================================
/// AI PROVIDER DESCRIPTOR (ENTERPRISE PHASE)
/// ============================================================
class AIProviderDescriptor {
  final String providerKey;
  final String displayName;
  final String capability;
  final String description;
  final int priority;
  final bool enabledByDefault;
  final Map<String, dynamic> configuration;

  const AIProviderDescriptor({
    required this.providerKey,
    required this.displayName,
    required this.capability,
    this.description = '',
    this.priority = 0,
    this.enabledByDefault = true,
    this.configuration = const {},
  });
}

/// ============================================================
/// COMMAND PALETTE ACTION DESCRIPTOR (ENTERPRISE PHASE)
/// ============================================================
class CommandPaletteActionDescriptor {
  final String actionKey;
  final String label;
  final String description;
  final String category;
  final String iconKey;
  final String? route;
  final String? actionId;
  final int priority;
  final List<String> keywords;
  final bool enabledByDefault;

  const CommandPaletteActionDescriptor({
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
  });
}

/// ============================================================
/// SETTINGS PAGE DESCRIPTOR (ENTERPRISE PHASE)
/// ============================================================
class SettingsPageDescriptor {
  final String settingsKey;
  final String displayName;
  final String description;
  final String iconKey;
  final String category;
  final int displayOrder;
  final String? route;
  final bool enabledByDefault;

  const SettingsPageDescriptor({
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

/// ============================================================
/// REPORT DESCRIPTOR (ENTERPRISE PHASE)
/// ============================================================
class ReportDescriptor {
  final String reportKey;
  final String displayName;
  final String description;
  final String iconKey;
  final String category;
  final int displayOrder;
  final bool enabledByDefault;

  const ReportDescriptor({
    required this.reportKey,
    required this.displayName,
    this.description = '',
    this.iconKey = 'description',
    required this.category,
    this.displayOrder = 0,
    this.enabledByDefault = true,
  });
}

/// ============================================================
/// BACKGROUND JOB DESCRIPTOR (ENTERPRISE PHASE)
/// ============================================================
class BackgroundJobDescriptor {
  final String jobKey;
  final String displayName;
  final String description;
  final String schedule;
  final bool enabledByDefault;
  final int priority;

  const BackgroundJobDescriptor({
    required this.jobKey,
    required this.displayName,
    this.description = '',
    required this.schedule,
    this.enabledByDefault = true,
    this.priority = 0,
  });
}

/// ============================================================
/// FLOATING ACTION BUTTON DESCRIPTOR (ENTERPRISE PHASE)
/// ============================================================
class FloatingActionButtonDescriptor {
  final String actionKey;
  final String label;
  final String iconKey;
  final String? route;
  final String? actionId;
  final int priority;
  final String? screenRoute;
  final bool enabledByDefault;

  const FloatingActionButtonDescriptor({
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

/// ============================================================
/// EXPORT PROVIDER DESCRIPTOR (ENTERPRISE PHASE)
/// ============================================================
class ExportProviderDescriptor {
  final String providerKey;
  final String displayName;
  final List<String> formats;
  final List<String> entityTypes;
  final bool enabledByDefault;

  const ExportProviderDescriptor({
    required this.providerKey,
    required this.displayName,
    this.formats = const ['csv'],
    this.entityTypes = const [],
    this.enabledByDefault = true,
  });
}

/// ============================================================
/// IMPORT PROVIDER DESCRIPTOR (ENTERPRISE PHASE)
/// ============================================================
class ImportProviderDescriptor {
  final String providerKey;
  final String displayName;
  final List<String> formats;
  final List<String> entityTypes;
  final bool enabledByDefault;

  const ImportProviderDescriptor({
    required this.providerKey,
    required this.displayName,
    this.formats = const ['csv'],
    this.entityTypes = const [],
    this.enabledByDefault = true,
  });
}

/// ============================================================
/// ACTIVITY TIMELINE ITEM DESCRIPTOR (ENTERPRISE PHASE)
/// ============================================================
class ActivityTimelineItemDescriptor {
  final String activityKey;
  final String displayName;
  final String iconKey;
  final String category;
  final int displayOrder;
  final bool enabledByDefault;

  const ActivityTimelineItemDescriptor({
    required this.activityKey,
    required this.displayName,
    this.iconKey = 'history',
    required this.category,
    this.displayOrder = 0,
    this.enabledByDefault = true,
  });
}

/// ============================================================
/// HELP ARTICLE DESCRIPTOR (ENTERPRISE PHASE)
/// ============================================================
class HelpArticleDescriptor {
  final String articleKey;
  final String title;
  final String summary;
  final String category;
  final List<String> tags;
  final int displayOrder;
  final bool enabledByDefault;

  const HelpArticleDescriptor({
    required this.articleKey,
    required this.title,
    this.summary = '',
    required this.category,
    this.tags = const [],
    this.displayOrder = 0,
    this.enabledByDefault = true,
  });
}

/// ============================================================
/// CONTEXT MENU DESCRIPTOR (ENTERPRISE PHASE)
/// ============================================================
class ContextMenuDescriptor {
  final String actionKey;
  final String label;
  final String iconKey;
  final String entityType;
  final int displayOrder;
  final bool destructive;
  final String? route;
  final String? actionId;
  final bool enabledByDefault;

  const ContextMenuDescriptor({
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

/// ============================================================
/// ENTITY ACTION DESCRIPTOR (ENTERPRISE PHASE)
/// ============================================================
class EntityActionDescriptor {
  final String actionKey;
  final String label;
  final String iconKey;
  final String entityType;
  final int displayOrder;
  final String? route;
  final String? actionId;
  final bool isPrimary;
  final bool enabledByDefault;

  const EntityActionDescriptor({
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

/// ============================================================
/// WORKFLOW STEP DESCRIPTOR (ENTERPRISE PHASE)
/// ============================================================
class WorkflowStepDescriptor {
  final String stepKey;
  final String displayName;
  final String description;
  final String workflowKey;
  final int stepOrder;
  final bool enabledByDefault;

  const WorkflowStepDescriptor({
    required this.stepKey,
    required this.displayName,
    this.description = '',
    required this.workflowKey,
    required this.stepOrder,
    this.enabledByDefault = true,
  });
}

/// ============================================================
/// APPROVAL ACTION DESCRIPTOR (ENTERPRISE PHASE)
/// ============================================================
class ApprovalActionDescriptor {
  final String actionKey;
  final String displayName;
  final String description;
  final String entityType;
  final List<String> requiredRoles;
  final bool enabledByDefault;

  const ApprovalActionDescriptor({
    required this.actionKey,
    required this.displayName,
    this.description = '',
    required this.entityType,
    this.requiredRoles = const [],
    this.enabledByDefault = true,
  });
}

/// ============================================================
/// SHELL EXTENSION DESCRIPTOR (SHELL CONTRIBUTION POINT)
/// ============================================================
///
/// A module contributes a shell extension to specify that it wants
/// to place a widget in a shell region slot. The descriptor contains
/// ONLY metadata — no widget trees, no rendering logic.
///
/// The shell renders these by matching the slot identifier. The shell
/// never knows what the widget represents — it just renders it.
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/domain/models/ = composition domain models
///
/// ✅ Responsibilities:
///   - Pure data model for shell extension metadata
///   - Defines slot, priority, feature flag key
///   - NO widget builders, NO rendering logic
///
/// ❌ Does NOT:
///   - Import Flutter widgets
///   - Reference shell internals
///   - Contain business logic
/// ============================================================
class ShellExtensionDescriptor {
  /// Unique identifier for this extension
  final String id;

  /// Shell slot this extension belongs to
  /// Matches ShellExtensionSlot enum values in shell/domain/contracts
  final String slot;

  /// Priority for ordering (lower = higher priority)
  final int priority;

  /// Key used for feature flag evaluation
  final String? featureFlagKey;

  /// Whether this extension requires the module to be enabled
  final bool requireModuleEnabled;

  /// Whether this extension should be hidden in maintenance mode
  final bool hideInMaintenance;

  const ShellExtensionDescriptor({
    required this.id,
    required this.slot,
    this.priority = 100,
    this.featureFlagKey,
    this.requireModuleEnabled = true,
    this.hideInMaintenance = true,
  });
}
