import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/context_engine/controllers/context_controller.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/session/app_session.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/workspace/application/active_workspace_provider.dart';
import 'package:famhub_app/core/workspace/application/workspace_catalog_provider.dart';
import 'package:famhub_app/core/workspace/application/workspace_dashboard_provider.dart';
import 'package:famhub_app/core/workspace/domain/workspace_catalog_item.dart';

const workspaceHistoryExtraKey = '_workspaceHistory';
const _workspaceHistoryOriginalExtraKey = '_workspaceHistoryOriginalExtra';

class WorkspaceHistoryRestoreResult {
  const WorkspaceHistoryRestoreResult._(this.restored, this.message);

  const WorkspaceHistoryRestoreResult.restored()
      : this._(true, null);

  const WorkspaceHistoryRestoreResult.failed(String message)
      : this._(false, message);

  final bool restored;
  final String? message;
}

class _BrowserHistoryEvent {
  const _BrowserHistoryEvent(this.id, this.uri);

  final int id;
  final Uri uri;
}

class WorkspaceHistoryRestoreCoordinator {
  WorkspaceHistoryRestoreCoordinator(this._ref);

  final Ref _ref;
  GoRouter? _router;
  _BrowserHistoryEvent? _browserEvent;
  int _nextBrowserEventId = 0;
  int _nextEntryId = 0;
  int? _handledEventId;
  String? _handledEntryId;
  Future<WorkspaceHistoryRestoreResult>? _handledRestore;

  void attach(GoRouter router) {
    if (identical(_router, router)) return;
    detach();
    _router = router;
    router.routeInformationProvider.addListener(_onRouteInformationChanged);
    router.routerDelegate.addListener(_onRouterChanged);
  }

  void detach() {
    final router = _router;
    if (router != null) {
      router.routeInformationProvider.removeListener(_onRouteInformationChanged);
      router.routerDelegate.removeListener(_onRouterChanged);
    }
    _router = null;
    _browserEvent = null;
  }

  void dispose() => detach();

  Object? createHistoryExtra(
    Object? previousExtra, {
    required String workspaceId,
    required EntityContext context,
  }) {
    final routeExtra = _stringKeyedMap(previousExtra);
    final extra = <Object?, Object?>{};
    if (previousExtra is Map) extra.addAll(previousExtra);
    extra.addAll(routeExtra);
    if (previousExtra != null && previousExtra is! Map) {
      extra[_workspaceHistoryOriginalExtraKey] = previousExtra;
    }
    extra[workspaceHistoryExtraKey] = <String, Object?>{
      'entryId':
          '${DateTime.now().microsecondsSinceEpoch}-${++_nextEntryId}',
      'workspaceId': workspaceId,
      'userId': context.userId,
      'profileId': context.profileId,
      'entityId': context.entityId,
      'roleId': context.roleId,
      'activeMode': context.role,
      'businessProfileId': context.businessProfileId,
    };
    return extra;
  }

  Future<WorkspaceHistoryRestoreResult>? restoreCurrentBrowserEntry({
    required Uri uri,
    required Object? extra,
    required String workspaceKey,
  }) {
    final event = _browserEvent;
    if (event == null || event.uri.path != uri.path) return null;

    final routeExtra = _stringKeyedMap(extra);
    if (!routeExtra.containsKey(workspaceHistoryExtraKey)) return null;
    final metadata = _stringKeyedMap(routeExtra[workspaceHistoryExtraKey]);
    final entryId = metadata['entryId']?.toString();
    if (_handledEventId == event.id &&
        _handledEntryId == entryId &&
        _handledRestore != null) {
      return _handledRestore;
    }
    _handledEventId = event.id;
    _handledEntryId = entryId;
    _handledRestore = _restore(
      extra: extra,
      workspaceKey: workspaceKey,
    ).catchError((Object error, StackTrace stackTrace) {
      debugPrint('[WorkspaceHistory] restoration failed: $error');
      return const WorkspaceHistoryRestoreResult.failed(
        'The workspace history entry could not be restored.',
      );
    });
    return _handledRestore;
  }

  void _onRouteInformationChanged() {
    final router = _router;
    if (router == null) return;

    // go_router 14.8.1 receives decoded browser history entries as a Map;
    // programmatic GoRouter navigation uses its internal state object.
    final state = router.routeInformationProvider.value.state;
    if (state is Map) {
      _browserEvent = _BrowserHistoryEvent(
        ++_nextBrowserEventId,
        router.routeInformationProvider.value.uri,
      );
    } else {
      _browserEvent = null;
    }
  }

  void _onRouterChanged() {
    final router = _router;
    final event = _browserEvent;
    if (router == null || event == null) return;

    final route = router.routerDelegate.currentConfiguration;
    final workspaceKey = _workspaceKeyForPath(route.uri.path);
    if (workspaceKey == null || event.uri.path != route.uri.path) {
      _browserEvent = null;
      return;
    }
    restoreCurrentBrowserEntry(
      uri: route.uri,
      extra: route.extra,
      workspaceKey: workspaceKey,
    );
  }

  Future<WorkspaceHistoryRestoreResult> _restore({
    required Object? extra,
    required String workspaceKey,
  }) async {
    final metadata =
        _stringKeyedMap(_stringKeyedMap(extra)[workspaceHistoryExtraKey]);
    final entryId = metadata['entryId']?.toString();
    final workspaceId = metadata['workspaceId']?.toString();
    final userId = metadata['userId']?.toString();
    final profileId = metadata['profileId']?.toString();
    final entityId = metadata['entityId']?.toString();
    final roleId = metadata['roleId']?.toString();
    final activeMode = metadata['activeMode']?.toString();
    final hasBusinessProfileHint = metadata.containsKey('businessProfileId');
    final businessProfileId = metadata['businessProfileId']?.toString();
    if (entryId == null ||
        entryId.isEmpty ||
        workspaceId == null ||
        workspaceId.isEmpty ||
        userId == null ||
        userId.isEmpty ||
        profileId == null ||
        profileId.isEmpty ||
        entityId == null ||
        entityId.isEmpty ||
        roleId == null ||
        roleId.isEmpty ||
        activeMode == null ||
        activeMode.isEmpty ||
        !hasBusinessProfileHint) {
      return const WorkspaceHistoryRestoreResult.failed(
        'This browser history entry has no complete workspace context.',
      );
    }

    final session = _ref.read(sessionProvider);
    if (session is! AuthenticatedSession ||
        session.userId != userId ||
        session.profile?['id']?.toString() != profileId ||
        !session.workspaceIds.contains(workspaceId)) {
      return const WorkspaceHistoryRestoreResult.failed(
        'This workspace history entry is no longer available to the '
        'current profile.',
      );
    }

    final currentWorkspaceId = _ref.read(activeWorkspaceProvider).workspaceId;
    final currentContext = _ref.read(contextProvider);
    if (currentWorkspaceId == workspaceId &&
        _matchesContext(
          currentContext,
          userId: userId,
          profileId: profileId,
          workspaceId: workspaceId,
          entityId: entityId,
          roleId: roleId,
          activeMode: activeMode,
          businessProfileId: businessProfileId,
        )) {
      return const WorkspaceHistoryRestoreResult.restored();
    }

    final contextController = _ref.read(contextProvider.notifier);
    final generation = contextController.beginSelectionOperation(
      userId: userId,
      profileId: profileId,
    );
    if (generation < 0) {
      return const WorkspaceHistoryRestoreResult.failed(
        'The signed-in profile could not be confirmed.',
      );
    }

    bool isCurrent() => contextController.selectionOperationIsCurrent(
          generation: generation,
          userId: userId,
          profileId: profileId,
        );

    List<WorkspaceCatalogItem> catalog;
    try {
      catalog = await _ref.read(workspaceCatalogProvider.future);
    } catch (_) {
      return _failCurrent(
        contextController,
        generation,
        userId,
        profileId,
        'Available workspaces could not be confirmed.',
      );
    }
    if (!isCurrent()) {
      return const WorkspaceHistoryRestoreResult.failed(
        'Workspace restoration was superseded by a newer selection.',
      );
    }
    final catalogMatches = catalog
        .where((workspace) => workspace.id == workspaceId)
        .toList();
    final expectedType = _workspaceTypeForKey(workspaceKey);
    if (catalogMatches.length != 1 ||
        expectedType == null ||
        WorkspaceDashboardCatalog.normalizeType(
              catalogMatches.single.category ?? catalogMatches.single.name,
            ) !=
            expectedType) {
      return _failCurrent(
        contextController,
        generation,
        userId,
        profileId,
        'The recorded workspace does not match this route.',
      );
    }

    List<Map<String, dynamic>> contexts;
    try {
      contexts =
          await _ref.read(authServiceProvider).getAvailableWorkspaceContexts();
    } catch (_) {
      return _failCurrent(
        contextController,
        generation,
        userId,
        profileId,
        'Authorized workspace contexts could not be confirmed.',
      );
    }
    if (!isCurrent()) {
      return const WorkspaceHistoryRestoreResult.failed(
        'Workspace restoration was superseded by a newer selection.',
      );
    }

    final matches = contexts.where((record) {
      final recordProfileId = record['profile_id']?.toString();
      return record['workspace_id']?.toString() == workspaceId &&
          record['entity_id']?.toString() == entityId &&
          record['role_id']?.toString() == roleId &&
          record['active_mode']?.toString() == activeMode &&
          record['business_profile_id']?.toString() == businessProfileId &&
          (recordProfileId == null ||
              recordProfileId.isEmpty ||
              recordProfileId == profileId);
    }).toList();
    if (matches.length != 1) {
      return _failCurrent(
        contextController,
        generation,
        userId,
        profileId,
        'The recorded entity and role are no longer uniquely authorized.',
      );
    }

    final activeContext = _ref.read(contextProvider);
    final activeWorkspaceId =
        _ref.read(activeWorkspaceProvider).workspaceId;
    if (activeWorkspaceId == workspaceId &&
        _matchesContext(
          activeContext,
          userId: userId,
          profileId: profileId,
          workspaceId: workspaceId,
          entityId: entityId,
          roleId: roleId,
          activeMode: activeMode,
          businessProfileId: businessProfileId,
        )) {
      return const WorkspaceHistoryRestoreResult.restored();
    }

    if (!isCurrent()) {
      return const WorkspaceHistoryRestoreResult.failed(
        'Workspace restoration was superseded by a newer selection.',
      );
    }
    final activated = await contextController.activateContextRow(
      workspaceId: workspaceId,
      entityId: entityId,
      roleId: roleId,
      activeMode: activeMode,
      businessProfileId: businessProfileId,
      expectedGeneration: generation,
      commitWorkspaceSelection: true,
    );
    if (activated == null) {
      return const WorkspaceHistoryRestoreResult.failed(
        'The recorded workspace context could not be activated.',
      );
    }
    final latestSession = _ref.read(sessionProvider);
    if (latestSession is! AuthenticatedSession ||
        latestSession.userId != userId ||
        latestSession.profile?['id']?.toString() != profileId ||
        _ref.read(activeWorkspaceProvider).workspaceId != workspaceId ||
        !_matchesContext(
          _ref.read(contextProvider),
          userId: userId,
          profileId: profileId,
          workspaceId: workspaceId,
          entityId: entityId,
          roleId: roleId,
          activeMode: activeMode,
          businessProfileId: businessProfileId,
        )) {
      return const WorkspaceHistoryRestoreResult.failed(
        'Workspace restoration was superseded by a newer selection.',
      );
    }

    return const WorkspaceHistoryRestoreResult.restored();
  }

  bool _matchesContext(
    EntityContext context, {
    required String userId,
    required String profileId,
    required String workspaceId,
    required String entityId,
    required String roleId,
    required String activeMode,
    required String? businessProfileId,
  }) =>
      !context.isLoading &&
      !context.isGuest &&
      context.userId == userId &&
      context.profileId == profileId &&
      context.activeWorkspaceId == workspaceId &&
      context.entityId == entityId &&
      context.roleId == roleId &&
      context.role == activeMode &&
      context.businessProfileId == businessProfileId;

  Future<WorkspaceHistoryRestoreResult> _failCurrent(
    ContextController contextController,
    int generation,
    String userId,
    String profileId,
    String message,
  ) async {
    if (contextController.selectionOperationIsCurrent(
          generation: generation,
          userId: userId,
          profileId: profileId,
        ) &&
        _ref.read(contextProvider).isLoading) {
      await contextController.init();
    }
    return WorkspaceHistoryRestoreResult.failed(message);
  }

  static String? _workspaceKeyForPath(String path) {
    for (final moduleKey in WorkspaceDashboardCatalog.modulePromotions.values
        .expand((moduleKeys) => moduleKeys)) {
      if (WorkspaceDashboardCatalog.workspaceRouteForModuleKey(moduleKey)
              ?.$2 ==
          path) {
        return moduleKey;
      }
    }
    return null;
  }

  static String? _workspaceTypeForKey(String key) {
    for (final entry in WorkspaceDashboardCatalog.modulePromotions.entries) {
      if (entry.value.isNotEmpty && entry.value.first == key) {
        return entry.key;
      }
    }
    return null;
  }

  static Map<String, Object?> _stringKeyedMap(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
  }
}

final workspaceHistoryRestoreCoordinatorProvider =
    Provider<WorkspaceHistoryRestoreCoordinator>((ref) {
  final coordinator = WorkspaceHistoryRestoreCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
