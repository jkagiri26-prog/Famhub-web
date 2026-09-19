/// ============================================================
/// CURRENT WORKSPACE CONTEXTS — READ-ONLY
/// ============================================================
///
/// Authorized entity/context choices for the ACTIVE workspace, from the
/// canonical `users.get_available_workspace_contexts()`.
///
/// Shared by the app-bar context switcher and the Business Hub entity
/// switcher so the workspace/entity/role authorization model stays in one
/// place. This is a READ-ONLY provider — it never activates a context.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/workspace/application/active_workspace_provider.dart';

final currentWorkspaceContextsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final workspaceId =
      ref.watch(activeWorkspaceProvider.select((w) => w.workspaceId));
  if (workspaceId.isEmpty) return const [];

  final authService = ref.read(authServiceProvider);
  final all = await authService.getAvailableWorkspaceContexts();
  return all
      .where((c) => c['workspace_id']?.toString() == workspaceId)
      .toList();
});
