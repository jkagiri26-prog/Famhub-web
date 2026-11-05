import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/composition/router/dynamic_route_registrar.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/session/app_session.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/workspace/application/active_workspace_provider.dart';
import 'package:famhub_app/core/workspace/application/workspace_catalog_provider.dart';
import 'package:famhub_app/core/workspace/application/workspace_dashboard_provider.dart';
import 'package:famhub_app/core/workspace/application/workspace_history_restore_coordinator.dart';
import 'package:famhub_app/core/dashboard_engine/presentation/renderer/responsive_dashboard_renderer.dart';
import 'package:famhub_app/core/observability/dashboard_diagnostic_panel.dart';

/// ============================================================
/// UNIFIED DASHBOARD HOST — Workspace landing dispatcher
/// ============================================================
///
/// The root route ('/') is the selected workspace's landing/dashboard.
/// It dispatches DIRECTLY to the workspace's primary experience — the
/// existing module landing page — based on the active workspace type.
///
///   farmer            → FarmManagementPage      (farm_management)
///   trader / supplier → Trader module           (trader)
///   institution       → FinancingPage           (finance)
///   service_provider  → ExtensionServicesPage   (extension_services)
///   knowledge_partner → KnowledgeLinkPage       (knowledge)
///
/// There is NO intermediate dashboard card the user must click to enter
/// the workspace, and NO redirect — the landing page renders in place.
///
/// Unmapped/unknown workspace types fall back to the curated workspace
/// dashboard (ResponsiveDashboardRenderer), never the generic
/// all-module directory.
///
/// ✅ Uses the existing ModulePageRegistry (single source of page
///    builders) and the existing workspace type mapping — the shell does
///    not import feature modules directly.
/// ============================================================
class UnifiedDashboardHost extends ConsumerStatefulWidget {
  const UnifiedDashboardHost({super.key});

  @override
  ConsumerState<UnifiedDashboardHost> createState() =>
      _UnifiedDashboardHostState();
}

class _UnifiedDashboardHostState extends ConsumerState<UnifiedDashboardHost> {
  String? _lastDiagnosticSignature;
  String? _pendingLandingRoute;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final userId = session is AuthenticatedSession ? session.userId : null;
    final profile = session is AuthenticatedSession ? session.profile : null;
    final profileId = profile == null ? null : profile['id']?.toString();
    final activeWorkspace = ref.watch(activeWorkspaceProvider);
    final catalog = ref.watch(workspaceCatalogProvider);
    final type = ref.watch(activeWorkspaceTypeProvider);
    final primaryKey = WorkspaceDashboardCatalog.primaryModuleKeyFor(type);
    final builder =
        primaryKey == null ? null : ModulePageRegistry.resolve(primaryKey);

    // Do not commit a workspace-dependent dashboard until the authoritative
    // active entity context has resolved (and the workspace has been
    // reconciled against it). Prevents rendering a workspace that does not
    // match the active context on startup.
    final EntityContext entityContext;
    try {
      entityContext = ref.watch(contextProvider);
    } catch (error, stackTrace) {
      if (kIsWeb) {
        DashboardDiagnosticLog.record(
          '[DashboardDiagnostic] ${DateTime.now().toIso8601String()} '
          'context_provider_threw errorType=${error.runtimeType} '
          'session=${session.runtimeType.toString()} '
          'user=${_abbreviateId(userId)} '
          'profile=${_abbreviateId(profileId)} '
          'activeWorkspaceId=${_abbreviateId(activeWorkspace.workspaceId)} '
          'normalizedWorkspaceType=${type ?? 'null'} '
          'resolvedPrimaryModuleId=${primaryKey ?? 'null'} '
          'builderFound=${builder != null}',
        );
        DashboardDiagnosticLog.record(
          '[DashboardDiagnostic] EntityContext provider stack',
          stackTrace: stackTrace,
          maxFrames: 12,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    _logDashboardState(
      sessionType: session.runtimeType.toString(),
      userId: userId,
      profileId: profileId,
      entityContext: entityContext,
      workspaceId: activeWorkspace.workspaceId,
      workspaceType: type,
      primaryModuleId: primaryKey,
      builderFound: builder != null,
      catalogState: catalog.isLoading
          ? 'loading'
          : catalog.hasError
              ? 'error:${catalog.error.runtimeType}'
              : 'data',
    );
    if (entityContext.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final canonicalLandingRoute = primaryKey == null
        ? null
        : WorkspaceDashboardCatalog.workspaceRouteForModuleKey(primaryKey)?.$2;
    final hasResolvedWorkspaceContext =
        session is AuthenticatedSession &&
        session.hasProfile &&
        !entityContext.isGuest &&
        entityContext.activeWorkspaceId == activeWorkspace.workspaceId &&
        entityContext.entityId != null &&
        entityContext.entityId!.isNotEmpty &&
        entityContext.roleId != null &&
        entityContext.roleId!.isNotEmpty;
    if (canonicalLandingRoute != null &&
        builder != null &&
        hasResolvedWorkspaceContext &&
        _pendingLandingRoute != canonicalLandingRoute) {
      final router = GoRouter.of(context);
      if (router.routerDelegate.currentConfiguration.uri.path == '/') {
        _pendingLandingRoute = canonicalLandingRoute;
        final workspaceId = activeWorkspace.workspaceId;
        final extra = ref
            .read(workspaceHistoryRestoreCoordinatorProvider)
            .createHistoryExtra(
              router.routerDelegate.currentConfiguration.extra,
              workspaceId: workspaceId,
              context: entityContext,
            );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final router = GoRouter.of(context);
          if (router.routerDelegate.currentConfiguration.uri.path != '/' ||
              ref.read(activeWorkspaceProvider).workspaceId != workspaceId) {
            return;
          }
          Router.neglect(
            context,
            () => router.go(canonicalLandingRoute, extra: extra),
          );
        });
      }
    }

    if (builder != null) {
      // Render the existing module landing page directly.
      if (kIsWeb) {
        DashboardDiagnosticLog.record(
          '[DashboardDiagnostic] ${DateTime.now().toIso8601String()} '
          'module_builder_invoked module=$primaryKey',
        );
      }
      try {
        final page = builder(context);
        if (kIsWeb) {
          DashboardDiagnosticLog.record(
            '[DashboardDiagnostic] ${DateTime.now().toIso8601String()} '
            'module_builder_returned module=$primaryKey '
            'widget=${page.runtimeType}',
          );
        }
        if (primaryKey == 'farm_management') {
          return _DashboardFirstFrameProbe(
            moduleId: primaryKey!,
            child: page,
          );
        }
        return page;
      } catch (error, stackTrace) {
        if (kIsWeb) {
          DashboardDiagnosticLog.record(
            '[DashboardDiagnostic] ${DateTime.now().toIso8601String()} '
            'module_builder_threw module=$primaryKey '
            'errorType=${error.runtimeType}',
          );
          DashboardDiagnosticLog.record(
            '[DashboardDiagnostic] module builder stack',
            stackTrace: stackTrace,
            maxFrames: 12,
          );
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    }

    // Unknown/unmapped workspace → curated workspace-aware fallback.
    return const ResponsiveDashboardRenderer();
  }

  void _logDashboardState({
    required String sessionType,
    required String? userId,
    required String? profileId,
    required EntityContext entityContext,
    required String workspaceId,
    required String? workspaceType,
    required String? primaryModuleId,
    required bool builderFound,
    required String catalogState,
  }) {
    if (!kIsWeb) return;
    final contextStatus = entityContext.isLoading
        ? 'loading'
        : entityContext.isGuest
            ? 'guest'
            : entityContext.userId == null ||
                    entityContext.profileId == null ||
                    entityContext.activeWorkspaceId == null ||
                    entityContext.entityId == null ||
                    entityContext.roleId == null ||
                    entityContext.role == null
                ? 'unavailable'
                : 'resolved';
    final contextMatchesWorkspace =
        entityContext.activeWorkspaceId == workspaceId;
    final signature = [
      sessionType,
      _abbreviateId(userId),
      _abbreviateId(profileId),
      contextStatus,
      _abbreviateId(entityContext.userId),
      _abbreviateId(entityContext.profileId),
      _abbreviateId(entityContext.activeWorkspaceId),
      _abbreviateId(entityContext.entityId),
      _abbreviateId(entityContext.roleId),
      _abbreviateId(entityContext.businessProfileId),
      entityContext.role ?? 'null',
      contextMatchesWorkspace,
      _abbreviateId(workspaceId),
      workspaceType ?? 'null',
      primaryModuleId ?? 'null',
      builderFound,
      catalogState,
    ].join('|');
    if (_lastDiagnosticSignature == signature) return;
    _lastDiagnosticSignature = signature;
    DashboardDiagnosticLog.record(
      '[DashboardDiagnostic] ${DateTime.now().toIso8601String()} '
      'session=$sessionType user=${_abbreviateId(userId)} '
      'profile=${_abbreviateId(profileId)} context=$contextStatus '
      'contextError=none '
      'contextLoading=${entityContext.isLoading} '
      'contextGuest=${entityContext.isGuest} '
      'contextUser=${_abbreviateId(entityContext.userId)} '
      'contextProfile=${_abbreviateId(entityContext.profileId)} '
      'contextWorkspace=${_abbreviateId(entityContext.activeWorkspaceId)} '
      'contextMatchesWorkspace=$contextMatchesWorkspace '
      'entity=${_abbreviateId(entityContext.entityId)} '
      'roleId=${_abbreviateId(entityContext.roleId)} '
      'mode=${entityContext.role ?? 'null'} '
      'businessProfile=${_abbreviateId(entityContext.businessProfileId)} '
      'activeWorkspaceId=${_abbreviateId(workspaceId)} '
      'normalizedWorkspaceType=${workspaceType ?? 'null'} '
      'resolvedPrimaryModuleId=${primaryModuleId ?? 'null'} '
      'builderFound=$builderFound catalog=$catalogState',
    );
  }
}

String _abbreviateId(String? value) {
  if (value == null || value.isEmpty) return 'null';
  if (value.length <= 8) return '[redacted]';
  return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
}

class _DashboardFirstFrameProbe extends SingleChildRenderObjectWidget {
  const _DashboardFirstFrameProbe({
    required this.moduleId,
    required super.child,
  });

  final String moduleId;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _DashboardFirstFrameRenderProbe(moduleId);
}

class _DashboardFirstFrameRenderProbe extends RenderProxyBox {
  _DashboardFirstFrameRenderProbe(this.moduleId);

  final String moduleId;
  bool _layoutReported = false;
  bool _paintReported = false;

  @override
  void performLayout() {
    try {
      super.performLayout();
    } catch (error, stackTrace) {
      _logRenderFailure('layout', error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
    if (kIsWeb && !_layoutReported) {
      _layoutReported = true;
      DashboardDiagnosticLog.record(
        '[DashboardDiagnostic] ${DateTime.now().toIso8601String()} '
        'module_first_layout module=$moduleId '
        'size=${size.width}x${size.height} child=${child != null}',
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    try {
      super.paint(context, offset);
    } catch (error, stackTrace) {
      _logRenderFailure('paint', error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
    if (kIsWeb && !_paintReported) {
      _paintReported = true;
      DashboardDiagnosticLog.record(
        '[DashboardDiagnostic] ${DateTime.now().toIso8601String()} '
        'module_first_paint module=$moduleId '
        'size=${size.width}x${size.height} child=${child != null}',
      );
    }
  }

  void _logRenderFailure(
    String phase,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!kIsWeb) return;
    DashboardDiagnosticLog.record(
      '[DashboardDiagnostic] ${DateTime.now().toIso8601String()} '
      'module_render_failed module=$moduleId phase=$phase '
      'errorType=${error.runtimeType}',
    );
    DashboardDiagnosticLog.record(
      '[DashboardDiagnostic] module $phase stack',
      stackTrace: stackTrace,
      maxFrames: 12,
    );
  }
}
