/// ============================================================
/// ASSISTANT CONTEXT PROVIDER
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/application/assistant/ = shell-level assistant seam
///
/// ✅ Responsibilities:
///   - Resolve the current route → module id/name using the EXISTING
///     RouteRegistry + ModuleRegistry catalogs (and the runtime module
///     registry for backend-provided display names)
///   - Read the EXISTING active workspace and entity context providers
///   - Assemble an [AssistantContext] envelope
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Builds on existing state only — no duplicate workspace/entity state
///   - Pure derivation: every field is watched, so switching workspace,
///     entity or module re-derives the envelope automatically
///   - Never guesses a module, workspace or entity name
///
/// ❌ Does NOT:
///   - Fetch anything itself
///   - Carry identifiers to the model
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/composition/providers/composition_providers.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context.dart';
import 'package:famhub_app/core/workspace/application/current_workspace_contexts_provider.dart';
import 'package:famhub_app/core/workspace/application/workspace_dashboard_provider.dart';
import 'package:famhub_app/system/registry/module_registry.dart';
import 'package:famhub_app/system/registry/route_registry.dart';

/// The assistant context envelope for a given current route.
///
/// Family key is the router path captured when the assistant opens.
/// All other fields are watched, so the envelope stays live while the
/// assistant is open.
final assistantContextProvider =
    Provider.family<AssistantContext, String>((ref, route) {
  final String? workspaceType = ref.watch(activeWorkspaceTypeProvider);
  final String? workspaceName = ref.watch(activeWorkspaceNameProvider);
  final context = ref.watch(contextProvider);
  final contexts =
      ref.watch(currentWorkspaceContextsProvider).value ?? const [];

  // Match and report on the path only. `uri.toString()` from the router can
  // carry a query or fragment (`/marketplace?tab=sell`), which would never
  // equal a catalog route and would wrongly report "no module". Query values
  // are screen state, not a page identity, and are not shipped to the model.
  final String path = _routePathOf(route);

  final String? moduleId = _moduleIdForRoute(path, workspaceType);
  final String? moduleName = _moduleNameFor(ref, moduleId);

  return AssistantContext(
    route: path,
    moduleId: moduleId,
    moduleName: moduleName,
    workspaceName: workspaceName,
    workspaceType: workspaceType,
    contextMode: context.role,
    entityName: _entityNameFor(context.entityId, contexts),
  );
});

/// Returns [route] with any query string and fragment removed.
String _routePathOf(String route) {
  final int query = route.indexOf('?');
  final int fragment = route.indexOf('#');
  int end = route.length;
  if (query >= 0 && query < end) end = query;
  if (fragment >= 0 && fragment < end) end = fragment;
  return end == route.length ? route : route.substring(0, end);
}

/// Longest-prefix match of [route] against the static route catalog.
///
/// A base only matches on a path-segment boundary, so `/farm` resolves
/// `/farm` and `/farm/crops` but never `/farmer-tools`.
///
/// The landing route `/` has no module of its own — it renders the active
/// workspace's primary module, so that is what it resolves to. Anything
/// that does not resolve returns null rather than a guess.
String? _moduleIdForRoute(String route, String? workspaceType) {
  if (route.isEmpty) return null;

  if (route == '/') {
    if (workspaceType == null || workspaceType.isEmpty) return null;
    return WorkspaceDashboardCatalog.primaryModuleKeyFor(workspaceType);
  }

  String? match;
  for (final mapping in RouteRegistry.mappings) {
    final String base = mapping.route;
    if (base == '/' || base.isEmpty) continue;
    if (route == base || route.startsWith('$base/')) {
      if (match == null || base.length > match.length) match = base;
    }
  }
  if (match == null) return null;
  return RouteRegistry.forRoute(match)?.moduleId;
}

/// Backend runtime display name first (authoritative), static catalog second.
String? _moduleNameFor(Ref ref, String? moduleId) {
  if (moduleId == null) return null;

  for (final module in ref.watch(runtimeModuleRegistryProvider)) {
    if (module.moduleId == moduleId && module.displayName.isNotEmpty) {
      return module.displayName;
    }
  }
  return ModuleRegistry.byId(moduleId)?.name;
}

/// Human-readable entity name from the contexts the user is authorized to
/// see. Returns null when it cannot be resolved — never a raw id.
String? _entityNameFor(
  String? activeEntityId,
  List<Map<String, dynamic>> contexts,
) {
  if (activeEntityId == null || activeEntityId.isEmpty) return null;
  const List<String> nameKeys = <String>[
    'entity_name',
    'entity_display_name',
    'entity_slug',
    'name',
  ];
  for (final c in contexts) {
    if (c['entity_id']?.toString() != activeEntityId) continue;
    for (final key in nameKeys) {
      final named = c[key]?.toString().trim();
      if (named != null && named.isNotEmpty) return named;
    }
  }
  return null;
}
