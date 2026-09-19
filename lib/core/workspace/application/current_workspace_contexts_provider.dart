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

import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/workspace/application/active_workspace_provider.dart';

final currentWorkspaceContextsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final workspaceId =
      ref.watch(activeWorkspaceProvider.select((w) => w.workspaceId));
  if (workspaceId.isEmpty) return const [];

  final authService = ref.read(authServiceProvider);
  final all = await authService.getAvailableWorkspaceContexts();
  final contexts = all
      .where((c) => c['workspace_id']?.toString() == workspaceId)
      .toList();

  // Resolve human-readable entity names for contexts whose RPC row omits them
  // (never display a raw entity UUID).
  final missing = contexts
      .where((c) => (c['entity_name']?.toString().trim().isEmpty ?? true))
      .map((c) => c['entity_id']?.toString())
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();
  if (missing.isNotEmpty) {
    try {
      final rows = await SupabaseService.instance.client
          .schema('core')
          .from('entities')
          .select('id, name')
          .inFilter('id', missing);
      final names = <String, String>{};
      for (final r in (rows as List).cast<Map<String, dynamic>>()) {
        final id = r['id']?.toString();
        final name = r['name']?.toString();
        if (id != null && name != null && name.isNotEmpty) {
          names[id] = name;
        }
      }
      for (final c in contexts) {
        final id = c['entity_id']?.toString();
        final current = c['entity_name']?.toString();
        if ((current == null || current.trim().isEmpty) &&
            id != null &&
            names.containsKey(id)) {
          c['entity_name'] = names[id];
        }
      }
    } catch (_) {
      // Non-fatal: the UI falls back to the role/mode label.
    }
  }

  return contexts;
});
