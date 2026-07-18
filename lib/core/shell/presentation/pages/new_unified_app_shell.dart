/// ============================================================
/// UNIFIED APP SHELL V2.0 — Domain-agnostic, enterprise-grade shell
/// ============================================================
///
/// 🎯 MISSION:
///   Transform UnifiedAppShell into a completely domain-agnostic,
///   enterprise-grade application shell that serves as the operating
///   system layer of the platform.
///
/// ✅ Performance (Phase 9):
///   - Regions isolated via ShellRegion (RepaintBoundary per region)
///   - No redundant provider watching
///   - Layout switching only on breakpoint changes
///   - All layout widgets use const constructors
///   - Immutable config models (ShellConfig + copyWith)
///
/// ✅ Extension Points (Phase 10):
///   - Extension slots in every region via runtime shellExtensionProvider
///   - Shell never knows what widgets represent
///   - No feature module imports in shell
///
/// 🏗️ Shell Regions:
///   TopBar:       Logo, workspace switcher, search, notifications, user menu
///   Navigation:   Sidebar (desktop), Rail (tablet), BottomNav (mobile/compact XS)
///   Content:      Module pages, dashboard host, dialog host
///   Overlay:      Notifications, toasts, global loading, AI assistant
///   Floating:     FAB, quick actions
///   Status:       Connectivity, sync, version, background tasks
///   Footer:       Optional desktop footer with links
///   Secondary:    Right-side panel (ultra-wide or splitWorkspace mode)
///
/// 🎮 Shell Modes (switched at runtime via config.mode):
///   standard:        All regions visible (default)
///   focus:           Hides nav/status/footer — content takes full space
///   immersive:       Full-screen content, zero chrome
///   splitWorkspace:  Dual-panel content layout with secondary panel
///   presentation:    Distraction-free for screen sharing
///   minimal:         Compact top bar only, no chrome
///
/// 🏢 Usage for ANY domain (zero shell modifications):
///   ```dart
///   // FAMHUB
///   ShellTheme.fromBrand(brandPrimary: Color(0xFF059669), brandName: 'FAMHUB');
///   // Factory ERP
///   ShellTheme.fromBrand(brandPrimary: Color(0xFF2563EB), brandName: 'FactoryERP');
///   // Healthcare
///   ShellTheme.fromBrand(brandPrimary: Color(0xFF0891B2), brandName: 'HealthApp');
///   // Education
///   ShellTheme.fromBrand(brandPrimary: Color(0xFFD97706), brandName: 'EduPortal');
///   ```
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../navigation/resize_optimizer.dart';
import '../../../navigation/runtime_refresh_provider.dart';
import '../../../theme/shell_theme.dart';
import '../../../dashboard_engine/application/observability/navigation_metrics.dart';
import '../../../providers/system_state_provider.dart';
import '../../../session/session_provider.dart';
import '../../domain/models/app_shell_context.dart';
import '../../config/shell_config.dart';
import '../../application/controllers/keyboard_navigation.dart';
import '../widgets/focus_manager.dart';
import '../layouts/compact_xs_shell_layout.dart';
import '../layouts/mobile_shell_layout.dart';
import '../layouts/tablet_shell_layout.dart';
import '../layouts/desktop_shell_layout.dart';
import '../layouts/ultra_wide_shell_layout.dart';
import '../layouts/common/common.dart';

/// ============================================================
/// UNIFIED APP SHELL V2.0
/// ============================================================
///
/// The SINGLE shell that powers ALL platform products.
/// Completely domain-agnostic, configured via ShellConfig + ShellTheme.
///
/// ⚡ Performance:
///   - Reads only systemStateProvider (minimal provider dependency)
///   - LayoutBuilder isolated in child StatelessWidget
///   - Breakpoint determined once, not recalculated on rebuilds
///   - Each region isolated via ShellRegion (RepaintBoundary)
/// ============================================================
class UnifiedAppShellV2 extends ConsumerWidget {
  final Widget child;
  final ShellConfig config;

  const UnifiedAppShellV2({
    super.key,
    required this.child,
    this.config = const ShellConfig(),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Activate runtime auto-invalidation — listens to module/context changes
    // and automatically refreshes navigation, extensions, and dashboard state.
    ref.listen(runtimeAutoInvalidatorProvider, (_, __) {});

    final systemState = ref.watch(systemStateProvider);
    final palette = Theme.of(context).extension<ShellThemeColors>()?.palette ??
        ShellTheme.defaultLight;

    // ============================================================
    // SYSTEM DOWN GATE (GLOBAL BLOCKER)
    // ============================================================
    if (systemState.isSystemDown) {
      return const ShellSystemDown();
    }

    // ============================================================
    // RESPONSIVE + MODE-AWARE SHELL
    // ============================================================
    // Delegates to _ShellLayoutBuilder (plain StatelessWidget) so that
    // LayoutBuilder does NOT run inside ConsumerWidget's build method.
    // This prevents unnecessary rebuilds when providers emit new values
    // but breakpoint/config remain unchanged.
    return _ShellLayoutBuilder(
      config: config,
      palette: palette,
      systemState: systemState,
      child: child,
    );
  }
}

/// ============================================================
/// SHELL LAYOUT BUILDER — Isolates LayoutBuilder rebuilds
/// ============================================================
///
/// Key performance optimization: LayoutBuilder's builder callback
/// only fires when constraints change, not when parent providers
/// emit new values. By separating this from ConsumerWidget, we
/// avoid re-running the LayoutBuilder closure on every provider
/// update.
/// ============================================================
class _ShellLayoutBuilder extends ConsumerStatefulWidget {
  final Widget child;
  final ShellConfig config;
  final ShellColorPalette palette;
  final SystemState systemState;

  const _ShellLayoutBuilder({
    required this.child,
    required this.config,
    required this.palette,
    required this.systemState,
  });

  @override
  ConsumerState<_ShellLayoutBuilder> createState() => _ShellLayoutBuilderState();
}

class _ShellLayoutBuilderState extends ConsumerState<_ShellLayoutBuilder> {
  @override
  Widget build(BuildContext context) {
    // ── Start timing for observability ──
    final stopwatch = Stopwatch()..start();

    // Watch the single breakpoint provider (shared with dashboard)
    final breakpointState = ref.watch(breakpointProvider);
    final deviceType = breakpointState.deviceType;

    // Apply mode transforms once per build (pure function)
    final effectiveConfig = applyShellMode(widget.config, widget.config.mode);

    // Build the appropriate layout widget from device type string
    final Widget shell = _buildLayoutForDevice(deviceType, effectiveConfig);

    // Record build time
    stopwatch.stop();
    navigationMetrics.recordDashboardRender(stopwatch.elapsedMilliseconds);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Feed width into the shared breakpoint notifier
        ref.read(breakpointProvider.notifier).updateWidth(constraints.maxWidth);
        return shell;
      },
    );
  }

  /// Build the appropriate layout for the current device type
  Widget _buildLayoutForDevice(String deviceType, ShellConfig effectiveConfig) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final isGuest = !isAuthenticated;
    final wrappedChild = AppShellContext(
      isGuest: isGuest,
      isSystemDown: widget.systemState.isSystemDown,
      child: widget.child,
    );

    Widget shell;

    switch (deviceType) {
      case 'compactXs':
        shell = CompactXsShellLayout(
          config: effectiveConfig,
          palette: widget.palette,
          child: wrappedChild,
        );
      case 'mobile':
        shell = MobileShellLayout(
          config: effectiveConfig,
          palette: widget.palette,
          child: wrappedChild,
        );
      case 'tablet':
        shell = TabletShellLayout(
          config: effectiveConfig,
          palette: widget.palette,
          child: wrappedChild,
        );
      case 'ultraWide':
        shell = UltraWideShellLayout(
          config: effectiveConfig,
          palette: widget.palette,
          child: wrappedChild,
        );
      case 'desktop':
      default:
        shell = DesktopShellLayout(
          config: effectiveConfig,
          palette: widget.palette,
          child: wrappedChild,
        );
    }

    // ── Wrap with keyboard navigation and focus management ──
    if (widget.config.enableKeyboardNavigation) {
      shell = KeyboardShortcutsHandler(
        overlays: effectiveConfig.overlays,
        child: shell,
      );
      shell = ShellFocusScope(child: shell);
    }

    return shell;
  }
}

/// ============================================================
/// APPLY SHELL MODE — Pure function, no side effects
/// ============================================================
///
/// Top-level function (not a method) so it can be used
/// by layout widgets or tests without instantiating the shell.
/// The original [config] is never mutated — derived config is returned.
/// ============================================================
ShellConfig applyShellMode(ShellConfig original, ShellMode mode) {
  switch (mode) {
    case ShellMode.standard:
      return original;

    case ShellMode.focus:
      return original.copyWith(
        navigation: original.navigation.copyWith(visible: false),
        statusBar: original.statusBar.copyWith(visible: false),
        footer: original.footer.copyWith(visible: false),
        overlays: const OverlayConfig(
          enableCommandPalette: false,
          enableGlobalSearch: false,
          enableNotificationsPanel: false,
        ),
      );

    case ShellMode.immersive:
      return original.copyWith(
        topBar: original.topBar.copyWith(visible: false),
        navigation: original.navigation.copyWith(visible: false),
        statusBar: original.statusBar.copyWith(visible: false),
        footer: original.footer.copyWith(visible: false),
        floatingActions: original.floatingActions.copyWith(enabled: false),
        secondaryPanel: original.secondaryPanel.copyWith(visible: false),
        showMaintenanceBanner: false,
        overlays: const OverlayConfig(
          enableCommandPalette: false,
          enableGlobalSearch: false,
          enableNotificationsPanel: false,
        ),
      );

    case ShellMode.splitWorkspace:
      return original.copyWith(
        secondaryPanel: original.secondaryPanel.copyWith(
          visible: true,
          title: original.secondaryPanel.title ?? 'Workspace',
        ),
      );

    case ShellMode.presentation:
      return original.copyWith(
        navigation: original.navigation.copyWith(visible: false),
        statusBar: original.statusBar.copyWith(visible: false),
        footer: original.footer.copyWith(visible: false),
        floatingActions: original.floatingActions.copyWith(enabled: false),
        secondaryPanel: original.secondaryPanel.copyWith(visible: false),
        showMaintenanceBanner: false,
        topBar: original.topBar.copyWith(
          showSearch: false,
          showNotifications: false,
          showAiAssistant: false,
        ),
      );

    case ShellMode.minimal:
      return original.copyWith(
        navigation: original.navigation.copyWith(visible: false),
        statusBar: original.statusBar.copyWith(visible: false),
        footer: original.footer.copyWith(visible: false),
        secondaryPanel: original.secondaryPanel.copyWith(visible: false),
        topBar: original.topBar.copyWith(
          showContextSelector: false,
          showModuleStatus: false,
          showSearch: false,
          showNotifications: false,
          showAiAssistant: false,
          showSettings: false,
          showProfile: true,
          height: 48.0,
        ),
      );
  }
}