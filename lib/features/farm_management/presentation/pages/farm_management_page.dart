/// ============================================================
/// FARM MANAGEMENT PAGE (ORCHESTRATION LAYER)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/presentation/pages/ = page layer
///
/// ✅ Responsibilities (ONLY):
///   1. Initialize module lifecycle via bootstrap coordinator
///   2. Bootstrap providers
///   3. Load farm context
///   4. Decide which UI state to display:
///      - Loading → skeleton
///      - No farms → onboarding empty state
///      - Farms loaded → dashboard with registered widgets
///      - Error → error state with retry
///      - Offline → offline state
///   5. Render dashboard widgets through the dashboard engine
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Contain large hardcoded UI implementations
///   - Import widget implementations directly
///   - Bypass the Widget Registry
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Uses Module Bootstrap Coordinator for initialization
///   - Renders widgets exclusively through WidgetRegistry
///   - No manual KPI cards, Weather, Production, etc.
///   - Shell-compliant: no Scaffold, no AppBar
///   - Every state has a meaningful UI (loading/empty/error/offline/data)
/// ============================================================
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_registry.dart';
import 'package:famhub_app/core/composition/providers/descriptor_providers.dart';
import 'package:famhub_app/core/composition/domain/models/module_descriptor.dart';
import 'package:famhub_app/core/navigation/resize_optimizer.dart';

import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/shared/layouts/dashboard_section_widget.dart';
import 'package:famhub_app/shared/layouts/app_spacing_widget.dart';
import 'package:famhub_app/shared/widgets/module_error_boundary.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/offline_state_widget.dart';
import 'package:famhub_app/shared/demo/demo_banner_widget.dart' show ExploreBanner;

import 'package:famhub_app/features/farm_management/application/bootstrap/farm_module_bootstrap.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_selector_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_tab_navigation_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_onboarding_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/fields_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/crops_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/livestock_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/activities_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/add_farm_page.dart';
import 'package:famhub_app/features/farm_management/presentation/widgets/farm_setup_guide_widget.dart';
import 'package:famhub_app/features/farm_management/presentation/widgets/farm_onboarding_checklist_widget.dart';
import 'package:famhub_app/features/farm_management/presentation/widgets/farm_created_success_dialog.dart';

import 'package:famhub_app/features/farm_management/presentation/pages/farms_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/crops_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/livestock_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/activities_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/reports_page.dart';

const _farmManagementHistoryExtraKey = '_farmManagementHistory';

Map<String, Object?> _farmHistoryStringMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

/// ============================================================
/// FARM MANAGEMENT PAGE (PRIMARY MODULE ENTRY POINT)
/// ============================================================
///
/// Lightweight orchestration page that:
///   1. Calls bootstrapModule() on first build
///   2. Resolves farm selector state
///   3. Decides which state to render
///   4. Delegates rendering to dashboard engine
///
/// INITIALIZATION FLOW:
///   Open Module
///     ↓
///   Bootstrap Coordinator
///     ↓
///   Load Farms (auto-select default)
///     ↓
///   Resolve Farm Context
///     ↓
///   Dashboard Renderer
///     ├── Farm Selector
///     ├── Farm KPIs
///     ├── Farm Summary
///     ├── Weather
///     ├── Activities
///     ├── Production
///     ├── Stock
///     ├── Alerts
///     ├── Quick Actions
///     └── Future Widgets
/// ============================================================
class FarmManagementPage extends ConsumerStatefulWidget {
  const FarmManagementPage({super.key});

  @override
  ConsumerState<FarmManagementPage> createState() => _FarmManagementPageState();
}

class _FarmManagementPageState extends ConsumerState<FarmManagementPage>
    with SingleTickerProviderStateMixin {
  bool _bootstrapped = false;
  bool _historyReady = false;
  bool _restoringHistory = false;
  bool _historyRecordScheduled = false;
  late TabController _tabController;
  GoRouter? _router;
  String? _lastHistorySnapshot;
  String? _activitySelectionId;
  int _historyRestoreGeneration = 0;

  /// Bumped when the user re-taps the active Activity Logs tab so the
  /// page (whose detail view lives in local state) returns to its
  /// journal home.
  int _activitiesResetToken = 0;

  /// Whether ActivitiesPage's in-tab detail view is open. Reported by the
  /// page via its onDetailOpenChanged callback — the detail is local state
  /// the router cannot see, but system back must unwind it first.
  bool _activityDetailOpen = false;

  /// Last tab index at which the TabController settled (animation done).
  /// Used to rebuild when the tab changes so PopScope.canPop stays in sync.
  int _settledTabIndex = FarmManagementTab.overview;

  /// Keys per tab so we can scroll the strip to keep the active tab visible.
  late final List<GlobalKey> _tabKeys;

  /// 🏗️ Farm Workspace Tabs
  static const _tabDefs = <(String, IconData)>[
    ('Overview', Icons.dashboard),
    ('My Farms', Icons.agriculture),
    ('Crops', Icons.eco),
    ('Livestock', Icons.pets),
    ('Activity Logs', Icons.list_alt),
    ('Reports', Icons.description),
  ];

  @override
  void initState() {
    super.initState();
    _tabKeys =
        List<GlobalKey>.generate(_tabDefs.length, (_) => GlobalKey());
    _tabController = TabController(length: _tabDefs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _initializeModule();
  }

  @override
  void dispose() {
    _historyRestoreGeneration++;
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _router?.routerDelegate.removeListener(_onRouterChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (identical(router, _router)) return;
    _router?.routerDelegate.removeListener(_onRouterChanged);
    _router = router;
    router.routerDelegate.addListener(_onRouterChanged);
  }

  /// Keep the active tab fully visible in the (scrollable) tab strip,
  /// including when the tab is switched programmatically.
  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    // Rebuild once per settled tab switch so PopScope.canPop tracks the
    // tab the user is actually on (the controller notifies at settle).
    if (_tabController.index != _settledTabIndex) {
      _settledTabIndex = _tabController.index;
      if (mounted) setState(() {});
    }
    _scheduleBrowserHistoryRecord();
    final key = _tabKeys[_tabController.index].currentContext;
    if (key == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        key,
        alignment: 0.5,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// TabBar.onTap — fires AFTER TabController.animateTo (see
  /// TabBar._handleTap), so a tab SWITCH always arrives here with
  /// [TabController.indexIsChanging] == true. A re-tap of the already-
  /// active tab is short-circuited by TabController (same index → no-op)
  /// and arrives with indexIsChanging == false — that re-tap is the
  /// "return this tab to its home view" gesture.
  void _onTabTapped(int index) {
    if (_tabController.indexIsChanging) return;
    _resetTabToHome(index);
  }

  /// Return the given tab to its home/content view. Mirrors each tab's
  /// own back-arrow behaviour so every entry point stays consistent.
  void _resetTabToHome(int index) {
    final notifier = ref.read(hierarchyProvider.notifier);
    final state = ref.read(hierarchyProvider);
    switch (index) {
      case 1: // My Farms → farm list (FarmsPage back arrow)
        if (state.hasEntity) notifier.reset();
      case 2: // Crops → crops list (CropsPage._clearSelection)
        if (state.cropOrLivestockType == 'crop') notifier.clearToField();
      case 3: // Livestock → list (LivestockPage._clearSelection)
        if (state.cropOrLivestockType == 'livestock') notifier.clearToField();
      case 4: // Activity Logs → journal (detail lives in ActivitiesPage)
        setState(() => _activitiesResetToken++);
        _activitySelectionId = null;
      case 5: // Reports → global report (ReportsPage._resetToGlobal)
        if (state.hasEntity || state.cropOrLivestock != null) {
          notifier.reset();
        }
      default: // Overview (0) — the dashboard is already home.
        break;
    }
    _scheduleBrowserHistoryRecord();
  }

  /// Callback from ActivitiesPage reporting whether its in-tab detail view
  /// is open (kept in [_activityDetailOpen] for the system-back handler).
  void _onActivityDetailChanged(bool open) {
    if (!mounted || _activityDetailOpen == open) return;
    setState(() => _activityDetailOpen = open);
  }

  void _onActivitySelectionChanged(String? activityId) {
    if (_activitySelectionId == activityId) return;
    setState(() => _activitySelectionId = activityId);
    _scheduleBrowserHistoryRecord();
  }

  void _onRouterChanged() {
    final router = _router;
    if (!kIsWeb || !_historyReady || !mounted || router == null) return;
    final configuration = router.routerDelegate.currentConfiguration;
    if (configuration.uri.path != '/farm') {
      _historyRestoreGeneration++;
      _restoringHistory = false;
      return;
    }

    final routeExtra = _farmHistoryStringMap(configuration.extra);
    final rawSnapshot = routeExtra[_farmManagementHistoryExtraKey];
    if (rawSnapshot is! Map) return;
    final snapshot = _farmHistoryStringMap(rawSnapshot);
    final encoded = jsonEncode(snapshot);
    if (encoded == _lastHistorySnapshot) return;

    _lastHistorySnapshot = encoded;
    unawaited(_restoreBrowserHistory(snapshot));
  }

  void _scheduleBrowserHistoryRecord() {
    if (kIsWeb && !_restoringHistory) {
      _historyRestoreGeneration++;
    }
    if (!kIsWeb ||
        !_historyReady ||
        _restoringHistory ||
        _historyRecordScheduled ||
        _router?.routerDelegate.currentConfiguration.uri.path != '/farm') {
      return;
    }
    _historyRecordScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _historyRecordScheduled = false;
      if (!mounted || _restoringHistory) return;
      _writeBrowserHistory();
    });
  }

  void _writeBrowserHistory({bool replace = false}) {
    final router = _router;
    if (!kIsWeb ||
        router == null ||
        router.routerDelegate.currentConfiguration.uri.path != '/farm') {
      return;
    }
    final snapshot = _browserHistorySnapshot();
    final encoded = jsonEncode(snapshot);
    if (!replace && encoded == _lastHistorySnapshot) return;

    final configuration = router.routerDelegate.currentConfiguration;
    final routeExtra = _farmHistoryStringMap(configuration.extra);
    final extra = {
      ...routeExtra,
      _farmManagementHistoryExtraKey: snapshot,
    };
    _lastHistorySnapshot = encoded;
    final uri = configuration.uri;
    if (replace) {
      Router.neglect(context, () => router.go(uri.toString(), extra: extra));
    } else {
      Router.navigate(context, () => router.go(uri.toString(), extra: extra));
    }
  }

  Map<String, Object?> _browserHistorySnapshot() {
    final hierarchy = ref.read(hierarchyProvider);
    return {
      'tabIndex': _tabController.index,
      'entityId': hierarchy.entityId,
      'fieldId': hierarchy.fieldId,
      'assetId': hierarchy.cropOrLivestockId,
      'assetType': hierarchy.cropOrLivestockType,
      'activityId': _activitySelectionId,
    };
  }

  Future<void> _restoreBrowserHistory(Map<String, Object?> snapshot) async {
    final generation = ++_historyRestoreGeneration;
    _restoringHistory = true;
    final encodedTarget = jsonEncode(snapshot);
    try {
      final tabIndex = snapshot['tabIndex'] is int
          ? snapshot['tabIndex']! as int
          : FarmManagementTab.overview;
      final entityId = snapshot['entityId'] is String
          ? snapshot['entityId']! as String
          : null;
      final fieldId = snapshot['fieldId'] is String
          ? snapshot['fieldId']! as String
          : null;
      final assetId = snapshot['assetId'] is String
          ? snapshot['assetId']! as String
          : null;
      final assetType = snapshot['assetType'] is String
          ? snapshot['assetType']! as String
          : null;
      final activityId = snapshot['activityId'] is String
          ? snapshot['activityId']! as String
          : null;

      var farms = ref.read(farmSelectorProvider).farms;
      if (farms.isEmpty) {
        await ref.read(farmSelectorProvider.notifier).loadFarms();
        if (!mounted || generation != _historyRestoreGeneration) return;
        farms = ref.read(farmSelectorProvider).farms;
      }
      FarmEntity? farm;
      for (final candidate in farms) {
        if (candidate.id == entityId) {
          farm = candidate;
          break;
        }
      }
      if (farm == null && entityId != null) {
        await ref.read(farmSelectorProvider.notifier).loadFarms();
        if (!mounted || generation != _historyRestoreGeneration) return;
        farms = ref.read(farmSelectorProvider).farms;
        for (final candidate in farms) {
          if (candidate.id == entityId) {
            farm = candidate;
            break;
          }
        }
      }

      final hierarchy = ref.read(hierarchyProvider.notifier);
      FieldEntity? field;
      Object? asset;
      if (farm == null) {
        hierarchy.reset();
      } else {
        hierarchy.selectEntity(farm);
        hierarchy.clearToEntity();
        if (fieldId != null) {
          await ref.read(fieldsProvider.notifier).loadFields(farmId: farm.id);
          if (!mounted || generation != _historyRestoreGeneration) return;
          final fieldState = ref.read(fieldsProvider);
          if (fieldState.errorMessage == null) {
            for (final candidate in fieldState.fields) {
              if (candidate.id == fieldId && candidate.farmId == farm.id) {
                field = candidate;
                break;
              }
            }
          }
          if (field != null) {
            hierarchy.selectField(field);
            if (assetId != null && assetType == 'crop') {
              await ref
                  .read(cropsProvider.notifier)
                  .loadCrops(farmId: farm.id, fieldId: field.id);
              if (!mounted || generation != _historyRestoreGeneration) return;
              final cropState = ref.read(cropsProvider);
              if (cropState.errorMessage == null) {
                for (final candidate in cropState.crops) {
                  if (candidate.id == assetId &&
                      candidate.farmId == farm.id &&
                      candidate.fieldId == field.id) {
                    asset = candidate;
                    break;
                  }
                }
              }
              if (asset is CropEntity) {
                hierarchy.selectCrop(asset);
              }
            } else if (assetId != null && assetType == 'livestock') {
              await ref
                  .read(livestockProvider.notifier)
                  .loadLivestock(farmId: farm.id, fieldId: field.id);
              if (!mounted || generation != _historyRestoreGeneration) return;
              final livestockState = ref.read(livestockProvider);
              if (livestockState.errorMessage == null) {
                for (final candidate in livestockState.livestock) {
                  if (candidate.id == assetId &&
                      candidate.farmId == farm.id &&
                      candidate.fieldId == field.id) {
                    asset = candidate;
                    break;
                  }
                }
              }
              if (asset is LivestockEntity) {
                hierarchy.selectLivestock(asset);
              }
            }
          }
        }
      }

      String? restoredActivityId;
      if (activityId != null) {
        final activities = await ref.read(allUserActivitiesProvider.future);
        if (!mounted || generation != _historyRestoreGeneration) return;
        if (activities.any((entry) => entry.activity.id == activityId)) {
          restoredActivityId = activityId;
        }
      }

      if (!mounted || generation != _historyRestoreGeneration) return;
      setState(() {
        _activitySelectionId = restoredActivityId;
        if (tabIndex >= 0 && tabIndex < _tabDefs.length) {
          _tabController.animateTo(tabIndex);
        }
      });

      final restoredSnapshot = _browserHistorySnapshot();
      if (jsonEncode(restoredSnapshot) != encodedTarget) {
        _lastHistorySnapshot = null;
        _writeBrowserHistory(replace: true);
      } else {
        _lastHistorySnapshot = encodedTarget;
      }
    } finally {
      if (generation == _historyRestoreGeneration) {
        _restoringHistory = false;
      }
    }
  }

  /// Whether the current view has an internal destination that Android
  /// system back must unwind before the event is allowed to leave Farm
  /// Management (and, from the Overview root, the app).
  ///
  /// Mirrors the existing navigation model:
  ///  * Every non-default tab has at least one internal step: its own
  ///    detail/list hierarchy (rules 1–3) or, when already at the tab's
  ///    home view, the default Overview tab (rule 4).
  ///  * Overview is the workspace root. Explicit detail views opened in
  ///    other tabs (an asset detail or an open activity detail) still count
  ///    as internal destinations, so back returns to them instead of
  ///    exiting (rule 6). Hierarchy *context* (farm/field) does not gate
  ///    exit — `loadFarms` auto-selects the first farm at bootstrap, so
  ///    treating context as a destination would trap every back press.
  ///  * No destination left → back follows the router: pops to the page
  ///    Farm Management was pushed from, or exits at the true app root
  ///    (rules 5–6).
  ///
  /// Only checked at this page's own route: pushed forms/dialogs sit on
  /// top of it and consult their own routes first.
  bool _hasInternalBackDestination(HierarchySelectionState hierarchy) {
    if (_tabController.index != FarmManagementTab.overview) return true;
    return _activityDetailOpen || hierarchy.cropOrLivestock != null;
  }

  /// Unwind exactly one internal level in response to the Android system
  /// back button. Called only when [_hasInternalBackDestination] was true
  /// (PopScope.canPop == false), so every branch must consume the event.
  ///
  /// Each branch mirrors the tab's visible back-arrow semantics so the
  /// system back button and the on-screen arrows stay consistent.
  void _handleSystemBack() {
    final notifier = ref.read(hierarchyProvider.notifier);
    final hierarchy = ref.read(hierarchyProvider);

    switch (_tabController.index) {
      case FarmManagementTab.myFarms:
        // Farm detail with fields expanding inside it (rules 1–3):
        // collapse the expanded field first, then farm → farms list
        // (FarmsPage back arrow).
        if (hierarchy.hasEntity) {
          if (hierarchy.field != null) {
            notifier.clearToEntity();
          } else {
            notifier.reset();
          }
          return;
        }
        break;
      case FarmManagementTab.crops:
        // Crop detail → All Crops (CropsPage._clearSelection).
        if (hierarchy.cropOrLivestockType == 'crop' &&
            hierarchy.cropOrLivestock is CropEntity) {
          notifier.clearToField();
          return;
        }
        break;
      case FarmManagementTab.livestock:
        // Livestock detail → All Livestock (LivestockPage._clearSelection).
        if (hierarchy.cropOrLivestockType == 'livestock' &&
            hierarchy.cropOrLivestock is LivestockEntity) {
          notifier.clearToField();
          return;
        }
        break;
      case FarmManagementTab.activityLogs:
        // In-tab activity detail → journal list first (rule 1). The reset
        // token is the page's existing "return to home" path.
        if (_activityDetailOpen) {
          setState(() => _activitiesResetToken++);
          _activitySelectionId = null;
          return;
        }
        // Contextual journal opened from an asset → back to that asset's
        // detail, with the hierarchy context preserved (spec: activity logs
        // opened from a crop/livestock return to that crop/livestock).
        if (hierarchy.cropOrLivestock != null) {
          _tabController.animateTo(
            hierarchy.cropOrLivestockType == 'livestock'
                ? FarmManagementTab.livestock
                : FarmManagementTab.crops,
          );
          return;
        }
        break;
      case FarmManagementTab.reports:
        // Asset/farm report → global report (ReportsPage back arrows).
        if (hierarchy.hasEntity || hierarchy.cropOrLivestock != null) {
          notifier.reset();
          return;
        }
        break;
      default: // Overview
        // Only reachable while a detail view in another tab is open:
        // return to that detail instead of exiting (rule 6).
        if (_activityDetailOpen) {
          _tabController.animateTo(FarmManagementTab.activityLogs);
          return;
        }
        if (hierarchy.cropOrLivestock != null) {
          _tabController.animateTo(
            hierarchy.cropOrLivestockType == 'livestock'
                ? FarmManagementTab.livestock
                : FarmManagementTab.crops,
          );
          return;
        }
        break;
    }

    // Rule 4 — nothing deeper in this view: the previous internal view is
    // the default Overview tab (tabs have no separate navigation history;
    // hierarchy context is preserved, never reset).
    if (_tabController.index != FarmManagementTab.overview) {
      _tabController.animateTo(FarmManagementTab.overview);
    }
  }

  /// Initialize the module through the bootstrap coordinator.
  /// This happens automatically — the module never depends on
  /// another page having called loadFarms(), initializeDashboard(),
  /// or restoreContext().
  Future<void> _initializeModule() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    // Bootstrap the entire module lifecycle
    final coordinator = ref.read(farmModuleBootstrapCoordinatorProvider);
    await coordinator.bootstrapModule();
    if (!mounted) return;
    _historyReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !kIsWeb) return;
      final configuration = _router?.routerDelegate.currentConfiguration;
      if (configuration == null || configuration.uri.path != '/farm') return;
      final extra = _farmHistoryStringMap(configuration.extra);
      final rawSnapshot = extra[_farmManagementHistoryExtraKey];
      if (rawSnapshot is Map) {
        final snapshot = _farmHistoryStringMap(rawSnapshot);
        _lastHistorySnapshot = jsonEncode(snapshot);
        unawaited(_restoreBrowserHistory(snapshot));
      } else {
        _lastHistorySnapshot = null;
        _writeBrowserHistory(replace: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectorState = ref.watch(farmSelectorProvider);
    final hierarchy = ref.watch(hierarchyProvider);
    ref.listen(hierarchyProvider, (previous, next) {
      if (!_restoringHistory &&
          previous != null &&
          (previous.entityId != next.entityId ||
              previous.fieldId != next.fieldId ||
              previous.cropOrLivestockId != next.cropOrLivestockId ||
              previous.cropOrLivestockType != next.cropOrLivestockType)) {
        _activitySelectionId = null;
      }
      _scheduleBrowserHistoryRecord();
    });

    // Tab-switch requests from dashboard widgets (e.g. the farm selector's
    // "Open" action opens a farm inside the My Farms tab).
    ref.listen(farmTabNavigationProvider, (previous, next) {
      if (next != null && next.tabIndex != _tabController.index) {
        _tabController.animateTo(next.tabIndex);
      }
    });

    // Android system back / predictive back: intercepted at this page's
    // route so back unwinds internal workspace navigation first instead of
    // bubbling to the root navigator and closing the app (the tab views are
    // local/provider state, not routes, so the router has nothing to pop).
    // Pushed forms and dialogs sit on top of this route and are unaffected.
    return BackButtonListener(
      onBackButtonPressed: () async {
        if (kIsWeb || Navigator.of(context).canPop()) return false;
        if (!_hasInternalBackDestination(ref.read(hierarchyProvider))) {
          return false;
        }
        _handleSystemBack();
        return true;
      },
      child: PopScope(
        canPop: kIsWeb || !_hasInternalBackDestination(hierarchy),
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (didPop) return;
          _handleSystemBack();
        },
        child: ShellPageContent(
      title: 'Farm Management',
      subtitle: hierarchy.hasEntity
          ? hierarchy.entity!.farmName
          : 'Manage your farms, fields, crops, and livestock',
      scrollable: false,
      child: Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tab Bar ──
            SizedBox(
              width: double.infinity,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                onTap: _onTabTapped,
                tabs: [
                  for (var i = 0; i < _tabDefs.length; i++)
                    Tab(
                      key: _tabKeys[i],
                      text: _tabDefs[i].$1,
                      icon: Icon(_tabDefs[i].$2, size: 18),
                    ),
                ],
                indicatorColor: Theme.of(context).colorScheme.primary,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),

            // ── Tab Content ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 1. Overview — full farm dashboard
                  _buildOverviewTab(context, selectorState),

                  // 2. My Farms — hierarchy workspace (farm → field → asset)
                  FarmsPage(
                    onOpenCrops: () => _tabController.animateTo(2),
                    onOpenLivestock: () => _tabController.animateTo(3),
                  ),

                  // 3. Crops — global crop workspace (list ↔ in-tab details)
                  CropsPage(
                    onOpenActivities: () => _tabController.animateTo(4),
                    onGoToMyFarms: () => _tabController.animateTo(1),
                  ),

                  // 4. Livestock — global livestock workspace
                  LivestockPage(
                    onOpenActivities: () => _tabController.animateTo(4),
                    onGoToMyFarms: () => _tabController.animateTo(1),
                  ),

                  // 5. Activity Logs — global activity journal
                  ActivitiesPage(
                    onOpenCrops: () => _tabController.animateTo(2),
                    onOpenLivestock: () => _tabController.animateTo(3),
                    resetToken: _activitiesResetToken,
                    onDetailOpenChanged: _onActivityDetailChanged,
                    restoredActivityId: _activitySelectionId,
                    onActivitySelectionChanged: _onActivitySelectionChanged,
                  ),

                  // 6. Reports — reporting workspace
                  ReportsPage(
                    onOpenCrops: () => _tabController.animateTo(2),
                    onOpenLivestock: () => _tabController.animateTo(3),
                    onOpenActivities: () => _tabController.animateTo(4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }

  /// Overview tab: renders the farm selector-driven state machine
  /// (loading / error / empty onboarding / full dashboard) inside a
  /// scrollable area.
  Widget _buildOverviewTab(
    BuildContext context,
    FarmSelectorState selectorState,
  ) {
    // ── State 1: Loading ──
    if (selectorState.isLoading) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: _buildLoadingState(),
      );
    }

    // ── State 2: Error ──
    if (selectorState.errorMessage != null) {
      return _buildErrorState(context, selectorState.errorMessage!);
    }

    // ── State 3: Empty / No Farms ──
    if (selectorState.farms.isEmpty) {
      return _buildEmptyState(context, ref.watch(isAuthenticatedProvider));
    }

    // ── State 4: Data — full dashboard with registered widgets ──
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: _buildDashboard(context),
    );
  }

  /// ============================================================
  /// STATE: LOADING
  /// ============================================================
  ///
  /// Animated skeleton loader that gives the user visual feedback
  /// while farms are being loaded.
  /// ============================================================
  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Skeleton row 1
          _SkeletonBlock(width: 180, height: 20),
          SizedBox(height: 16),
          _SkeletonBlock(width: double.infinity, height: 80),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SkeletonBlock(width: double.infinity, height: 100)),
              SizedBox(width: 12),
              Expanded(child: _SkeletonBlock(width: double.infinity, height: 100)),
            ],
          ),
          SizedBox(height: 12),
          _SkeletonBlock(width: double.infinity, height: 60),
        ],
      ),
    );
  }

  /// ============================================================
  /// STATE: ERROR
  /// ============================================================
  ///
  /// Error message with a retry action.
  /// ============================================================
  Widget _buildErrorState(BuildContext context, String error) {
    return ErrorStateWidget(
      title: 'Unable to Load Farms',
      message: 'We encountered a problem loading your farm data. '
          'Please check your connection and try again.',
      retryLabel: 'Retry',
      onRetry: () {
        ref.read(farmSelectorProvider.notifier).loadFarms();
      },
      detailedError: error,
    );
  }

  /// ============================================================
  /// STATE: EMPTY (No Farms)
  /// ============================================================
  ///
  /// Professional onboarding experience for users with no farms.
  ///
  /// Includes:
  ///   - Welcome message
  ///   - Create Farm button
  ///   - Demo farm preview (guest mode)
  ///   - Quick Actions
  ///   - Marketplace shortcut
  /// ============================================================
  Widget _buildEmptyState(BuildContext context, bool isAuthenticated) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),

          // ── Guest Mode Banner ──
          if (!isAuthenticated)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: ExploreBanner(
                onSignIn: () {
                  // Navigate to sign in — handled by session gate
                },
              ),
            ),

          // ── Welcome Icon ──
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.agriculture_rounded,
              size: 40,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),

          // ── Welcome Title ──
          Text(
            'Welcome to Farm Management',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // ── Welcome Subtitle ──
          Text(
            'Get started by creating your first farm. '
            'Manage fields, track crops, monitor livestock, '
            'and record all your farming activities in one place.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // ── Create Farm Button ──
          SizedBox(
            width: 240,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddFarmPage(),
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text('Create Your First Farm'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // ── Quick Start Guide ──
          _buildQuickStartSection(context, theme),

          const SizedBox(height: 24),

          // ── Marketplace Shortcut ──
          _buildMarketplaceShortcut(context, theme),
        ],
      ),
    );
  }

  Widget _buildQuickStartSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Start Guide',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        const _QuickStartStep(
          icon: Icons.add_circle,
          title: 'Create a Farm',
          description: 'Add your farm with name, location, and size',
          color: Colors.green,
        ),
        const SizedBox(height: 12),
        const _QuickStartStep(
          icon: Icons.terrain,
          title: 'Add Fields',
          description: 'Define your farm fields and growing areas',
          color: Colors.brown,
        ),
        const SizedBox(height: 12),
        const _QuickStartStep(
          icon: Icons.eco,
          title: 'Plant Crops',
          description: 'Track what you plant and when',
          color: Colors.teal,
        ),
        const SizedBox(height: 12),
        const _QuickStartStep(
          icon: Icons.pets,
          title: 'Add Livestock',
          description: 'Manage your animals and their health',
          color: Colors.orange,
        ),
        const SizedBox(height: 12),
        const _QuickStartStep(
          icon: Icons.edit_note,
          title: 'Record Activities',
          description: 'Log daily farming operations',
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildMarketplaceShortcut(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.06),
            theme.colorScheme.secondary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.store_rounded,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Explore the Marketplace',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Buy inputs, sell produce, and connect with other farmers',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // Navigate to marketplace
              // Context.go('/marketplace');
            },
            icon: Icon(
              Icons.arrow_forward_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  bool _successDialogShown = false;

  /// ============================================================
  /// STATE: DATA — DASHBOARD
  /// ============================================================
  ///
  /// Renders farm management dashboard widgets through the
  /// Widget Registry. Prepends onboarding widgets (setup guide,
  /// checklist) at the top when applicable.
  ///
  /// Also shows the one-time success dialog after farm creation.
  /// ============================================================
  Widget _buildDashboard(BuildContext context) {
    // Show success dialog if farm was just created (one-time)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSuccessDialogIfNeeded(context);
    });

    // Resolve farm management widget descriptors from the runtime engine
    final descriptorsAsync = ref.watch(
      moduleWidgetDescriptorsProvider('farm_management'),
    );

    return descriptorsAsync.when(
      loading: () => _buildLoadingState(),
      error: (err, _) => _buildDashboardFromRegistry(context),
      data: (descriptors) {
        if (descriptors.isEmpty) {
          return _buildDashboardFromRegistry(context);
        }
        return _buildDashboardFromDescriptors(context, descriptors);
      },
    );
  }

  /// Show the one-time success dialog if the farm was just created.
  void _showSuccessDialogIfNeeded(BuildContext context) {
    if (_successDialogShown) return;

    final onboardingState = ref.read(farmOnboardingProvider);
    final hierarchy = ref.read(hierarchyProvider);

    if (!onboardingState.showSuccessCard) return;
    if (hierarchy.entity == null || hierarchy.field == null) return;

    _successDialogShown = true;

    FarmCreatedSuccessDialog.show(
      context: context,
      farmName: hierarchy.entity!.farmName,
      fieldName: hierarchy.field!.fieldName,
      farmSize: hierarchy.entity!.size,
      onContinueSetup: () {
        // Keep the setup guide visible — user wants guided flow
        // The success card is dismissed, but setup guide stays
        ref.read(farmOnboardingProvider.notifier).dismissSuccessCard();
      },
      onGoToDashboard: () {
        // Dismiss both success card and setup guide
        ref.read(farmOnboardingProvider.notifier).dismissSuccessCard();
        ref.read(farmOnboardingProvider.notifier).dismissSetupGuide();
      },
    );
  }

  /// Build the onboarding widgets (setup guide + checklist)
  /// that appear at the top of the dashboard for new farms.
  Widget _buildOnboardingSection(BuildContext context) {
    final hierarchy = ref.watch(hierarchyProvider);

    // Only show onboarding when a farm is selected
    if (!hierarchy.hasEntity) return const SizedBox.shrink();

    return const Column(
      children: [
        // ── Guided Setup Card (shown when farm has no crops/livestock) ──
        FarmSetupGuideWidget(),

        // ── Onboarding Checklist ──
        FarmOnboardingChecklistWidget(),
      ],
    );
  }

  /// Build dashboard using runtime descriptors (preferred path).
  Widget _buildDashboardFromDescriptors(
    BuildContext context,
    List<DashboardWidgetDescriptor> descriptors,
  ) {
    final theme = Theme.of(context);
    final breakpoint = ref.watch(breakpointProvider);
    final isMobile = breakpoint.deviceType == 'compactXs' || breakpoint.deviceType == 'mobile';

    // Resolve widgets from registry
    final widgetEntries = <_WidgetEntry>[];
    for (final desc in descriptors) {
      final builder = WidgetRegistry.resolve(desc.widgetKey);
      if (builder != null) {
        widgetEntries.add(_WidgetEntry(
          descriptor: desc,
          widget: ModuleErrorBoundary(
            moduleKey: desc.widgetKey,
            displayName: desc.displayName,
            child: builder(),
          ),
        ));
      }
    }

    // Sort by display order
    widgetEntries.sort(
      (a, b) => a.descriptor.displayOrder.compareTo(b.descriptor.displayOrder),
    );

    if (widgetEntries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.agriculture, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Dashboard widgets are being prepared',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

        // 🐛 FIXED: No SingleChildScrollView — ShellPageContent handles scrolling.
    // Just return the Column of widgets.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Guest mode banner
        if (!ref.watch(isAuthenticatedProvider))
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ExploreBanner(),
          ),

        // ── Onboarding Section (setup guide + checklist) ──
        _buildOnboardingSection(context),

        const SizedBox(height: 4),
        // Widget flow — single Column on mobile, Wrap on tablet/desktop
        if (isMobile)
          ...widgetEntries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DashboardWidgetCard(
              descriptor: entry.descriptor,
              child: entry.widget,
            ),
          ))
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: widgetEntries.map((entry) {
              final width = breakpoint.deviceType == 'tablet'
                  ? (MediaQuery.of(context).size.width - 44) / 2
                  : (MediaQuery.of(context).size.width - 56) / 3;
              return SizedBox(
                width: width,
                child: _DashboardWidgetCard(
                  descriptor: entry.descriptor,
                  child: entry.widget,
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Fallback: Build dashboard directly from WidgetRegistry
  Widget _buildDashboardFromRegistry(BuildContext context) {
    final farmWidgetKeys = <String>[
      'farm_lifecycle_stage',
      'farm_farm_selector',
      'farm_recommendations',
      'farm_kpis',
      'farm_summary',
      'farm_activity_timeline',
      'farm_production_summary',
      'farm_alerts',
      'farm_stock_summary',
      'farm_livestock',
      'farm_weather',
      'farm_quick_actions',
    ];

    final resolvedWidgets = <Widget>[];
    for (final key in farmWidgetKeys) {
      final builder = WidgetRegistry.resolve(key);
      if (builder != null) {
        resolvedWidgets.add(builder());
      }
    }

    if (resolvedWidgets.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.agriculture,
        title: 'Farm Dashboard',
        subtitle: 'Farm management widgets are not available. '
            'Please check your connection and try again.',
      );
    }

    final breakpoint = ref.watch(breakpointProvider);
    final isMobile = breakpoint.deviceType == 'compactXs' || breakpoint.deviceType == 'mobile';

    // 🐛 FIXED: No SingleChildScrollView — ShellPageContent handles scrolling.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Guest mode banner
        if (!ref.watch(isAuthenticatedProvider))
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ExploreBanner(),
          ),

        // ── Onboarding Section (setup guide + checklist) ──
        _buildOnboardingSection(context),

        const SizedBox(height: 4),
        if (isMobile)
          ...resolvedWidgets.map((w) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DashboardWidgetCardFallback(child: w),
          ))
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: resolvedWidgets.map((w) {
              final width = breakpoint.deviceType == 'tablet'
                  ? (MediaQuery.of(context).size.width - 44) / 2
                  : (MediaQuery.of(context).size.width - 56) / 3;
              return SizedBox(
                width: width,
                child: _DashboardWidgetCardFallback(child: w),
              );
            }).toList(),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// ============================================================
/// DASHBOARD WIDGET CARD WRAPPER (DESCRIPTOR-BASED)
/// ============================================================
class _DashboardWidgetCard extends StatelessWidget {
  final DashboardWidgetDescriptor descriptor;
  final Widget child;

  const _DashboardWidgetCard({
    required this.descriptor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// ============================================================
/// DASHBOARD WIDGET CARD WRAPPER (FALLBACK)
/// ============================================================
class _DashboardWidgetCardFallback extends StatelessWidget {
  final Widget child;

  const _DashboardWidgetCardFallback({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// ============================================================
/// SKELETON LOADING BLOCK
/// ============================================================
class _SkeletonBlock extends StatelessWidget {
  final double width;
  final double height;

  const _SkeletonBlock({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// ============================================================
/// QUICK START STEP TILE
/// ============================================================
class _QuickStartStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _QuickStartStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// INTERNAL DATA MODEL
/// ============================================================
class _WidgetEntry {
  final DashboardWidgetDescriptor descriptor;
  final Widget widget;

  const _WidgetEntry({
    required this.descriptor,
    required this.widget,
  });
}

/// @deprecated Use [FarmManagementPage] instead.
typedef FarmDashboardPage = FarmManagementPage;
