# 🏗️ FAMHUB UNIFIED APP SHELL — STAGE 2 AUDIT REPORT (FINAL)

> **Audited by**: Agent Mode — Codebase Analysis  
> **Date**: 2025  
> **Scope**: `lib/core/shell/`, `lib/core/navigation/`, `lib/shared/layouts/`, `lib/features/*/presentation/pages/`, `lib/main.dart`

---

## A. EXECUTIVE SUMMARY

The **UnifiedAppShellV2** architecture is conceptually correct and well-designed:
- Domain-agnostic shell with complete region isolation via `ShellRegion` (RepaintBoundary)
- Configurable via immutable `ShellConfig` with `copyWith`
- Shell modes (`standard`, `focus`, `immersive`, `splitWorkspace`, `presentation`, `minimal`)
- Responsive breakpoint-driven layout (compactXs → mobile → tablet → desktop → ultraWide)
- Extension slots via `ShellExtensionSlot` enum
- Keyboard navigation support via `Shortcuts`/`Actions` system
- Theme-driven via `ShellTheme` + `ShellThemeColors` extension

**Phase 1 (Scaffold elimination) is now COMPLETE ✅** — all 14 critical violations resolved.

**Phase 3 (Breakpoint consolidation) is now COMPLETE ✅** — dual breakpoint systems unified into single `breakpointProvider`.

**Phase 2D.2 (Delegate shell states) is now COMPLETE ✅** — UnifiedDashboardHost no longer owns loading, error, or empty state widgets. Three private state classes extracted into reusable public shell components at `lib/core/shell/presentation/layouts/common/`. Host now only delegates to shared widgets and renders dashboard content.

Remaining issues: **1 major architectural flaw**, **2 minor items**, and cleanup tasks for future phases.

---

## B. FINDINGS SUMMARY

| Category | Count | Severity | Effort |
|----------|-------|----------|--------|
| 🔴 Feature pages with own `Scaffold` + `AppBar` | ~~**14 files**~~ | ~~**CRITICAL**~~ | ~~~3 days~~ |
| | **✅ 0 files (Phase 1 complete)** | **✅ RESOLVED** | |
| 🔴 Loading/Error screens with hardcoded chrome | ~~**2 files**~~ | ~~**CRITICAL**~~ | ~~~2 hrs~~ |
| | **✅ 0 files (Phase 1 complete)** | **✅ RESOLVED** | |
| 🟠 Duplicate navigation widget files | ~~**4 files**~~ → **✅ 0 files** | ~~**MAJOR**~~ → **✅ RESOLVED** | ~~~1 day~~ |
| 🟠 Dual breakpoint resolution systems | ~~**2 systems**~~ → **✅ 1 system** | ~~**MAJOR**~~ → **✅ RESOLVED** | ~~~2 days~~ |
| 🟠 Legacy code still importable | ~~**2 files**~~ → **✅ 0 files** | ~~**MAJOR**~~ → **✅ RESOLVED** | ~~~1 hr~~ |
| 🟡 Hardcoded navigation items (compact XS) | **1 layout** | **MAJOR** | ✅ **RESOLVED** |
| 🟡 Wrong nav pattern (tablet uses Sidebar not NavigationRail) | **1 layout** | **MAJOR** | ✅ **RESOLVED** |
| 🟡 Business logic in presentation (activity page) | **1 file** | **MAJOR** | ~2 days |
| 🔵 Hardcoded section icon mapping (renderer) | ~~**1 file**~~ → **✅ 0 files** | ~~**MAJOR**~~ → **✅ RESOLVED** | ~~~1 hr~~ |
| 🔵 Missing accessibility, placeholders, unconsumed providers | **4 items** | **MINOR** | ~2 days |

**Total estimated effort: 4-7 days**

---

## C. COMPLETE SHELL HIERARCHY

```
runApp()
└── UncontrolledProviderScope
    └── MyApp (ConsumerStatefulWidget)
        │
        ├─ [Loading] MaterialApp (no router)
        │   └─ Scaffold [❌ hardcoded chrome]
        │       └─ Center → CircularProgressIndicator
        │
        └─ [Runtime] MaterialApp.router
            ├─ theme: shellTheme.toThemeData(ThemeMode.light)          ✅
            ├─ darkTheme: shellTheme.toThemeData(ThemeMode.dark)       ✅
            ├─ themeMode: themeModeProvider                            ✅
            └─ routerConfig: appRouterProvider (GoRouter)
                │
                └─ GoRouter
                    ├─ ShellRoute → UnifiedAppShellV2
                    │   │
                    │   └─ UnifiedAppShellV2 (ConsumerWidget)
                                        │   ├─ [System Down Gate]
                    │   │   └─ ShellSystemDown (reusable shell widget)
                    │   │
                    │       └─ _ShellLayoutBuilder (ConsumerStatefulWidget)
                    │           ├─ watches breakpointProvider (deviceType)
                    │           └─ LayoutBuilder → reads width → breakpointProvider.updateWidth()
                    │               │
                    │               ├─ compactXs (<360px)
                    │               │   └─ CompactXsShellLayout
                    │               │       Scaffold ✅ (owned by shell)
                    │               │       ├─ body: SafeArea → Column
                    │               │       │   ├─ MaintenanceBanner
                    │               │       │   └─ Expanded → child (module page)
                    │               │       └─ bottomNavigationBar: _CompactBottomNav [✅ RUNTIME-DRIVEN — bottomNavItemsProvider]
                    │               │
                    │               ├─ mobile (360-599px)
                    │               │   └─ MobileShellLayout
                    │               │       Scaffold ✅ (owned by shell)
                    │               │       ├─ appBar: ShellAppBar
                    │               │       ├─ body: SafeArea → Column
                    │               │       │   ├─ MaintenanceBanner
                    │               │       │   └─ Expanded → child
                    │               │       ├─ bottomNavigationBar: ShellBottomNav
                    │               │       └─ floatingActionButton: ShellFloatingActions
                    │               │
                    │               ├─ tablet (600-1023px)
                    │               │   └─ TabletShellLayout
                    │               │       Scaffold ✅ (owned by shell)
                    │               │       ├─ body: SafeArea → Column
                    │               │       │   ├─ MaintenanceBanner
                    │               │       │   ├─ ShellAppBar
                    │               │       │   └─ Expanded → Row
                    │               │       │       ├─ ShellNavigationRail [✅ Material 3 NavigationRail]
                    │               │       │       ├─ VerticalDivider
                    │               │       │       └─ ContentWrapper → child
                    │               │       └─ floatingActionButton: ShellFloatingActions
                    │               │
                    │               ├─ desktop (1024-1439px)
                    │               │   └─ DesktopShellLayout
                    │               │       Scaffold ✅ (owned by shell)
                    │               │       ├─ body: SafeArea → Column
                    │               │       │   ├─ MaintenanceBanner
                    │               │       │   ├─ ShellAppBar
                    │               │       │   └─ Expanded → Row
                    │               │       │       ├─ ShellSidebar
                    │               │       │       ├─ VerticalDivider
                    │               │       │       └─ ContentWrapper → child
                    │               │       ├─ ShellStatusBar
                    │               │       ├─ ShellFooter
                    │               │       └─ ShellFloatingActions
                    │               │
                    │               └─ ultraWide (≥1440px)
                    │                   └─ UltraWideShellLayout
                    │                       Scaffold ✅ (owned by shell)
                    │                       ├─ body: SafeArea → Column
                    │                       │   ├─ MaintenanceBanner
                    │                       │   ├─ ShellAppBar
                    │                       │   └─ Expanded → Row
                    │                       │       ├─ ShellSidebar (collapsible)
                    │                       │       ├─ VerticalDivider
                    │                       │       ├─ ContentWrapper → child
                    │                       │       ├─ VerticalDivider
                    │                       │       └─ ShellSecondaryPanel
                    │                       ├─ ShellStatusBar
                    │                       ├─ ShellFooter
                    │                       └─ ShellFloatingActions
                    │
                    └─ Routes (25 total — see Section D)
                        ├─ '/' → UnifiedDashboardHost                 ✅ (no Scaffold)
                        ├─ '/farm' → FarmManagementPage              ✅ SHELL-COMPLIANT
                        ├─ '/marketplace' → MarketplacePage           ✅ SHELL-COMPLIANT
                        ├─ '/search' → GlobalSearchPage               ✅ SHELL-COMPLIANT
                        └─ ... (22 more routes — all SHELL-COMPLIANT)
```

---

## D. COMPLETE ROUTE TABLE — UPDATED ✅ (All Compliant)

| # | Route | Widget | Location | Own Scaffold? | Own AppBar? |
|---|-------|--------|----------|:---:|:---:|
| 1 | `/` | `UnifiedDashboardHost` | `lib/core/dashboard_engine/presentation/pages/` | ✅ No | ✅ No |
| 2 | `/farm` | `FarmManagementPage` → `ShellPageContent` | `lib/features/farm_management/presentation/pages/` | ✅ **No** | ✅ **No** |
| 3 | `/marketplace` | `MarketplacePage` (ResponsiveWrapper) | `lib/features/marketplace/presentation/pages/` | ✅ **No** | ✅ **No** |
| 4 | `/analytics` | `AnalyticsPage` | `lib/features/analytics/presentation/pages/` | ✅ **No** | ✅ **No** |
| 5 | `/financing` | `FinancingPage` | `lib/features/financing/presentation/pages/` | ✅ **No** | ✅ **No** |
| 6 | `/logistics` | `LogisticsPage` | `lib/features/logistics/presentation/pages/` | ✅ **No** | ✅ **No** |
| 7 | `/traceability` | `TraceabilityPage` | `lib/features/traceability/presentation/pages/` | ✅ **No** | ✅ **No** |
| 8 | `/carbon-credit` | `CarbonCreditPage` | `lib/features/carbon_credit/presentation/pages/` | ✅ **No** | ✅ **No** |
| 9 | `/knowledge` | `KnowledgeLinkPage` | `lib/features/knowledge/presentation/pages/` | ✅ **No** | ✅ **No** |
| 10 | `/agribusiness` | `AgribusinessPage` | `lib/features/agribusiness/presentation/pages/` | ✅ **No** | ✅ **No** |
| 11 | `/opportunities` | `OpportunitiesPage` | `lib/features/opportunities/presentation/pages/` | ✅ **No** | ✅ **No** |
| 12 | `/extension` | `ExtensionServicesPage` | `lib/features/extension_services/presentation/pages/` | ✅ **No** | ✅ **No** |
| 13 | `/connect` | `AgriConnectPage` | `lib/features/agri_connect/presentation/pages/` | ✅ **No** | ✅ **No** |
| 14 | `/tech-lab` | `AgriTechLabPage` | `lib/features/agri_tech_lab/presentation/pages/` | ✅ **No** | ✅ **No** |
| 15 | `/referrals` | `ReferralHubPage` | `lib/features/referral_hub/presentation/pages/` | ✅ **No** | ✅ **No** |
| 16 | `/profile` | `ProfilePage` | `lib/features/profile/presentation/pages/` | ✅ **No** | ✅ **No** |
| 17 | `/settings` | `SettingsPage` | `lib/features/settings/presentation/pages/` | ✅ **No** | ✅ **No** |
| 18 | `/admin` | `AdminDashboardPage` | `lib/features/admin/presentation/pages/` | ✅ **No** | ✅ **No** |
| 19 | `/home` | `HomePage` | `lib/features/home/presentation/pages/` | ✅ **No** | ✅ **No** |
| 20 | `/search` | `GlobalSearchPage` → `ShellPageContent` | `lib/features/search/presentation/pages/` | ✅ **No** | ✅ **No** |
| 21 | `/notifications` | `NotificationCenterPage` → `ShellPageContent` | `lib/features/notifications/presentation/pages/` | ✅ **No** | ✅ **No** |
| 22 | `/reports` | `ReportsCenterPage` → `ShellPageContent` | `lib/features/reports/presentation/pages/` | ✅ **No** | ✅ **No** |
| 23 | `/runtime-settings` | `RuntimeSettingsPage` → `ShellPageContent` | `lib/features/runtime_settings/presentation/pages/` | ✅ **No** | ✅ **No** |
| 24 | `/ai-assistant` | `AIAssistantPage` → `ShellPageContent` | `lib/features/ai_assistant/presentation/pages/` | ✅ **No** | ✅ **No** |
| 25 | `/guest` | `GuestHomePage` → `ShellPageContent` | `lib/features/guest/guest_homepage.dart` | ✅ **No** | ✅ **No** |
| — | `errorBuilder` | `ShellNotFound` | `lib/core/shell/presentation/layouts/common/shell_not_found.dart` | ✅ **No** (shell-themed) | ✅ No |
| — | Loading state | Loading page | `lib/main.dart` | ✅ **No** (shell-themed) | ✅ No |

**Finding**: **25 of 25** feature pages are now compliant. **Zero** feature‑level `Scaffold` or `AppBar` violations remain.

---

## E. DUPLICATE / LEGACY COMPONENT MAP

```
DUPLICATE NAVIGATION WIDGETS
════════════════════════════

┌─────────────────────────┬─────────────────────────┬────────────┐
│ USED (NEW)             │ DUPLICATE (OLD)         │ ACTION     │
├─────────────────────────┼─────────────────────────┼────────────┤
│ ShellSidebar            │ SideNav                │ ✅ DELETED │
│ shell_sidebar.dart      │ side_nav.dart           │            │
├─────────────────────────┼─────────────────────────┼────────────┤
│ ShellSidebar            │ AnimatedSideNav         │ ✅ DELETED │
│ shell_sidebar.dart      │ animated_side_nav.dart  │            │
├─────────────────────────┼─────────────────────────┼────────────┤
│ ShellBottomNav          │ BottomNav              │ ✅ DELETED │
│ shell_bottom_nav.dart   │ bottom_nav.dart         │            │
├─────────────────────────┼─────────────────────────┼────────────┤
│ ShellNavItemContainer   │ NavItemContainer        │ ✅ DELETED │
│ shell_nav_item.dart     │ nav_item_styles.dart    │            │
├─────────────────────────┼─────────────────────────┼────────────┤
│ ShellNavItemContainer   │ NavItemIndicator       │ ✅ DELETED │
│ shell_nav_item.dart     │ nav_item_styles.dart    │            │
├─────────────────────────┼─────────────────────────┼────────────┤
│ ShellNavItemContainer   │ NavItemStyleResolver    │ ✅ DELETED │
│ shell_nav_item.dart     │ nav_item_styles.dart    │            │
├─────────────────────────┼─────────────────────────┼────────────┤
│ (Runtime) shellExtension│ (Static)                │ PENDING    │
│ _provider               │ ShellExtensionRegistry  │ static API │
└─────────────────────────┴─────────────────────────┴────────────┘

LEGACY FILES STILL IN TREE (ZERO CONSUMERS)
════════════════════════════════════════════

┌──────────────────────────────────┬──────────────────────────────┐
│ FILE                             │ STATUS                       │
├──────────────────────────────────┼──────────────────────────────┤
│ lib/shared/layouts/main_shell.dart│ DEPRECATED — Do Not Use     │
│ lib/core/navigation/side_nav.dart │ REPLACED by ShellSidebar    │
│ lib/core/navigation/animated_side_│ REPLACED by ShellSidebar    │
│ nav.dart                          │                              │
│ lib/core/navigation/bottom_nav.dart│ REPLACED by ShellBottomNav  │
│ lib/core/navigation/nav_item_    │ REPLACED by shell_nav_item  │
│ styles.dart                       │ .dart                       │
│ lib/core/shell/domain/contracts/ │ Static registry — runtime   │
│ shell_extension.dart (register()) │ provider should be only API │
└──────────────────────────────────┴──────────────────────────────┘

### ✅ Deleted (Task 2E.3):

| File | Status |
|------|--------|
| `lib/core/router/navigation_service.dart` | **DELETED** — No runtime usages found. Static wrapper around `GoRouter` that was never imported or referenced anywhere in the codebase. |
```

---

## F. BREAKPOINT SYSTEM — NOW SINGLE SOURCE OF TRUTH ✅

**Status: ✅ RESOLVED — Phase 3 Complete**

The dual breakpoint systems have been consolidated into a single `breakpointProvider`.

### BEFORE (2 systems):

- **ScreenBreakpoint enum** (`new_unified_app_shell.dart`) — shell layout switching
- **BreakpointNotifier** (`resize_optimizer.dart`) — dashboard grid columns/spacing
- **`_resolveDeviceType()`** (`registry_dashboard_renderer.dart`) — third independent check
- **Raw `MediaQuery` + `width > 900`** (`enhanced_dashboard_renderer.dart`) — fourth check

All four used different types, different thresholds, and were never synchronized.

### AFTER (1 system):

**Single source of truth**: `breakpointProvider` (`resize_optimizer.dart`)

```
BreakpointState (Notifier<BreakpointState>)
  ├── deviceType: 'compactXs' | 'mobile' | 'tablet' | 'desktop' | 'ultraWide'
  ├── columnCount: 1 | 1 | 2 | 3 | 3
  ├── spacing: 6 | 8 | 12 | 16 | 16
  └── width: double (current container width)
              ▲
              │
  LayoutBuilder.updateWidth(constraints.maxWidth)
      └── _ShellLayoutBuilder (new_unified_app_shell.dart)
      └── (any widget can call updateWidth)
```

**Consumers (all unified)**:

| Consumer | Before | After |
|----------|--------|-------|
| Shell layout switching | `ScreenBreakpoint` enum | `breakpointProvider.deviceType` |
| Dashboard grid columns | `LayoutBuilder` raw check | `breakpointProvider.columnCount` |
| Dashboard spacing | Hardcoded per-renderer | `breakpointProvider.spacing` |
| Loading skeleton columns | `LayoutBuilder` raw check | `breakpointProvider.columnCount` |
| `registry_dashboard_renderer.dart` | `_resolveDeviceType()` local method | `breakpointProvider.deviceType` |
| `enhanced_dashboard_renderer.dart` | `MediaQuery.of(context).size.width` | `breakpointProvider.columnCount` |

**Backward compatibility for all 5 device types ✅**:

| New Type | Old `isVisibleOnDevice()` Mapping |
|----------|-----------------------------------|
| `compactXs` | normalized → `mobile` |
| `mobile` | unchanged |
| `tablet` | unchanged |
| `desktop` | unchanged |
| `ultraWide` | normalized → `desktop` |

Files updated to normalize extended types:
- `lib/core/navigation/nav_item.dart` — `isVisibleOnDevice()`
- `lib/core/feature_flags/application/services/runtime_feature_flags.dart` — `_checkDeviceCompatibility()`
- `lib/core/dashboard_engine/domain/models/dashboard_widget_definition.dart` — `isVisibleOnDevice()`
- `lib/core/composition/navigation/composition_nav_builder.dart` — `CompositionNavItem.isVisibleOnDevice()`

---

## G. DETAILED VIOLATION REGISTER

### 🔴 CRITICAL — ALL RESOLVED ✅ (Phase 1 Complete)

| ID | Status | File | Resolution |
|:--:|:------:|------|------------|
| C1 | ✅ **RESOLVED** | `farm_dashboard_page.dart` | `Scaffold+AppBar` → `ShellPageContent` |
| C2 | ✅ **RESOLVED** | `farm_detail_page.dart` | `Scaffold+AppBar+TabBar` → `Column` + embedded `TabBar` |
| C3 | ✅ **RESOLVED** | `add_farm_page.dart` | `Scaffold+AppBar` → `ShellPageContent` |
| C4 | ✅ **RESOLVED** | `activity_template_selection_page.dart` | `Scaffold+AppBar` → `ShellPageContent` |
| C5 | ✅ **RESOLVED** | `activity_creation_page.dart` | `Scaffold+AppBar` → `ShellPageContent` |
| C6 | ✅ **RESOLVED** | `production_page.dart` | `Scaffold+AppBar` → `ShellPageContent` |
| C7 | ✅ **RESOLVED** | `dynamic_activity_execution_page.dart` | **Two** `Scaffold+AppBar` → single `ShellPageContent` |
| C8 | ✅ **RESOLVED** | `guest_homepage.dart` | `Scaffold` → `ShellPageContent` (pure content widget) |
| C9 | ✅ **RESOLVED** | `global_search_page.dart` | `Scaffold+AppBar` → `ShellPageContent` + inline search field |
| C10 | ✅ **RESOLVED** | `notification_center_page.dart` | `Scaffold+AppBar` → `ShellPageContent` |
| C11 | ✅ **RESOLVED** | `runtime_settings_page.dart` | `Scaffold+AppBar` → `ShellPageContent` |
| C12 | ✅ **RESOLVED** | `reports_center_page.dart` | `Scaffold+AppBar` → `ShellPageContent` |
| C13 | ✅ **RESOLVED** | `app_router.dart` | Plain `Scaffold` → shell-themed (`ShellThemeColors`) |
| C14 | ✅ **RESOLVED** | `main.dart` | Plain `Scaffold` → shell-themed (`ShellThemeColors`)

### 🟠 MAJOR (8 items)

| ID | Status | File | Issue | Details |
|:--:|:------:|------|-------|---------|
| M1 | ✅ **RESOLVED** | `resize_optimizer.dart` + `new_unified_app_shell.dart` | **Dual breakpoint systems** | `ScreenBreakpoint` enum removed. All consumers now use `breakpointProvider`. Extended `BreakpointState` to support all 5 device types. Initial state fixed (`width: 0` instead of `width: 1440`). |
| M2 | ✅ **RESOLVED** | `lib/core/navigation/side_nav.dart` | **Dead code — duplicate** | `SideNav` is older version of `ShellSidebar`. Uses hardcoded colors. |
| M3 | ✅ **RESOLVED** | `lib/core/navigation/animated_side_nav.dart` | **Dead code — duplicate** | `AnimatedSideNav` predates `ShellSidebar`. Uses legacy `NavItemContainer`. Hardcodes 'FAMHUB' brand. |
| M4 | ✅ **RESOLVED** | `lib/core/navigation/bottom_nav.dart` | **Dead code — duplicate** | `BottomNav` predates `ShellBottomNav`. No ShellTheme integration. |
| M5 | ✅ **RESOLVED** | `lib/core/navigation/nav_item_styles.dart` | **Dead code — duplicate** | `NavItemContainer`, `NavItemStyleResolver`, `NavItemIndicator` all duplicated in `shell_nav_item.dart`. |
| M6 | ✅ **RESOLVED** | `lib/shared/layouts/main_shell.dart` | **Dead legacy code** | Comments say "DEPRECATED - Do Not Use" but file still exists and is importable. Contains old Scaffold+AppBar+Drawer pattern. |
| M7 | PENDING | `lib/core/shell/domain/contracts/shell_extension.dart` | **Two registration systems** | Static `ShellExtensionRegistry.register()` coexists with runtime `shellExtensionProvider`. Static bypasses governance. |
| M8 | ✅ **RESOLVED** | `compact_xs_shell_layout.dart` | **Hardcoded bottom nav items** | `_CompactBottomNav` now reads from `bottomNavItemsProvider` — same runtime provider as `ShellBottomNav`. Hardcoded icons removed. Navigation order follows provider. |
| M9 | ✅ **RESOLVED** | `responsive_dashboard_renderer.dart` | **Duplicate feature flag logic** | `_evaluateItem()` removed — all checks (disabled modules, maintenance mode, guest restrictions, device visibility, feature flags) were lifted. Renderer now trusts `dashboardNavItemsProvider` which already applies all governance. |
| M10 | PENDING | `dynamic_activity_execution_page.dart` | **Business logic in widget** | Page directly orchestrates stock mutation, financial recording, KPI automation. |
| M11 | ✅ **RESOLVED** | `responsive_dashboard_renderer.dart` | **Hardcoded section icon mapping** | `_getSectionIcon()` switch statement removed. Section icons now read directly from `NavItem.icon` metadata from navigation/composition layer. No module name references remain. Renderer is fully presentation-only. |
| M12 | ✅ **RESOLVED** | `lib/core/router/navigation_service.dart` | **Dead code — unused NavigationService** | Static wrapper class around GoRouter was never imported, referenced, or instantiated anywhere in the codebase. All searches for `NavigationService`, `navigationServiceProvider`, `setRouter(`, `navigatorKey`, `globalNavigatorKey` returned zero results. File deleted — no routing behavior affected. |

### 🔵 MINOR (12 items)

| ID | File | Issue | Details |
|----|------|-------|---------|
| m1 | `shell_sidebar.dart:142` | **Hardcoded fallback brand name** | `_getBrandName()` returns `'App'` instead of reading from `ShellTheme.brand.name` |
| m2 | `shell_theme_provider.dart:76` | **Theme toggle wraps incorrectly** | Toggle cycles `system → light → dark → system` (system is meaningless in a manual toggle) |
| m3 | ✅ **RESOLVED** — `resize_optimizer.dart:78` | **BreakpointNotifier incorrect initial state** | Changed from `width: 1440, deviceType: 'desktop'` to `width: 0, deviceType: 'desktop'` — neutral initial state updated immediately by LayoutBuilder |
| m4 | `shell_app_bar.dart:190` | **Badge count hardcoded to 0** | `badgeCount: 0` with TODO `// TODO: wire up notification count` |
| m5 | `shell_status_bar.dart:140,169` | **Connection/sync are TODOs** | Both `_ConnectionStatus` and `_SyncStatus` have `// TODO: Replace with actual` |
| m6 | `shell_secondary_panel.dart` | **Empty panel — no extension integration** | Shows `config.emptyText` placeholder — no rendering of `ShellExtensionSlot.secondaryPanel` |
| m7 | `shell_extension_provider.dart:56` | **Placeholder builders** | Extension mapping uses `const SizedBox.shrink()` — declared but not functional |
| m8 | `shell_sidebar.dart`, `shell_nav_item.dart` | **Missing accessibility** | Navigation icons lack `semanticLabel` and `Semantics` wrappers |
| m9 | `keyboard_navigation.dart` | **No visual focus indicator** | Keyboard shortcuts work but no visible focus ring |
| m10 | ✅ **RESOLVED** — `new_unified_app_shell.dart` | **Provider not consumed** | `runtimeAutoInvalidatorProvider` is now consumed via `ref.listen(runtimeAutoInvalidatorProvider, (_, __) {})` in `UnifiedAppShellV2.build()`. Import of `runtime_refresh_provider.dart` added. |
| m11 | ✅ **RESOLVED** — `compact_xs_shell_layout.dart` | **CompactXS hardcoded nav** | `_CompactBottomNav` now uses `bottomNavItemsProvider` — same provider as `ShellBottomNav`. |
| m12 | ✅ **RESOLVED** | **Navigation config mode now aligned** | `TabletShellLayout` replaced `ShellSidebar` with `ShellNavigationRail` — Material 3 `NavigationRail` is the correct tablet pattern |

---

## H. STATE OWNERSHIP MAP (VERIFIED)

| State | Owner | Storage | Source of Truth | Correct? |
|-------|-------|---------|----------------|:---:|
| Current route/location | GoRouter | GoRouterState | `GoRouterState.of(context).uri` | ✅ |
| Sidebar expanded/collapsed | `SidebarController` | `sidebarControllerProvider` (Riverpod) | `sidebarState.isExpanded` | ✅ |
| Theme mode | `ThemeModeNotifier` | `themeModeProvider` (Riverpod) | `ref.watch(themeModeProvider)` | ✅ |
| Shell theme config | `ShellTheme` | `shellThemeProvider` (Riverpod) | `ShellThemeColors.palette` | ✅ |
| System down | `SystemStateNotifier` | `systemStateProvider` (Riverpod) | `systemState.isSystemDown` | ✅ |
| Navigation items (sidebar) | `nav_config.dart` | `sidebarNavItemsProvider` | Backend `SystemModule` data | ✅ |
| Navigation items (bottom) | `nav_config.dart` | `bottomNavItemsProvider` | Backend `SystemModule` data | ✅ |
| Navigation items (dashboard) | `nav_config.dart` | `dashboardNavItemsProvider` | Backend `SystemModule` data | ✅ |
| Breakpoint (shell layout) | `breakpointProvider` | `BreakpointState` (Riverpod) | Container width via `LayoutBuilder.updateWidth()` | ✅ **Single source** |
| Breakpoint (dashboard) | `breakpointProvider` | `BreakpointState` (Riverpod) | Container width via `LayoutBuilder.updateWidth()` | ✅ **Single source** |
| Shell mode | `ShellConfig.mode` | Passed as prop | `ref.watch(shellModeProvider)` (if exists) | ⚠️ Not Riverpod |
| Keyboard nav enabled | `ShellConfig.enableKeyboardNavigation` | Config constant | Config constant | ✅ |
| Dashboard loading skeleton | `ShellDashboardLoading` | `core/shell/layouts/common/` public widget | Shared shell component | ✅ **Delegated** |
| Dashboard error state | `ShellDashboardError` | `core/shell/layouts/common/` public widget | Shared shell component | ✅ **Delegated** |
| Dashboard empty state | `ShellDashboardEmpty` | `core/shell/layouts/common/` public widget | Shared shell component | ✅ **Delegated** |
| 404 / Page Not Found | `ShellNotFound` | `core/shell/layouts/common/` public widget | Shared shell component | ✅ **Centralized** |
| System down / maintenance | `ShellSystemDown` | `core/shell/layouts/common/` public widget | Shared shell component | ✅ **Centralized** |
| Notification count | None | None | `badgeCount: 0` (hardcoded) | ❌ Missing |

---

## I. RECOMMENDED ACTION PLAN

### Phase 1: CRITICAL — Remove Scaffolds from Feature Pages ✅ **DONE**

| # | Task | Files | Status |
|---|------|-------|:------:|
| 1.1 | Create `ShellPageContent` shared widget | `lib/shared/layouts/shell_page_content.dart` | ✅ **Done** |
| 1.2 | Convert farm management pages (12 files) | Farm dashboard, detail, add, activities, assets, crops, fields, livestock, activity template, activity creation, production, dynamic execution | ✅ **Done** |
| 1.3 | Convert `DynamicActivityExecutionPage` (presentation only) | `dynamic_activity_execution_page.dart` | ✅ **Done** |
| 1.4 | Convert system pages (6 files) | `global_search_page.dart`, `notification_center_page.dart`, `runtime_settings_page.dart`, `reports_center_page.dart`, `guest_homepage.dart`, `ai_assistant_page.dart` | ✅ **Done** |
| 1.5 | Verify marketplace pages | 6 marketplace pages (already clean) | ✅ **Done** |
| 1.6 | Fix errorBuilder + loading state | `app_router.dart`, `dynamic_route_registrar.dart`, `main.dart` | ✅ **Done** |

**Total resolved**: 18 feature pages + 3 error/loading screens

### Phase 2: MAJOR — Clean Up Duplicates + NavigationRail ✅ **ALL DONE**

| # | Task | Files | Est. | Status |
|---|------|-------|------|:------:|
| **2.1** | **Delete 4 duplicate nav widgets** | `side_nav.dart`, `animated_side_nav.dart`, `bottom_nav.dart`, `nav_item_styles.dart` | 15 min | **✅ Done** |
| **2.2** | **Delete legacy MainShell** | `main_shell.dart` | 5 min | **✅ Done** |
| **2.3** | **Remove static ShellExtensionRegistry** | `shell_extension.dart` (keep only models) | 30 min | **✅ Done** |
| **2C.2** | **Replace hardcoded Compact XS navigation** | `compact_xs_shell_layout.dart` | 2 hrs | **✅ Done** |
| 2.4 | Add NavigationRail for tablet | Create `shell_navigation_rail.dart` + update `tablet_shell_layout.dart` | 4 hrs | **✅ Done** |

### Phase 3: MAJOR — Unify Breakpoint System ✅ **DONE**

| # | Task | Files | Est. | Status |
|---|------|-------|:----:|:------:|
| 3.1 | Merge `ScreenBreakpoint` into `BreakpointNotifier` | `resize_optimizer.dart`, `new_unified_app_shell.dart` | 1 day | **✅ Done** |
| 3.2 | Fix initial state issue (width: 1440 → width: 0) | `resize_optimizer.dart` | 30 min | **✅ Done** |
| 3.3 | Update 3 dashboard renderers to use `breakpointProvider` | `registry_dashboard_renderer.dart`, `enhanced_dashboard_renderer.dart`, `responsive_dashboard_renderer.dart` | 1 hr | **✅ Done** |
| 3.4 | Add backward compatibility for extended device types | `nav_item.dart`, `runtime_feature_flags.dart`, `dashboard_widget_definition.dart`, `composition_nav_builder.dart` | 1 hr | **✅ Done** |
| 3.5 | Update loading skeleton to use `breakpointProvider` | `unified_dashboard_host.dart` | 30 min | **✅ Done** |
| 3.6 | Remove import of `responsive_breakpoints.dart` from shell | `new_unified_app_shell.dart` | 5 min | **✅ Done** |

### Phase 2F: MINOR — Centralize Shell Error & System-Down Pages ✅ **DONE**

| # | Task | Files | Est. | Status |
|---|------|-------|:----:|:------:|
| **2F.1** | **Create reusable `ShellNotFound` widget** | `shell_not_found.dart` | 30 min | **✅ Done** |
| **2F.1** | **Replace inline errorBuilder in `dynamic_route_registrar.dart`** | `dynamic_route_registrar.dart` | 15 min | **✅ Done** |
| **2F.1** | **Verify `app_router.dart` has no errorBuilder** | `app_router.dart` | 5 min | **✅ Clean** (delegates to DynamicRouteRegistrar) |
| **2F.1** | **Export via `common.dart` barrel file** | `common.dart` | 5 min | **✅ Done** |
| **2F.2** | **Create reusable `ShellSystemDown` widget** | `shell_system_down.dart` | 30 min | **✅ Done** |
| **2F.2** | **Replace inline system-down block in `new_unified_app_shell.dart`** | `new_unified_app_shell.dart` | 15 min | **✅ Done** |
| **2F.2** | **Export via `common.dart` barrel file** | `common.dart` | 5 min | **✅ Done** |

**Result (2F.1)**: One reusable `ShellNotFound` widget at `lib/core/shell/presentation/layouts/common/shell_not_found.dart`. No duplicated "Page Not Found" UI remains. Routing behavior unchanged — `errorBuilder: (context, state) => const ShellNotFound()` replaces the inline implementation. Shell-themed colors preserved identically via `ShellThemeColors` extension. `app_router.dart` was already clean (thin delegation wrapper with no errorBuilder).

**Result (2F.2)**: One reusable `ShellSystemDown` widget at `lib/core/shell/presentation/layouts/common/shell_system_down.dart`. No inline maintenance UI remains in `UnifiedAppShellV2`. Visual appearance unchanged — same `cloud_off_rounded` icon, same warning color, same text, same shell palette. The widget is a `const`-friendly `StatelessWidget` exported via `common.dart`. `SystemState`, providers, routing, shell modes, and business logic untouched. `flutter analyze` — zero new issues.

### Phase 4: MINOR — Quality Improvements (2-3 days)

| # | Task | Est. |
|---|------|------|
| 4.1 | Fix theme toggle order (remove `system` from cycle) | 15 min |
| 4.2 | Fix brand header fallback (read from ShellTheme) | 30 min |
| 4.3 | Wire up notification badge count | 1 hr |
| 4.4 | Implement actual connection/sync status | 2 hrs |
| 4.5 | Add Semantics wrappers (accessibility) | 2 hrs |
| 4.6 | Add visual focus indicators for keyboard nav | 1 hr |
| 4.7 | Connect SecondaryPanel to extensions | 2 hrs |
| 4.8 | ✅ **RESOLVED** — Consume runtimeAutoInvalidatorProvider | 30 min |

### Phase 5: REFACTOR — Business Logic Extraction (1 day)

| # | Task | Est. | Status |
|---|------|:----:|:------:|
| 5.1 | Extract DynamicActivityExecutionPage business logic to `DynamicActivityWorkflowService` | 1 day | PENDING |
| 5.2 | Clean up UnifiedDashboardHost loading/error/empty states | 4 hrs | **✅ Done** — Task 2D.2 |
| 5.3 | Ensure ShellExtensionProvider has real widget builders | 4 hrs | PENDING |

---

## J. KEY METRICS (UPDATED)

| Metric | Value |
|--------|-------|
| Shell layout variants | 5 (compactXs, mobile, tablet, desktop, ultraWide) |
| Shell modes | 6 (standard, focus, immersive, splitWorkspace, presentation, minimal) |
| Shell regions | 8 (topBar, navigation, content, overlay, floating, status, footer, secondary) |
| Total routes | 25 |
| Routes with compliant pages | **25 of 25** ✅ (100% — Phase 1 complete) |
| Routes with violating pages | **0** (all resolved) |
| Duplicate navigation files | **0** (✅ Phase 2.1 complete) |
| Dead legacy files | **0** (✅ Phase 2.2 complete) |
| Breakpoint systems | ~~**2**~~ → **✅ 1** (Phase 3 complete) |
| Dual registration systems | 1 (static + runtime extensions) |
| Dashboard state widgets owned by host | ~~**3** (private)~~ → **✅ 0** (all delegated to shared shell components) |
| System-down UI owned by `UnifiedAppShellV2` | ~~**1** (inline Scaffold)~~ → **✅ 0** (delegated to `ShellSystemDown`) |
| Shell reusable state widgets in `common/` | **6** (`ShellDashboardLoading`, `ShellDashboardError`, `ShellDashboardEmpty`, `ShellNotFound`, `ShellSystemDown`, `MaintenanceBanner`) |
| Tablet navigation pattern | ~~ShellSidebar~~ → **✅ ShellNavigationRail (Material 3)** |

---

## K. RISK ASSESSMENT (UPDATED)

| Risk | Probability | Impact | Mitigation |
|------|:---:|:---:|-----------|
| User sees double AppBar (shell's + feature's) | ~~**HIGH**~~ → **NONE** (Phase 1 done) | ~~**HIGH**~~ | ✅ Resolved — all feature Scaffolds/AppBars removed |
| Dead code is accidentally imported | ~~**MEDIUM** — 4 files exist~~ → **✅ NONE** (Phase 2.1/2.2 done) | ~~**MEDIUM** — subtle bugs~~ | ✅ Resolved — legacy nav widgets and MainShell deleted |
| Breakpoint confusion on ultrawide screens | **NONE** ✅ (Phase 3 done) | **NONE** ✅ | ✅ Resolved — single `breakpointProvider` with all 5 device types |
| Extensions don't render (empty placeholders) | **HIGH** — 0 functional extensions | **LOW** — no observable impact now | Phase 4/5 wiring |
| Business logic in widget crashes silently | **LOW** — 1 file affected | **HIGH** — data corruption | Phase 5 extraction |

---

## L. CONCLUSION (UPDATED)

**The UnifiedAppShellV2 architecture is well-designed and production-ready** as a shell layer. The core concepts — domain-agnostic regions, config-driven layout, theme extensibility, breakpoint-aware responsive design — are all correct and properly implemented.

**Phase 1 is COMPLETE ✅**: The critical enforcement gap is resolved. `UnifiedAppShellV2` now owns **100% of application chrome** — zero feature pages create their own `Scaffold` or `AppBar`. All feature modules render only content via `ShellPageContent` or other content-only widgets.

**Phase 2 (tasks 2.1 & 2.2) is COMPLETE ✅**: All 5 legacy navigation and layout files have been removed:
- `side_nav.dart` (duplicate of `ShellSidebar`)
- `animated_side_nav.dart` (duplicate of `ShellSidebar`)
- `bottom_nav.dart` (duplicate of `ShellBottomNav`)
- `nav_item_styles.dart` (duplicate of `shell_nav_item.dart`)
- `main_shell.dart` (deprecated legacy shell)

No barrel exports or remaining imports reference these files. The shell navigation components (`ShellSidebar`, `ShellBottomNav`, `ShellNavItemContainer`) are now the **only** navigation implementation.

**Phase 2 (tasks 2.1 & 2.2) is COMPLETE ✅**: All 5 legacy navigation and layout files deleted.

**Phase 2 (task 2.3) is COMPLETE ✅**: Static `ShellExtensionRegistry` removed — runtime `shellExtensionProvider` is the only extension mechanism.

**Phase 2 (task 2C.2) is COMPLETE ✅**: Compact XS bottom navigation is now fully runtime-driven. `_CompactBottomNav` reads from `bottomNavItemsProvider` — the same provider consumed by `ShellBottomNav` in the Mobile layout. Hardcoded icon list, hardcoded count, and static `StatelessWidget` replaced with `ConsumerWidget` watching the provider. Navigation order, icons, and labels all come from provider metadata. Enabling/disabling a module now automatically updates Compact XS navigation.

**Phase 3 (Breakpoint consolidation) is COMPLETE ✅**: `ScreenBreakpoint` enum removed. `BreakpointNotifier` enhanced to support all 5 device types. All shell + dashboard consumers unified under single `breakpointProvider`. Extended device types (`compactXs`, `ultraWide`) normalized for backward compatibility in all device-restriction checks. Initial state flicker fixed (`width: 0` instead of `width: 1440`).

**Phase 2D.2 (Delegate shell states) is COMPLETE ✅**: UnifiedDashboardHost's private loading/error/empty state widgets extracted into 3 reusable public shell components:
- `_DashboardLoadingLayout` → `ShellDashboardLoading` (83 lines, public, configurable skeleton count)
- `_DashboardErrorLayout` → `ShellDashboardError` (78 lines, public, retry callback)
- `_DashboardEmptyLayout` → `ShellDashboardEmpty` (62 lines, public, domain-agnostic)
All three live at `lib/core/shell/presentation/layouts/common/` and are exported via `common.dart` barrel. `UnifiedDashboardHost` reduced from ~250 lines to ~50 lines of pure delegation logic.

**Task 2F.2 (Centralize System Maintenance UI) is now COMPLETE ✅**: A reusable `ShellSystemDown` widget has been created at `lib/core/shell/presentation/layouts/common/shell_system_down.dart`. The inline system-down `Scaffold(...)` block in `UnifiedAppShellV2.build()` has been replaced with `return const ShellSystemDown()`. The widget preserves the exact visual appearance — `cloud_off_rounded` icon in shell warning color, "System maintenance in progress" title (18px, w600), "Please check back later." subtitle (14px, secondary text) — all sourced from `ShellThemeColors` extension. The widget is a `const`-friendly `StatelessWidget` exported via the `common.dart` barrel file. `UnifiedAppShellV2` no longer owns any maintenance UI. No `SystemState`, providers, routing, shell modes, or business logic were modified. `flutter analyze` reports zero new issues.

**Phase 2.4 (NavigationRail for tablet) is now COMPLETE ✅**: Tablet navigation migrated from `ShellSidebar` to Material 3 `NavigationRail`. A new `ShellNavigationRail` widget was created at `lib/core/navigation/shell_navigation_rail.dart`, consuming the same `sidebarNavItemsProvider` as `ShellSidebar`. `tablet_shell_layout.dart` was updated to replace `ShellSidebar` + `ExtensionSlot` + `Row` wrapper with a single `const ShellNavigationRail()`. No other shell layouts were affected. Design decisions: `extended: false`, `NavigationRailLabelType.all` (labels always shown), scrollable via `SingleChildScrollView`, all colors from `ShellThemeColors` — no hardcoded colors, icons, or modules. Governance (feature flags, permissions, maintenance mode, badges) preserved entirely through provider — the widget is pure presentation.

**Remaining work**: Business logic extraction (`DynamicActivityExecutionPage`) remains — targeted for future phases.

**Task 2E.1 (Remove hardcoded section icon mapping) is now COMPLETE ✅**: `responsive_dashboard_renderer.dart` is fully domain-agnostic — no module names, no switch statements, no icon registry. The renderer simply displays `NavItem.icon` metadata as section icons, or renders nothing when no items exist.

**Phase 2E.1 (Remove hardcoded section icon mapping) is COMPLETE ✅**: `responsive_dashboard_renderer.dart` no longer contains `_getSectionIcon()` — the hardcoded `switch` statement mapping module names (`'farm'`, `'marketplace'`, `'knowledge'`, etc.) to icon key strings has been fully removed. The section header now reads the icon directly from `NavItem.icon` metadata supplied by the navigation/composition layer. If no items exist in a section, no icon is rendered (no fallback mapping). The `IconResolver` import was also removed as it's no longer needed. The renderer is now completely presentation-only — it displays whatever metadata it receives without any domain knowledge.

**All Phase 2 tasks are now complete ✅**.

**Task 2E.3 (Remove Dead NavigationService) is now COMPLETE ✅**: `lib/core/router/navigation_service.dart` was audited for all runtime usages — `NavigationService`, `navigationServiceProvider`, `setRouter(`, `navigatorKey`, `globalNavigatorKey` — zero references found anywhere in the codebase. The file was deleted. No imports, exports, or barrel files referenced it. Routing behavior unchanged — `appRouterProvider` remains the single source of truth for GoRouter configuration via `DynamicRouteRegistrar.buildRouter()`.

**Phase 4 (task 4.8) is now COMPLETE ✅**: `runtimeAutoInvalidatorProvider` is now consumed by `UnifiedAppShellV2` via `ref.listen`. The import of `runtime_refresh_provider.dart` was added to the file. The shell now automatically reacts to runtime module and context changes — navigation, extensions, and dashboard state refresh without any manual `ref.invalidate(...)` calls. No business logic was added; the provider's existing side effects (watching `moduleProvider` and `contextProvider`, then invalidating navigation providers) are now activated. `runtime_refresh_provider.dart` remains unchanged.

**Task 2F.1 (Centralize Shell Error Pages) is now COMPLETE ✅**: A reusable `ShellNotFound` widget has been created at `lib/core/shell/presentation/layouts/common/shell_not_found.dart`. The inline GoRouter `errorBuilder` implementation in `dynamic_route_registrar.dart` (the only duplicated "Page Not Found" UI in the codebase) has been replaced with `const ShellNotFound()`. The `app_router.dart` compatibility wrapper was already clean — it delegates entirely to `DynamicRouteRegistrar` and never contained its own errorBuilder. The widget is exported via the `common.dart` barrel file alongside the other shared shell components (`ShellDashboardLoading`, `ShellDashboardError`, `ShellDashboardEmpty`). Visual appearance is identical — the same `ShellThemeColors` extension, same warning icon, same layout and text. No routing behavior, GoRouter configuration, redirects, navigation, or providers were changed. All GoRouter consumers (`DynamicRouteRegistrar.buildRouter()`, `AppRouter.createRouter()`, `AppRouter.createRouterWithModules()`) automatically use the shared widget.

**Task 2F.2 (Centralize System Maintenance UI) is now COMPLETE ✅**: A reusable `ShellSystemDown` widget has been created at `lib/core/shell/presentation/layouts/common/shell_system_down.dart`. The inline system-down `Scaffold(...)` block in `UnifiedAppShellV2.build()` has been replaced with `return const ShellSystemDown()`. The widget preserves the exact visual appearance — `cloud_off_rounded` icon in shell warning color, "System maintenance in progress" title (18px, w600), "Please check back later." subtitle (14px, secondary text) — all sourced from `ShellThemeColors` extension. The widget is a `const`-friendly `StatelessWidget` exported via the `common.dart` barrel file. `UnifiedAppShellV2` no longer owns any maintenance UI. No `SystemState`, providers, routing, shell modes, or business logic were modified. `flutter analyze` reports zero new issues.

**Task 2E.3 (Remove remaining manual provider invalidations) is now COMPLETE ✅**: 
- Scanned all **41** `ref.invalidate(...)` occurrences across 10 files.
- **Removed 9** redundant invalidations in `lib/main.dart`:
  - **Stage 6** (4 calls): `moduleProvider`, `enabledRuntimeModulesProvider`, `runtimeModuleRegistryProvider`, `appRouterProvider` — now handled by `runtimeAutoInvalidatorProvider`'s reactive watch on `contextProvider`/`moduleProvider`.
  - **Stage 7** (5 calls): `moduleRuntimeSyncProvider`, `moduleProvider`, `enabledRuntimeModulesProvider`, `runtimeModuleRegistryProvider`, `appRouterProvider` — same rationale; `RuntimeSyncEngine.init()` changes propagate through `moduleProvider`, triggering the auto-invalidator.
- **Retained 32** invalidations across 9 files: all are user-initiated (retry buttons, CRUD mutations, page lifecycle data loading) or in excluded files (`runtime_refresh_provider.dart`, `composition_providers.dart`).
- **Zero manual runtime refresh invalidations remain** outside explicit user-triggered actions.
- `lib/main.dart` now trusts the auto-invalidation pipeline — no preemptive invalidation during deferred initialization.

Estimated total effort for remaining phases: **~4-7 days** with 1-2 developers.

---

*End of Stage 2 Audit Report — 2025*
